-- auctions: schema, constraints, RLS, column privileges and start_auction.
-- Attacker cases: anon insert, user without a username, posing as another seller,
-- setting status/price/winner from the client, pointing at someone else's photo,
-- updating or deleting rows, starting someone else's auction, calling the trigger.
begin;
select plan(34);

-- alice and bob have usernames; carol signed up but has not chosen one.
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';

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
select has_table('public', 'auctions', 'auctions table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.auctions'::regclass),
  'RLS is enabled on auctions'
);
select col_type_is('public', 'auctions', 'current_price', 'numeric(12,2)',
  'money is numeric(12,2), not float');

-- Creating an auction -------------------------------------------------------
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
  $$ insert into public.auctions
       (title, description, image_path, start_price, min_increment, duration_minutes, starts_at)
     values ('  Vintage camera ', ' Works fine ',
             '11111111-1111-1111-1111-111111111111/camera.jpg',
             150.00, 10.00, 30, now()) $$,
  'user with a username can create an auction'
);
reset role;

select is(
  (select seller_id from public.auctions where title = 'Vintage camera'),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'seller_id comes from the JWT'
);
select is(
  (select status from public.auctions where title = 'Vintage camera'),
  'scheduled',
  'new auction is scheduled'
);
select is(
  (select current_price from public.auctions where title = 'Vintage camera'),
  150.00::numeric,
  'current_price starts at start_price'
);
select is(
  (select ends_at from public.auctions where title = 'Vintage camera'),
  null,
  'ends_at is empty until the auction starts'
);
select is(
  (select description from public.auctions where title = 'Vintage camera'),
  'Works fine',
  'title and description are trimmed'
);

-- Attacker: who may insert --------------------------------------------------
select pg_temp.act_as_anon();
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Anon item', 10, 1, 30, now()) $$,
  '42501', null,
  'anon cannot create auctions'
);
select is(
  (select count(*)::int from public.auctions where title = 'Vintage camera'),
  1,
  'anon can read auctions'
);
reset role;

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('No username', 10, 1, 30, now()) $$,
  '42501', null,
  'user without a username cannot create auctions'
);
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ insert into public.auctions
       (seller_id, title, start_price, min_increment, duration_minutes, starts_at)
     values ('22222222-2222-2222-2222-222222222222', 'Posing as bob', 10, 1, 30, now()) $$,
  '42501', null,
  'user cannot create an auction in someone else''s name'
);
select throws_ok(
  $$ insert into public.auctions
       (title, start_price, min_increment, duration_minutes, starts_at, status)
     values ('Already live', 10, 1, 30, now(), 'live') $$,
  '42501', null,
  'user cannot set status on insert'
);
select throws_ok(
  $$ insert into public.auctions
       (title, start_price, min_increment, duration_minutes, starts_at, current_price)
     values ('Cheap', 10, 1, 30, now(), 1) $$,
  '42501', null,
  'user cannot set current_price on insert'
);
select throws_ok(
  $$ insert into public.auctions
       (title, start_price, min_increment, duration_minutes, starts_at, current_winner_id)
     values ('Pre-won', 10, 1, 30, now(), '11111111-1111-1111-1111-111111111111') $$,
  '42501', null,
  'user cannot set current_winner_id on insert'
);
select throws_ok(
  $$ insert into public.auctions
       (title, image_path, start_price, min_increment, duration_minutes, starts_at)
     values ('Borrowed photo', '22222222-2222-2222-2222-222222222222/x.jpg', 10, 1, 30, now()) $$,
  '42501', null,
  'user cannot use a photo from someone else''s folder'
);

-- Constraints ---------------------------------------------------------------
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Free', 0, 1, 30, now()) $$,
  '23514', null,
  'start_price must be positive'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('No step', 10, 0, 30, now()) $$,
  '23514', null,
  'min_increment must be positive'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Too short', 10, 1, 4, now()) $$,
  '23514', null,
  'duration under 5 minutes is rejected'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Too long', 10, 1, 181, now()) $$,
  '23514', null,
  'duration over 180 minutes is rejected'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('  ab  ', 10, 1, 30, now()) $$,
  '23514', null,
  'title shorter than 3 characters (after trimming) is rejected'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Yesterday', 10, 1, 30, now() - interval '1 hour') $$,
  'P0001', 'INVALID_START_TIME',
  'start time in the past is rejected'
);
select throws_ok(
  $$ insert into public.auctions (title, start_price, min_increment, duration_minutes, starts_at)
     values ('Next year', 10, 1, 30, now() + interval '31 days') $$,
  'P0001', 'INVALID_START_TIME',
  'start time more than 30 days ahead is rejected'
);

-- Attacker: changing existing rows ------------------------------------------
select throws_ok(
  $$ update public.auctions set current_price = 1 where title = 'Vintage camera' $$,
  '42501', null,
  'seller cannot change current_price'
);
select throws_ok(
  $$ update public.auctions set status = 'ended' where title = 'Vintage camera' $$,
  '42501', null,
  'seller cannot change status directly'
);
select throws_ok(
  $$ delete from public.auctions where title = 'Vintage camera' $$,
  '42501', null,
  'seller cannot delete auctions'
);
select ok(
  not has_function_privilege('public.prepare_new_auction()', 'execute'),
  'user cannot call prepare_new_auction directly'
);
reset role;

-- start_auction -------------------------------------------------------------
select pg_temp.act_as_anon();
select throws_ok(
  $$ select public.start_auction((select id from public.auctions where title = 'Vintage camera')) $$,
  '42501', null,
  'anon cannot start auctions'
);
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ select public.start_auction((select id from public.auctions where title = 'Vintage camera')) $$,
  'P0001', 'NOT_AUCTION_SELLER',
  'user cannot start someone else''s auction'
);
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ select public.start_auction('99999999-9999-9999-9999-999999999999') $$,
  'P0001', 'AUCTION_NOT_FOUND',
  'starting a missing auction fails with AUCTION_NOT_FOUND'
);
select is(
  (select (a).status from (
     select public.start_auction((select id from public.auctions where title = 'Vintage camera')) as a
   ) started),
  'live',
  'seller can start their auction'
);
reset role;

-- now() is fixed for the whole transaction, so the exact end time can be compared.
select is(
  (select ends_at from public.auctions where title = 'Vintage camera'),
  now() + interval '30 minutes',
  'ends_at is start time plus duration_minutes'
);

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ select public.start_auction((select id from public.auctions where title = 'Vintage camera')) $$,
  'P0001', 'AUCTION_NOT_SCHEDULED',
  'a live auction cannot be started again'
);
reset role;

select * from finish();
rollback;
