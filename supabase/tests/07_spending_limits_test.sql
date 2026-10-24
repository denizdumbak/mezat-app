-- Spending limit: the sliding window, the user's period, reset and switch-off,
-- committed_in_window, SPENDING_LIMIT_EXCEEDED in place_bid, and privacy.
-- Attacker cases: reading or changing someone else's settings, creating settings for
-- someone else, writing reset_at directly, anon reading settings or calling the
-- functions, out-of-range values.
begin;
select plan(43);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'dave' where id = '44444444-4444-4444-4444-444444444444';

-- alice's auctions, all starting at 100 with a step of 10.
--   1 bob leads at 800          2, 3, 7 open, no bids
--   4 bob won 23 hours ago, 500 5 bob won 25 hours ago, 900
--   6 time up an hour ago, still 'live' until M5, bob at 100
insert into public.auctions
  (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
select ('aaaaaaaa-0000-0000-0000-00000000000' || n)::uuid,
       '11111111-1111-1111-1111-111111111111', 'Item ' || n, 100.00, 10.00, 30, now()
from generate_series(1, 7) n;
update public.auctions set status = 'live', ends_at = now() + interval '30 minutes'
where id in ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
             'aaaaaaaa-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000007');
update public.auctions
set current_price = 800, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.auctions
set status = 'ended', ends_at = now() - interval '23 hours',
    current_price = 500, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000004';
update public.auctions
set status = 'ended', ends_at = now() - interval '25 hours',
    current_price = 900, current_winner_id = '22222222-2222-2222-2222-222222222222'
where id = 'aaaaaaaa-0000-0000-0000-000000000005';
update public.auctions
set status = 'live', ends_at = now() - interval '1 hour',
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
-- bob's committed_in_window(), read as bob.
create function pg_temp.bob_total() returns numeric language plpgsql as $$
declare
  v numeric;
begin
  perform pg_temp.act_as('22222222-2222-2222-2222-222222222222');
  v := public.committed_in_window();
  reset role;
  return v;
end;
$$;

-- Schema --------------------------------------------------------------------
select has_table('public', 'spending_limits', 'spending_limits table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.spending_limits'::regclass),
  'RLS is enabled on spending_limits'
);
select col_type_is('public', 'spending_limits', 'limit_amount', 'numeric(12,2)',
  'money is numeric(12,2), not float');
select col_default_is('public', 'spending_limits', 'period', '1 day',
  'the window defaults to one day');
select col_default_is('public', 'spending_limits', 'enabled', 'true',
  'the limit is on by default');
select hasnt_column('public', 'profiles', 'daily_limit',
  'the limit is not on the public profiles table');
select hasnt_function('public', 'committed_today', 'committed_today is replaced');

-- The default window: on, ₺2.000, last 1 day --------------------------------
select is(pg_temp.bob_total(), 1400.00::numeric,
  'leading 800 + won 23 h ago 500 + time up 1 h ago 100; not 25 h ago');
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is(public.committed_in_window(), 0.00::numeric, 'dave has nothing in his window');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 600.01) $$,
  'P0001', 'SPENDING_LIMIT_EXCEEDED', 'a bid that takes the total past ₺2.000 is refused'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000002', 600.00) $$,
  'a bid that takes the total to exactly the limit is accepted'
);
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 110.00) $$,
  'P0001', 'SPENDING_LIMIT_EXCEEDED', 'at the limit, even the smallest bid is refused'
);
reset role;
select is(
  (select count(*) from public.bids where auction_id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  0::bigint, 'the refused bid is not recorded'
);

-- Choosing an amount and a period -------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ insert into public.spending_limits (limit_amount) values (5000.00) $$,
  'bob sets his own amount'
);
select is(
  (select user_id from public.spending_limits), '22222222-2222-2222-2222-222222222222'::uuid,
  'the row is bob''s (user_id from the JWT)'
);
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000003', 110.00) $$,
  'with a higher amount the bid goes through'
);
update public.spending_limits set period = interval '7 days';
reset role;
select is(pg_temp.bob_total(), 3010.00::numeric,
  'one week: the auction won 25 hours ago counts too');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
update public.spending_limits set period = interval '6 hours';
reset role;
select is(pg_temp.bob_total(), 1610.00::numeric,
  'six hours: the auction won 23 hours ago no longer counts; leading bids always do');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ update public.spending_limits set period = interval '36 hours' $$,
  'a custom period is allowed'
);
reset role;
select is(pg_temp.bob_total(), 3010.00::numeric, '36 hours reaches back past 25 hours');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$ update public.spending_limits set limit_amount = 3000.00 $$,
  'bob changes his amount'
);
select throws_ok(
  $$ update public.spending_limits set limit_amount = 0 $$,
  '23514', null, 'an amount must be above zero'
);
select throws_ok(
  $$ update public.spending_limits set period = interval '30 minutes' $$,
  '23514', null, 'a period is at least one hour'
);
select throws_ok(
  $$ update public.spending_limits set period = interval '400 days' $$,
  '23514', null, 'a period is at most a year'
);
select throws_ok(
  $$ update public.spending_limits set reset_at = now() + interval '1 year' $$,
  '42501', null, 'reset_at is written only by reset_spending_window'
);
reset role;

-- Being outbid frees the amount ---------------------------------------------
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.place_bid('aaaaaaaa-0000-0000-0000-000000000001', 900.00);
reset role;
select is(pg_temp.bob_total(), 2210.00::numeric, 'outbid on the 800 auction: 3010 - 800');

-- Reset ---------------------------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select lives_ok($$ select public.reset_spending_window() $$, 'bob resets his window');
reset role;
select is(pg_temp.bob_total(), 710.00::numeric,
  'after a reset only the auctions he still leads count (600 + 110)');
select is(
  (select period::text || ' ' || limit_amount::text from public.spending_limits
   where user_id = '22222222-2222-2222-2222-222222222222'),
  '36:00:00 3000.00', 'a reset keeps the period and the amount'
);

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.reset_spending_window();
reset role;
select is(
  (select limit_amount::text || ' ' || period::text || ' ' || enabled::text
   from public.spending_limits where user_id = '44444444-4444-4444-4444-444444444444'),
  '2000.00 1 day true', 'a reset without settings creates them with the defaults'
);

-- Switching the limit off ---------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
update public.spending_limits set limit_amount = 1000.00;
select throws_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000007', 500.00) $$,
  'P0001', 'SPENDING_LIMIT_EXCEEDED', '710 + 500 is over 1000'
);
update public.spending_limits set enabled = false;
select lives_ok(
  $$ select public.place_bid('aaaaaaaa-0000-0000-0000-000000000007', 500.00) $$,
  'with the limit switched off the same bid goes through'
);
reset role;

-- Attacker: other people's settings -----------------------------------------
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select is((select count(*) from public.spending_limits
           where user_id = '22222222-2222-2222-2222-222222222222'), 0::bigint,
  'dave cannot see bob''s settings');
select throws_ok(
  $$ insert into public.spending_limits (user_id, limit_amount)
     values ('11111111-1111-1111-1111-111111111111', 1.00) $$,
  '42501', null, 'dave cannot create settings for alice'
);
select lives_ok(
  $$ update public.spending_limits set enabled = true, limit_amount = 1.00
     where user_id = '22222222-2222-2222-2222-222222222222' $$,
  'dave''s update of bob''s settings runs but matches nothing'
);
select throws_ok(
  $$ update public.spending_limits set updated_at = now() $$,
  '42501', null, 'updated_at is not writable'
);
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ update public.spending_limits set user_id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'bob cannot move his row to alice'
);
select throws_ok(
  $$ delete from public.spending_limits $$,
  '42501', null, 'settings are not deleted from the app'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ select count(*) from public.spending_limits $$,
  '42501', null, 'anon cannot read settings'
);
select throws_ok(
  $$ select public.committed_in_window() $$,
  '42501', null, 'anon cannot call committed_in_window'
);
select throws_ok(
  $$ select public.reset_spending_window() $$,
  '42501', null, 'anon cannot call reset_spending_window'
);
reset role;

select is(
  (select limit_amount::text || ' ' || period::text || ' ' || enabled::text
   from public.spending_limits where user_id = '22222222-2222-2222-2222-222222222222'),
  '1000.00 36:00:00 false', 'bob''s settings are unchanged after the attempts'
);
select is(
  (select count(*) from public.spending_limits
   where user_id = '11111111-1111-1111-1111-111111111111'),
  0::bigint, 'no settings were created for alice'
);

select * from finish();
rollback;
