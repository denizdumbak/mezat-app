-- Maximum (proxy) bids: set_max_bid, the automatic answers inside place_bid, ties,
-- anti-sniping and privacy.
-- Attacker cases: reading someone else's maximum, writing max_bids directly, the seller
-- setting a maximum, anon calling set_max_bid, lowering a maximum.
-- Every auction starts at 100 with a minimum step of 10.
begin;
select plan(42);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'dave' where id = '44444444-4444-4444-4444-444444444444';
update public.profiles set username = 'erin' where id = '55555555-5555-5555-5555-555555555555';

-- 1: the main story. 2: equal maximums. 3: a tap equal to an earlier maximum.
-- 4: 10 seconds left. 5: scheduled.
insert into public.auctions
  (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
select ('aaaaaaaa-0000-0000-0000-00000000000' || n)::uuid,
       '11111111-1111-1111-1111-111111111111', 'Item ' || n, 100.00, 10.00, 30, now()
from generate_series(1, 5) n;
update public.auctions set status = 'live', ends_at = now() + interval '30 minutes'
where id in ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
             'aaaaaaaa-0000-0000-0000-000000000003');
update public.auctions set status = 'live', ends_at = now() + interval '10 seconds'
where id = 'aaaaaaaa-0000-0000-0000-000000000004';

create function pg_temp.act_as(user_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
$$;
create function pg_temp.act_as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
$$;
-- 'price winner' of an auction, e.g. '160.00 bob'.
create function pg_temp.state(p_auction uuid) returns text language sql as $$
  select a.current_price::text || ' ' || p.username
  from public.auctions a join public.profiles p on p.id = a.current_winner_id
  where a.id = p_auction;
$$;
-- The bids of an auction in feed order, e.g. 'bob 110.00 auto, dave 150.00'.
create function pg_temp.feed(p_auction uuid) returns text language sql as $$
  select string_agg(p.username || ' ' || b.amount::text || case when b.is_auto then ' auto' else '' end,
                    ', ' order by b.created_at)
  from public.bids b join public.profiles p on p.id = b.bidder_id
  where b.auction_id = p_auction;
$$;

-- Schema --------------------------------------------------------------------
select has_table('public', 'max_bids', 'max_bids table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.max_bids'::regclass),
  'RLS is enabled on max_bids'
);
select col_type_is('public', 'max_bids', 'max_amount', 'numeric(12,2)',
  'money is numeric(12,2), not float');

-- 1. The main story ---------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 200.00) $$,
  'bob sets a maximum of 200'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '110.00 bob',
  'a maximum on a fresh auction opens at start price + one step');
select is(pg_temp.feed('aaaaaaaa-0000-0000-0000-000000000001'), 'bob 110.00 auto',
  'the opening bid is recorded as automatic');

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is(
  (select count(*) from public.max_bids), 0::bigint,
  'dave cannot see bob''s maximum'
);
select is(
  (select current_price from public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 150.00)),
  160.00::numeric,
  'dave taps 150; place_bid returns the price after bob''s maximum answered'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '160.00 bob',
  'bob''s maximum answers one step above dave');
select is(pg_temp.feed('aaaaaaaa-0000-0000-0000-000000000001'),
  'bob 110.00 auto, dave 150.00, bob 160.00 auto',
  'the feed shows dave''s bid and bob''s automatic answer, in order');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is(
  (select max_amount from public.max_bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  200.00::numeric, 'bob can read his own maximum'
);
reset role;

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 250.00) $$,
  'dave taps 250, above bob''s maximum'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '250.00 dave',
  'a bid above the maximum wins; the exhausted maximum stays silent');

select pg_temp.act_as('55555555-5555-5555-5555-555555555555');
select lives_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 300.00) $$,
  'erin sets a maximum of 300'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '260.00 erin',
  'a new maximum bids one step above the leader at once');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 400.00) $$,
  'bob raises his maximum to 400'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '310.00 bob',
  'two maximums: the higher wins at the other''s maximum + one step');
select is(pg_temp.feed('aaaaaaaa-0000-0000-0000-000000000001'),
  'bob 110.00 auto, dave 150.00, bob 160.00 auto, dave 250.00, erin 260.00 auto, '
  'erin 300.00 auto, bob 310.00 auto',
  'the feed shows erin''s last word at her maximum, then bob''s answer, not every step');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 450.00) $$,
  'the leader may raise his own maximum'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '310.00 bob',
  'raising your own maximum while leading does not raise the price');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 420.00) $$,
  'P0001', 'MAX_CANNOT_DECREASE', 'a maximum cannot be lowered'
);
reset role;

select pg_temp.act_as('55555555-5555-5555-5555-555555555555');
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 315.00) $$,
  'P0001', 'MAX_TOO_LOW', 'a maximum below price + one step is refused'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 320.00) $$,
  'erin taps the minimum bid'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000001'), '330.00 bob',
  'bob''s raised maximum keeps answering');

-- 2. Equal maximums: the earlier one wins -----------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000002', 200.00);
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select lives_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000002', 200.00) $$,
  'dave sets the same maximum later'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000002'), '200.00 bob',
  'of two equal maximums the earlier wins, at that amount');
select is(pg_temp.feed('aaaaaaaa-0000-0000-0000-000000000002'),
  'bob 110.00 auto, dave 200.00 auto, bob 200.00 auto',
  'the feed shows the tie');

-- 3. A tap equal to an earlier maximum --------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000003', 200.00);
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 200.00) $$,
  'dave taps exactly bob''s maximum'
);
reset role;
select is(pg_temp.state('aaaaaaaa-0000-0000-0000-000000000003'), '200.00 bob',
  'the earlier maximum beats a later bid of the same amount');

-- 4. Anti-sniping -----------------------------------------------------------
create temp table closing_end as
  select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000004';
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000004', 200.00);
reset role;
select is(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  (select ends_at + interval '30 seconds' from closing_end),
  'a maximum that bids in the last 30 seconds extends the end'
);
update closing_end set ends_at = ends_at + interval '30 seconds';
-- Back inside the window, then a raise that bids nothing.
update public.auctions set ends_at = now() + interval '10 seconds'
where id = 'aaaaaaaa-0000-0000-0000-000000000004';
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000004', 300.00);
reset role;
select is(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  now() + interval '10 seconds',
  'raising a maximum without a new bid does not extend the end'
);
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.place_bid('aaaaaaaa-0000-0000-0000-000000000004', 150.00);
reset role;
select is(
  (select ends_at from public.auctions where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  now() + interval '40 seconds',
  'a tap answered by a maximum extends the end once'
);

-- Refusals ------------------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000005', 500.00) $$,
  'P0001', 'AUCTION_NOT_LIVE', 'no maximum on an auction that has not started'
);
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 500.001) $$,
  'P0001', 'INVALID_AMOUNT', 'a maximum with more than two decimals is refused'
);
reset role;

-- Attacker ------------------------------------------------------------------
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 9999.00) $$,
  'P0001', 'SELLER_CANNOT_BID', 'the seller cannot set a maximum on their own auction'
);
select is((select count(*) from public.max_bids), 0::bigint,
  'the seller cannot see the maximums on their auction');
reset role;

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select throws_ok(
  $$ insert into public.max_bids (auction_id, bidder_id, max_amount)
     values ('aaaaaaaa-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 9999) $$,
  '42501', null, 'a user cannot write a maximum directly'
);
select throws_ok(
  $$ update public.max_bids set max_amount = 1 $$,
  '42501', null, 'a user cannot change maximums directly'
);
select throws_ok(
  $$ select public.apply_max_bids('aaaaaaaa-0000-0000-0000-000000000001', now()) $$,
  '42501', null, 'the internal apply_max_bids cannot be called'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ select public.set_max_bid('aaaaaaaa-0000-0000-0000-000000000001', 500.00) $$,
  '42501', null, 'anon cannot call set_max_bid'
);
select throws_ok(
  $$ select count(*) from public.max_bids $$,
  '42501', null, 'anon cannot read maximums'
);
reset role;

select is(
  (select max_amount from public.max_bids
   where auction_id = 'aaaaaaaa-0000-0000-0000-000000000001'
     and bidder_id = '22222222-2222-2222-2222-222222222222'),
  450.00::numeric, 'bob''s maximum is unchanged after the attempts'
);

select * from finish();
rollback;
