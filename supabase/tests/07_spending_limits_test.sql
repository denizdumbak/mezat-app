-- Daily spending limit: spending_limits (privacy, who may write), committed_today and
-- DAILY_LIMIT_EXCEEDED in place_bid.
-- Attacker cases: reading or changing someone else's limit, setting a limit for someone
-- else, anon reading limits or calling committed_today, a zero limit.
begin;
select plan(26);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'dave' where id = '44444444-4444-4444-4444-444444444444';

-- Midnight in Istanbul today: "won today" and "won yesterday" sit exactly on either side,
-- so the test does not depend on what time it runs.
create temp table day as
  select (date_trunc('day', now() at time zone 'Europe/Istanbul')
          at time zone 'Europe/Istanbul') as starts;

-- alice's auctions, all starting at 100 with a step of 10.
--   1 leading (bob 800)   2, 3 open, no bids   4 won today (bob 500)
--   5 won yesterday (bob 900)   6 time up today, still 'live' until M5 (bob 100)
insert into public.auctions
  (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
select ('aaaaaaaa-0000-0000-0000-00000000000' || n)::uuid,
       '11111111-1111-1111-1111-111111111111', 'Item ' || n, 100.00, 10.00, 30, now()
from generate_series(1, 6) n;
update public.auctions set status = 'live', ends_at = now() + interval '30 minutes'
where id in ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
             'aaaaaaaa-0000-0000-0000-000000000003');
update public.auctions
set current_price = 800, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.auctions
set status = 'ended', ends_at = (select starts from day),
    current_price = 500, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000004';
update public.auctions
set status = 'ended', ends_at = (select starts - interval '1 second' from day),
    current_price = 900, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000005';
update public.auctions
set status = 'live', ends_at = (select starts from day),
    current_price = 100, current_winner_id = '22222222-2222-2222-2222-222222222222'
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

-- Schema --------------------------------------------------------------------
select has_table('public', 'spending_limits', 'spending_limits table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.spending_limits'::regclass),
  'RLS is enabled on spending_limits'
);
select col_type_is('public', 'spending_limits', 'daily_limit', 'numeric(12,2)',
  'money is numeric(12,2), not float');
select hasnt_column('public', 'profiles', 'daily_limit',
  'the limit is not on the public profiles table');

-- committed_today -----------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is(public.committed_today(), 1400.00::numeric,
  'bob''s total: leading 800 + won today 500 + time up today 100, not yesterday''s 900');
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is(public.committed_today(), 0.00::numeric, 'dave has nothing today');
reset role;

-- place_bid against the default limit (₺2.000) -----------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 600.01) $$,
  'P0001', 'DAILY_LIMIT_EXCEEDED', 'a bid that takes the total past ₺2.000 is refused'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 600.00) $$,
  'a bid that takes the total to exactly the limit is accepted'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 110.00) $$,
  'P0001', 'DAILY_LIMIT_EXCEEDED', 'at the limit, even the smallest bid is refused'
);
select is(
  (select count(*) from public.bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  0::bigint, 'the refused bid is not recorded'
);

-- Setting your own limit ----------------------------------------------------
select lives_ok(
  $$ insert into public.spending_limits (daily_limit) values (5000.00) $$,
  'bob sets his own limit'
);
select is(
  (select user_id from public.spending_limits), '22222222-2222-2222-2222-222222222222'::uuid,
  'the row is bob''s (user_id from the JWT)'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 110.00) $$,
  'with a higher limit the bid goes through'
);
select lives_ok(
  $$ update public.spending_limits set daily_limit = 3000.00 $$,
  'bob changes his limit'
);
select throws_ok(
  $$ update public.spending_limits set daily_limit = 0 $$,
  '23514', null, 'a limit must be above zero'
);
reset role;

-- Being outbid frees the amount ---------------------------------------------
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 900.00);
reset role;
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is(public.committed_today(), 1310.00::numeric,
  'outbid on the 800 auction: 2110 - 800');
reset role;

-- Attacker: other people's limits -------------------------------------------
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is((select count(*) from public.spending_limits), 0::bigint,
  'dave cannot see bob''s limit');
select throws_ok(
  $$ insert into public.spending_limits (user_id, daily_limit)
     values ('22222222-2222-2222-2222-222222222222', 1.00) $$,
  '42501', null, 'dave cannot set a limit for bob'
);
select lives_ok(
  $$ update public.spending_limits set daily_limit = 1.00
     where user_id = '22222222-2222-2222-2222-222222222222' $$,
  'dave''s update of bob''s limit runs but matches nothing'
);
select throws_ok(
  $$ update public.spending_limits set updated_at = now() $$,
  '42501', null, 'updated_at is not writable'
);
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ update public.spending_limits set user_id = '44444444-4444-4444-4444-444444444444' $$,
  '42501', null, 'bob cannot move his row to dave'
);
select throws_ok(
  $$ delete from public.spending_limits $$,
  '42501', null, 'limits are not deleted from the app'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ select count(*) from public.spending_limits $$,
  '42501', null, 'anon cannot read limits'
);
select throws_ok(
  $$ select public.committed_today() $$,
  '42501', null, 'anon cannot call committed_today'
);
reset role;

select is(
  (select daily_limit from public.spending_limits
   where user_id = '22222222-2222-2222-2222-222222222222'),
  3000.00::numeric, 'bob''s limit is unchanged after the attempts'
);
select is(
  (select count(*) from public.spending_limits
   where user_id in ('11111111-1111-1111-1111-111111111111',
                     '44444444-4444-4444-4444-444444444444')),
  0::bigint, 'no limit was created for alice or dave'
);

select * from finish();
rollback;
