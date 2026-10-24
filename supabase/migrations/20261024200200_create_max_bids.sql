-- Maximum (proxy) bids: a user names the most they will pay and the server bids for them,
-- one minimum step above whoever challenges them, never beyond that amount.
-- Written only by set_max_bid(); read only by their owner (a visible maximum tells
-- rivals exactly what to bid).

create table public.max_bids (
  auction_id uuid not null references public.auctions (id) on delete cascade,
  bidder_id uuid not null references public.profiles (id) on delete cascade,
  max_amount numeric(12, 2) not null,
  -- When this maximum was set: of two equal maximums the earlier one wins.
  set_at timestamptz not null default now(),
  primary key (auction_id, bidder_id),
  constraint max_bids_amount_positive check (max_amount > 0)
);

alter table public.max_bids enable row level security;

create policy "Users read their own maximum bids"
  on public.max_bids for select
  to authenticated
  using (bidder_id = (select auth.uid()));

revoke all on public.max_bids from anon, authenticated;
grant select on public.max_bids to authenticated;

-- apply_max_bids: after a bid or a new maximum, let the maximums answer. Called with the
-- auction row already locked by place_bid / set_max_bid. Settles the auction in one step
-- instead of trading bids one increment at a time:
--   contenders: every other maximum still at or above the price, plus the leader, whose
--               reach is their own maximum or at least the price they lead at;
--   winner:     the highest reach; of equal ones, the one placed first;
--   price:      the runner-up's reach plus one minimum step, capped at the winner's reach.
-- Records at most two automatic bids (the runner-up's last word, then the winner's), so the
-- feed shows why the price moved. Their times follow p_now by a microsecond each, which
-- keeps the feed in order.
create function public.apply_max_bids(p_auction_id uuid, p_now timestamptz)
returns public.auctions
language plpgsql
set search_path = ''
as $$
declare
  v_auction public.auctions;
  v_leader_reach numeric(12, 2);
  v_leader_since timestamptz;
  v_winner uuid;
  v_winner_reach numeric(12, 2);
  v_runner uuid;
  v_runner_reach numeric(12, 2);
  v_price numeric(12, 2);
  v_contender record;
begin
  select * into v_auction from public.auctions where id = p_auction_id;

  -- The leader's reach: a maximum above the price counts from when it was set; otherwise
  -- they reach the price itself, from their latest bid.
  if v_auction.current_winner_id is not null then
    select m.max_amount, m.set_at into v_leader_reach, v_leader_since
    from public.max_bids m
    where m.auction_id = p_auction_id and m.bidder_id = v_auction.current_winner_id
      and m.max_amount > v_auction.current_price;
    if not found then
      v_leader_reach := v_auction.current_price;
      select max(b.created_at) into v_leader_since
      from public.bids b
      where b.auction_id = p_auction_id and b.bidder_id = v_auction.current_winner_id;
    end if;
  end if;

  for v_contender in
    select c.bidder_id, c.reach
    from (
      select m.bidder_id, m.max_amount as reach, m.set_at as since
      from public.max_bids m
      where m.auction_id = p_auction_id
        and m.bidder_id is distinct from v_auction.current_winner_id
        and m.max_amount >= v_auction.current_price
      union all
      select v_auction.current_winner_id, v_leader_reach, v_leader_since
      where v_auction.current_winner_id is not null
    ) c
    order by c.reach desc, c.since asc
    limit 2
  loop
    if v_winner is null then
      v_winner := v_contender.bidder_id;
      v_winner_reach := v_contender.reach;
    else
      v_runner := v_contender.bidder_id;
      v_runner_reach := v_contender.reach;
    end if;
  end loop;

  if v_winner is null then
    return v_auction;
  end if;

  if v_winner = v_auction.current_winner_id then
    -- The leader holds. Only a challenger who reached above the price moves it.
    if v_runner is null or v_runner_reach <= v_auction.current_price then
      return v_auction;
    end if;
  elsif v_runner is null then
    -- A maximum on an auction nobody has bid on: the opening bid.
    v_runner_reach := v_auction.current_price;
  end if;

  v_price := least(v_winner_reach, v_runner_reach + v_auction.min_increment);

  if v_runner is not null and v_runner_reach > v_auction.current_price then
    insert into public.bids (auction_id, bidder_id, amount, is_auto, created_at)
    values (p_auction_id, v_runner, v_runner_reach, true, p_now + interval '1 microsecond');
  end if;
  insert into public.bids (auction_id, bidder_id, amount, is_auto, created_at)
  values (p_auction_id, v_winner, v_price, true, p_now + interval '2 microseconds');

  update public.auctions
  set current_price = v_price, current_winner_id = v_winner
  where id = p_auction_id
  returning * into v_auction;

  return v_auction;
end;
$$;

-- Anti-sniping, shared by place_bid and set_max_bid: a bid in the last 30 seconds moves
-- the end 30 seconds later. Same numbers as antiSnipingWindow / antiSnipingExtension in
-- lib/core/auction_rules.dart.
create function public.extend_if_closing(p_auction_id uuid, p_now timestamptz)
returns public.auctions
language sql
set search_path = ''
as $$
  update public.auctions
  set ends_at = case
    when ends_at - p_now <= interval '30 seconds' then ends_at + interval '30 seconds'
    else ends_at
  end
  where id = p_auction_id
  returning *;
$$;

-- place_bid, now followed by the maximums' answer. Same checks as before.
create or replace function public.place_bid(p_auction_id uuid, p_amount numeric)
returns public.auctions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bidder uuid := auth.uid();
  v_auction public.auctions;
  v_now timestamptz;
begin
  if v_bidder is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  -- numeric(12,2): positive, at most two decimals, at most 9 999 999 999.99.
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2)
     or p_amount >= 10000000000 then
    raise exception 'INVALID_AMOUNT';
  end if;
  -- The bid feed shows a username; the app asks for one right after sign-up.
  if not exists (
    select 1 from public.profiles where id = v_bidder and username is not null
  ) then
    raise exception 'USERNAME_REQUIRED';
  end if;

  -- Lock the auction. A second bid on the same auction waits here until this one
  -- commits, then reads the new price; that is what keeps two bids from both winning.
  select * into v_auction from public.auctions where id = p_auction_id for update;
  if not found then
    raise exception 'AUCTION_NOT_FOUND';
  end if;

  -- The real time after waiting for the lock: now() is when the transaction began,
  -- which may be before the auction ended.
  v_now := clock_timestamp();

  if v_auction.status <> 'live' then
    raise exception 'AUCTION_NOT_LIVE';
  end if;
  -- Still 'live' in the table until finalize_ended_auctions() runs (M5), but over.
  if v_auction.ends_at <= v_now then
    raise exception 'AUCTION_ENDED';
  end if;
  if v_auction.seller_id = v_bidder then
    raise exception 'SELLER_CANNOT_BID';
  end if;
  if v_auction.current_winner_id = v_bidder then
    raise exception 'ALREADY_WINNING';
  end if;
  if p_amount < v_auction.current_price + v_auction.min_increment then
    raise exception 'BID_TOO_LOW';
  end if;

  insert into public.bids (auction_id, bidder_id, amount, created_at)
  values (p_auction_id, v_bidder, p_amount, v_now);

  update public.auctions
  set current_price = p_amount, current_winner_id = v_bidder
  where id = p_auction_id;

  perform public.apply_max_bids(p_auction_id, v_now);
  return public.extend_if_closing(p_auction_id, v_now);
end;
$$;

-- set_max_bid: set or raise the caller's maximum. If they are not leading, the server
-- bids for them at once (and other maximums may answer). A maximum can only go up:
-- lowering it after it pushed others' bids up would be a free way to move the price.
create function public.set_max_bid(p_auction_id uuid, p_max numeric)
returns public.auctions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bidder uuid := auth.uid();
  v_auction public.auctions;
  v_before public.auctions;
  v_now timestamptz;
begin
  if v_bidder is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_max is null or p_max <= 0 or p_max <> round(p_max, 2)
     or p_max >= 10000000000 then
    raise exception 'INVALID_AMOUNT';
  end if;
  if not exists (
    select 1 from public.profiles where id = v_bidder and username is not null
  ) then
    raise exception 'USERNAME_REQUIRED';
  end if;

  select * into v_auction from public.auctions where id = p_auction_id for update;
  if not found then
    raise exception 'AUCTION_NOT_FOUND';
  end if;
  v_now := clock_timestamp();

  if v_auction.status <> 'live' then
    raise exception 'AUCTION_NOT_LIVE';
  end if;
  if v_auction.ends_at <= v_now then
    raise exception 'AUCTION_ENDED';
  end if;
  if v_auction.seller_id = v_bidder then
    raise exception 'SELLER_CANNOT_BID';
  end if;
  if p_max < v_auction.current_price + v_auction.min_increment then
    raise exception 'MAX_TOO_LOW';
  end if;
  if exists (
    select 1 from public.max_bids
    where auction_id = p_auction_id and bidder_id = v_bidder and max_amount >= p_max
  ) then
    raise exception 'MAX_CANNOT_DECREASE';
  end if;

  insert into public.max_bids (auction_id, bidder_id, max_amount, set_at)
  values (p_auction_id, v_bidder, p_max, v_now)
  on conflict (auction_id, bidder_id)
  do update set max_amount = excluded.max_amount, set_at = excluded.set_at;

  v_before := v_auction;
  v_auction := public.apply_max_bids(p_auction_id, v_now);

  -- Only a maximum that produced a bid counts for anti-sniping.
  if v_auction.current_price <> v_before.current_price then
    v_auction := public.extend_if_closing(p_auction_id, v_now);
  end if;
  return v_auction;
end;
$$;

revoke execute on function public.apply_max_bids(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.extend_if_closing(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.set_max_bid(uuid, numeric) from public, anon, authenticated;
grant execute on function public.set_max_bid(uuid, numeric) to authenticated;
