-- The spending limit becomes the user's own tool (developer's decision, 2026-10-24):
--   * a sliding window the user picks: "at most this much in the last N hours/days",
--     not a calendar day (a calendar day lets someone spend the limit twice around
--     midnight; a sliding window has no edge to cross);
--   * the user can reset the window (start counting from now) or switch the limit off.
-- No row still means the default: on, ₺2.000 in the last 1 day.

alter table public.spending_limits rename column daily_limit to limit_amount;
alter table public.spending_limits
  rename constraint spending_limits_daily_limit_positive to spending_limits_limit_amount_positive;

alter table public.spending_limits
  add column period interval not null default interval '1 day',
  add column enabled boolean not null default true,
  -- Set by reset_spending_window(): auctions won before it no longer count.
  add column reset_at timestamptz,
  add constraint spending_limits_period_range
    check (period >= interval '1 hour' and period <= interval '365 days');

-- The app writes the settings; reset_at only through reset_spending_window().
revoke all on public.spending_limits from anon, authenticated;
grant select, insert (user_id, limit_amount, period, enabled),
  update (limit_amount, period, enabled)
  on public.spending_limits to authenticated;

-- committed_in_window: what counts against the caller's limit now.
--   * every auction they lead that is still running: a live commitment, whatever the
--     window or a reset says;
--   * every auction they won (time up, still leading) inside the window: within the last
--     `period`, and not before their last reset.
-- Until M5 marks finished auctions 'ended', a 'live' one whose time is up counts as won.
create function public.committed_in_window()
returns numeric
language sql
stable
set search_path = ''
as $$
  with settings as (
    select
      coalesce(
        (select period from public.spending_limits where user_id = auth.uid()),
        interval '1 day'
      ) as period,
      (select reset_at from public.spending_limits where user_id = auth.uid()) as reset_at
  )
  select coalesce(sum(a.current_price), 0)::numeric(12, 2)
  from public.auctions a, settings s
  where a.current_winner_id = auth.uid()
    and a.status in ('live', 'ended')
    and (a.ends_at > now()
         or a.ends_at > greatest(now() - s.period, coalesce(s.reset_at, '-infinity')));
$$;

revoke execute on function public.committed_in_window() from public, anon, authenticated;
grant execute on function public.committed_in_window() to authenticated;

drop function public.committed_today();

-- reset_spending_window: start counting from now. Creates the row with the defaults if
-- the user never changed their settings.
create function public.reset_spending_window()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  insert into public.spending_limits (user_id, limit_amount, reset_at)
  values (v_user, 2000.00, now())
  on conflict (user_id) do update set reset_at = excluded.reset_at;
end;
$$;

revoke execute on function public.reset_spending_window() from public, anon, authenticated;
grant execute on function public.reset_spending_window() to authenticated;

-- place_bid against the window. Same rules and locks as before; the limit check reads
-- the user's settings (or the default) and is skipped when they switched it off.
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
  v_limit public.spending_limits;
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
  -- Locking the bidder's profile first makes one person's bids on different auctions
  -- wait for each other, so each is judged against the total including the other.
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

  -- The leader cannot bid again (ALREADY_WINNING), so this bid never replaces one that
  -- is already counted.
  select * into v_limit from public.spending_limits where user_id = v_bidder;
  if coalesce(v_limit.enabled, true)
     and public.committed_in_window() + p_amount > coalesce(v_limit.limit_amount, 2000.00) then
    raise exception 'SPENDING_LIMIT_EXCEEDED';
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
