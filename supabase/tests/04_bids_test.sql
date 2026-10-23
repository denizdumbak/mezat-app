-- bids: schema, constraints and RLS.
-- Attacker cases: anon and signed-in users writing bids directly (even a valid-looking
-- one for themselves), changing or deleting existing bids.
begin;
select plan(17);

-- alice sells, bob bids.
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';

insert into public.auctions
  (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111',
        'Vintage camera', 100.00, 10.00, 30, now());
update public.auctions
set status = 'live', ends_at = now() + interval '30 minutes'
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- An accepted bid, written the way place_bid() will: with the owner's privileges.
insert into public.bids (id, auction_id, bidder_id, amount)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '22222222-2222-2222-2222-222222222222', 110.00);

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
select has_table('public', 'bids', 'bids table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.bids'::regclass),
  'RLS is enabled on bids'
);
select col_type_is('public', 'bids', 'amount', 'numeric(12,2)',
  'money is numeric(12,2), not float');
select col_default_is('public', 'bids', 'is_auto', 'false', 'bids are manual by default');
select throws_ok(
  $$ insert into public.bids (auction_id, bidder_id, amount)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 0) $$,
  '23514', null,
  'amount must be positive'
);

-- Reading -------------------------------------------------------------------
select pg_temp.act_as_anon();
select is((select count(*) from public.bids), 1::bigint, 'anon can read bids');
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select is((select count(*) from public.bids), 1::bigint, 'a signed-in user can read bids');
reset role;

-- Attacker: writing bids directly -------------------------------------------
select pg_temp.act_as_anon();
select throws_ok(
  $$ insert into public.bids (auction_id, bidder_id, amount)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 500) $$,
  '42501', null,
  'anon cannot insert a bid'
);
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ insert into public.bids (auction_id, bidder_id, amount)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 120) $$,
  '42501', null,
  'a bidder cannot insert even a valid-looking bid of their own'
);
select throws_ok(
  $$ insert into public.bids (auction_id, bidder_id, amount)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 120) $$,
  '42501', null,
  'a user cannot insert a bid in someone else''s name'
);
select throws_ok(
  $$ update public.bids set amount = 5000 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  '42501', null,
  'a bidder cannot change their bid'
);
select throws_ok(
  $$ delete from public.bids where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  '42501', null,
  'a bidder cannot delete their bid'
);
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ delete from public.bids where auction_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '42501', null,
  'the seller cannot delete bids on their auction'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ update public.bids set amount = 1 $$,
  '42501', null,
  'anon cannot change bids'
);
select throws_ok(
  $$ delete from public.bids $$,
  '42501', null,
  'anon cannot delete bids'
);
reset role;

select is(
  (select amount from public.bids where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  110.00::numeric,
  'the bid is unchanged after the attempts'
);

-- Clean-up of a deleted auction ---------------------------------------------
delete from public.auctions where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
select is((select count(*) from public.bids), 0::bigint, 'bids go with their auction');

select * from finish();
rollback;
