-- place_bid: the only way a bid gets in. Checks every rule on the server, with the
-- auction row locked, so two bids arriving together are judged one after the other.
-- Errors are raised with a code as the message (same convention as start_auction),
-- which the app maps to Turkish text.

create function public.place_bid(p_auction_id uuid, p_amount numeric)
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

revoke execute on function public.place_bid(uuid, numeric) from public, anon, authenticated;
grant execute on function public.place_bid(uuid, numeric) to authenticated;
