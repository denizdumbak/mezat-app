-- place_bid: a valid bid, every refusal code and anti-sniping.
-- Attacker cases: anon calling it, bidding in someone else's name is impossible (the
-- bidder comes from the JWT), the seller bidding, amounts that break numeric(12,2).
begin;
select plan(37);

-- alice sells; bob and dave bid; carol has not chosen a username.
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'dave' where id = '44444444-4444-4444-4444-444444444444';

-- live: 30 minutes left. closing: 10 seconds left. over: time is up, still 'live'.
-- scheduled: not started. ended / cancelled: closed by the server.
insert into public.auctions
  (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Live item', 100.00, 10.00, 30, now()),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'Closing item', 100.00, 10.00, 30, now()),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   'Over item', 100.00, 10.00, 30, now()),
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   'Scheduled item', 100.00, 10.00, 30, now()),
  ('aaaaaaaa-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   'Ended item', 100.00, 10.00, 30, now()),
  ('aaaaaaaa-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   'Cancelled item', 100.00, 10.00, 30, now());
update public.auctions set status = 'live', ends_at = now() + interval '30 minutes'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.auctions set status = 'live', ends_at = now() + interval '10 seconds'
where id = 'aaaaaaaa-0000-0000-0000-000000000002';
update public.auctions set status = 'live', ends_at = now() - interval '1 second'
where id = 'aaaaaaaa-0000-0000-0000-000000000003';
update public.auctions set status = 'ended', ends_at = now() + interval '30 minutes'
where id = 'aaaaaaaa-0000-0000-0000-000000000005';
update public.auctions set status = 'cancelled', ends_at = now() + interval '30 minutes'
where id = 'aaaaaaaa-0000-0000-0000-000000000006';

create function pg_temp.act_as(user_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
$$;
create function pg_temp.act_as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
$$;

-- A valid bid ---------------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 110.00) $$,
  'a bid of current price + minimum step is accepted'
);
reset role;

select is(
  (select current_price from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  110.00::numeric, 'current_price moves to the bid'
);
select is(
  (select current_winner_id from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '22222222-2222-2222-2222-222222222222'::uuid, 'the bidder leads'
);
select is(
  (select count(*) from public.bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1::bigint, 'the bid is recorded'
);
select is(
  (select bidder_id from public.bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '22222222-2222-2222-2222-222222222222'::uuid, 'bidder_id comes from the JWT'
);
select hasnt_table('public', 'max_bids', 'no maximum bids: nothing bids on anyone''s behalf');
select hasnt_function('public', 'set_max_bid', 'no set_max_bid');
select ok(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000001')
    < now() + interval '30 minutes 1 second',
  'a bid with time to spare does not extend the auction'
);

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is(
  (select current_price from public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 175.50)),
  175.50::numeric, 'a higher bid than the minimum is accepted and returned'
);
reset role;
select is(
  (select current_winner_id from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '44444444-4444-4444-4444-444444444444'::uuid, 'the new bidder takes the lead'
);

-- Refusals ------------------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 185.49) $$,
  'P0001', 'BID_TOO_LOW', 'a bid below current price + minimum step is refused'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 175.50) $$,
  'P0001', 'BID_TOO_LOW', 'matching the current price is refused'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 185.50) $$,
  'exactly current price + minimum step is accepted'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 300.00) $$,
  'P0001', 'ALREADY_WINNING', 'the leader cannot outbid themselves'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 500.00) $$,
  'P0001', 'AUCTION_ENDED', 'a bid after the end is refused, even while status is live'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000004', 500.00) $$,
  'P0001', 'AUCTION_NOT_LIVE', 'a scheduled auction takes no bids'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-00000000ffff', 500.00) $$,
  'P0001', 'AUCTION_NOT_FOUND', 'an unknown auction is reported'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 400.001) $$,
  'P0001', 'INVALID_AMOUNT', 'more than two decimals is refused, not rounded'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', -5) $$,
  'P0001', 'INVALID_AMOUNT', 'a negative amount is refused'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', null) $$,
  'P0001', 'INVALID_AMOUNT', 'a missing amount is refused'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 10000000000) $$,
  'P0001', 'INVALID_AMOUNT', 'an amount beyond numeric(12,2) is refused'
);
reset role;

-- Attacker: who may bid -----------------------------------------------------
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 500.00) $$,
  'P0001', 'SELLER_CANNOT_BID', 'the seller cannot bid on their own auction'
);
reset role;

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 500.00) $$,
  'P0001', 'USERNAME_REQUIRED', 'a user without a username cannot bid'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 500.00) $$,
  '42501', null, 'anon cannot call place_bid'
);
reset role;

select is(
  (select current_price from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  185.50::numeric, 'refused bids leave the price alone'
);
select is(
  (select count(*) from public.bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  3::bigint, 'refused bids are not recorded'
);
select is(
  (select count(*) from public.bids where auction_id in ('aaaaaaaa-0000-0000-0000-000000000003',
    'aaaaaaaa-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-00000000ffff')),
  0::bigint, 'no bids on the ended, scheduled or unknown auctions'
);

-- Anti-sniping --------------------------------------------------------------
create temp table closing_end as
  select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000002';
grant select on closing_end to authenticated;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 110.00) $$,
  'a bid in the last 30 seconds is accepted'
);
reset role;
select is(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  (select ends_at + interval '30 seconds' from closing_end),
  'a bid in the last 30 seconds extends the end by 30 seconds'
);

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 120.00) $$,
  'the next bid, now with 40 seconds left, is accepted'
);
reset role;
select is(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  (select ends_at + interval '30 seconds' from closing_end),
  'a bid with more than 30 seconds left does not extend again'
);

-- More refusals and the outbid bidder --------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000005', 500.00) $$,
  'P0001', 'AUCTION_NOT_LIVE', 'an ended auction takes no bids, even with time on the clock'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000006', 500.00) $$,
  'P0001', 'AUCTION_NOT_LIVE', 'a cancelled auction takes no bids'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 130.00) $$,
  'an outbid bidder may bid again'
);

-- Attacker: a bidder skipping place_bid -------------------------------------
select throws_ok(
  $$ update public.auctions set current_winner_id = '22222222-2222-2222-2222-222222222222'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', null, 'a bidder cannot make themselves the winner'
);
select throws_ok(
  $$ update public.auctions set ends_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', null, 'a bidder cannot end an auction early'
);
reset role;

-- Not callable around the rules ---------------------------------------------
select ok(
  (select prosecdef from pg_proc where oid = 'public.place_bid(uuid, numeric)'::regprocedure),
  'place_bid runs as its owner (security definer), the only writer of bids'
);

select * from finish();
rollback;
