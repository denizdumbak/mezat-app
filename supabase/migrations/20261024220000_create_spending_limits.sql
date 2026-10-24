-- Daily spending limit (PRODUCT.md, "Güvenlik katmanı"), enforced in place_bid so a
-- modified client cannot skip it.
--
-- Its own table, not a profiles column: profiles are readable by everyone, and a limit
-- is private (it would also tell rivals how far someone can go). No row means the
-- default, ₺2.000, the same as BidSafetyConfig.defaultDailyLimitAmount in the app.

create table public.spending_limits (
  user_id uuid primary key default auth.uid() references public.profiles (id) on delete cascade,
  daily_limit numeric(12, 2) not null,
  updated_at timestamptz not null default now(),
  constraint spending_limits_daily_limit_positive check (daily_limit > 0)
);

alter table public.spending_limits enable row level security;

create policy "Users read their own limit"
  on public.spending_limits for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Users set their own limit"
  on public.spending_limits for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Users change their own limit"
  on public.spending_limits for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Upsert from the app: insert (user_id, daily_limit) or update daily_limit only.
revoke all on public.spending_limits from anon, authenticated;
grant select, insert (user_id, daily_limit), update (daily_limit)
  on public.spending_limits to authenticated;

create function public.touch_spending_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger spending_limits_touch
  before insert or update on public.spending_limits
  for each row execute function public.touch_spending_limit();

revoke execute on function public.touch_spending_limit() from public, anon, authenticated;

-- committed_today: the caller's total for today, the sum of the auctions they lead
-- (still running) or won today. Auctions are public, so this reads them with the caller's
-- own rights. "Today" is the Turkish calendar day. Until M5 marks finished auctions
-- 'ended', a 'live' one whose time is up counts as won on the day it ended.
create function public.committed_today()
returns numeric
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(a.current_price), 0)::numeric(12, 2)
  from public.auctions a
  where a.current_winner_id = auth.uid()
    and a.status in ('live', 'ended')
    and (a.ends_at > now()
         or (a.ends_at at time zone 'Europe/Istanbul')::date
            = (now() at time zone 'Europe/Istanbul')::date);
$$;

revoke execute on function public.committed_today() from public, anon, authenticated;
grant execute on function public.committed_today() to authenticated;

-- place_bid with the daily limit. Same rules as before, plus:
--   * the bidder's profile row is locked first, so one person's bids on different
--     auctions are judged one after the other against the same total (otherwise two
--     bids at once could each fit the limit and together pass it). Always profile, then
--     auction: the same order everywhere, so two bids cannot wait for each other;
--   * DAILY_LIMIT_EXCEEDED when today's total plus this bid passes the limit. The leader
--     cannot bid again (ALREADY_WINNING), so the bid never replaces one already counted.
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
  v_limit numeric(12, 2);
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
  -- "no key update": does not block the key-share locks that foreign keys take.
  perform 1 from public.profiles
  where id = v_bidder and username is not null
  for no key update;
  if not found then
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

  select coalesce(
    (select daily_limit from public.spending_limits where user_id = v_bidder),
    2000.00
  ) into v_limit;
  if public.committed_today() + p_amount > v_limit then
    raise exception 'DAILY_LIMIT_EXCEEDED';
  end if;

  insert into public.bids (auction_id, bidder_id, amount, created_at)
  values (p_auction_id, v_bidder, p_amount, v_now);

  -- Anti-sniping: a bid in the last 30 seconds moves the end 30 seconds later, so a
  -- last-second bid cannot win without giving others time to answer. Same numbers as
  -- antiSnipingWindow / antiSnipingExtension in lib/core/auction_rules.dart.
  update public.auctions
  set current_price = p_amount,
      current_winner_id = v_bidder,
      ends_at = case
        when ends_at - v_now <= interval '30 seconds' then ends_at + interval '30 seconds'
        else ends_at
      end
  where id = p_auction_id
  returning * into v_auction;

  return v_auction;
end;
$$;
