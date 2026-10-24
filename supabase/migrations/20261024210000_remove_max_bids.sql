-- Maximum (proxy) bids are removed (developer's decision, 2026-10-24): the highest bid
-- wins, every bid is tapped by a person, and an automatic answer goes against how a live
-- auction works. place_bid goes back to judging only the bid it receives.
-- "if exists": a local database may also hold cancel_max_bid from an unreleased draft.

drop function if exists public.set_max_bid(uuid, numeric);
drop function if exists public.cancel_max_bid(uuid);

-- place_bid: same rules as in 20261024200100_create_place_bid.sql.
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

-- The helpers are unused once place_bid no longer calls them.
drop function if exists public.apply_max_bids(uuid, timestamptz);
drop function if exists public.extend_if_closing(uuid, timestamptz);
drop table if exists public.max_bids;

-- Every bid is a person's now.
alter table public.bids drop column if exists is_auto;
