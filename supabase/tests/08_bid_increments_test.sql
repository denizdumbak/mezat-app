-- bid_increments: the seller's increment chips, checked at insert.
-- Attacker cases: chips below the minimum, too many chips, changing them later,
-- calling the trigger function directly.
begin;
select plan(13);

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'alice@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';

create function pg_temp.act_as(user_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
$$;

-- Inserts an auction with min_increment 10 and the given chips.
create function pg_temp.create_with(title text, increments numeric[]) returns void
language sql as $$
  insert into public.auctions
    (title, start_price, min_increment, duration_minutes, starts_at, bid_increments)
  values (title, 100, 10, 30, now(), increments);
$$;

select col_type_is('public', 'auctions', 'bid_increments', 'numeric(12,2)[]',
  'chips are numeric(12,2), not float');

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');

-- Valid chips ---------------------------------------------------------------
select lives_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('No chips', 100, 10, 30, now()) $$,
  'chips are optional'
);
select is(
  (select bid_increments from public.auctions where title = 'No chips'),
  '{}'::numeric[],
  'no chips is stored as an empty list'
);
select lives_ok(
  $$ select pg_temp.create_with('Three chips', '{10, 25.50, 100}') $$,
  'up to three ascending chips, the first equal to the minimum'
);
select is(
  (select bid_increments from public.auctions where title = 'Three chips'),
  '{10.00, 25.50, 100.00}'::numeric[],
  'chips are stored in the given order'
);
select lives_ok(
  $$ select pg_temp.create_with('One chip', '{50}') $$,
  'a single chip is fine'
);

-- Invalid chips -------------------------------------------------------------
select throws_ok(
  $$ select pg_temp.create_with('Below minimum', '{5, 50}') $$,
  'P0001', 'INVALID_INCREMENTS',
  'a chip below min_increment is refused'
);
select throws_ok(
  $$ select pg_temp.create_with('Too many', '{10, 20, 30, 40}') $$,
  'P0001', 'INVALID_INCREMENTS',
  'more than three chips are refused'
);
select throws_ok(
  $$ select pg_temp.create_with('Unordered', '{50, 20}') $$,
  'P0001', 'INVALID_INCREMENTS',
  'chips out of order are refused'
);
select throws_ok(
  $$ select pg_temp.create_with('Repeated', '{20, 20}') $$,
  'P0001', 'INVALID_INCREMENTS',
  'a repeated chip is refused'
);
select throws_ok(
  $$ select pg_temp.create_with('With null', array[20, null]::numeric[]) $$,
  'P0001', 'INVALID_INCREMENTS',
  'an empty chip is refused'
);

-- Attacker: changing chips later -------------------------------------------
select throws_ok(
  $$ update public.auctions set bid_increments = '{1}' where title = 'Three chips' $$,
  '42501', null,
  'the seller cannot change the chips after creating the auction'
);
select throws_ok(
  $$ select public.check_bid_increments() $$,
  '42501', null,
  'the trigger function is not callable'
);
reset role;

select * from finish();
rollback;
