-- profiles: schema, sign-up trigger, RLS and column privileges.
-- Attacker cases: anon writes, editing someone else's row, changing id/created_at,
-- direct insert/delete, duplicate or malformed usernames, calling trigger functions.
begin;
select plan(19);

-- Two users, created the way Supabase Auth does it (insert into auth.users).
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');

-- Helpers to act as a given API role, the way PostgREST does per request.
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
select has_table('public', 'profiles', 'profiles table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS is enabled on profiles'
);

-- Sign-up trigger -----------------------------------------------------------
select is(
  (select count(*)::int from public.profiles
   where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')),
  2,
  'a profile row is created for every new auth user'
);
select is(
  (select username from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  null,
  'username starts out empty'
);

-- Anonymous visitor ---------------------------------------------------------
select pg_temp.act_as_anon();
select is((select count(*)::int from public.profiles), 2, 'anon can read profiles');
select throws_ok(
  $$ update public.profiles set username = 'hacked' $$,
  '42501', null,
  'anon cannot update profiles'
);
reset role;

-- Owner ---------------------------------------------------------------------
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
  $$ update public.profiles set username = '  Alice_01 '
     where id = '11111111-1111-1111-1111-111111111111' $$,
  'user can set their own username'
);
select is(
  (select username from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'alice_01',
  'username is trimmed and lowercased'
);

-- Someone else's row: RLS hides it from the update, so nothing changes.
update public.profiles set username = 'stolen'
where id = '22222222-2222-2222-2222-222222222222';
reset role;
select is(
  (select username from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  null,
  'user cannot update another user''s profile'
);

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
  $$ update public.profiles set id = '33333333-3333-3333-3333-333333333333'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'user cannot change their profile id'
);
select throws_ok(
  $$ update public.profiles set created_at = now() - interval '1 year'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'user cannot change created_at'
);
select throws_ok(
  $$ insert into public.profiles (id, username)
     values ('33333333-3333-3333-3333-333333333333', 'ghost') $$,
  '42501', null,
  'user cannot insert profiles directly'
);
select throws_ok(
  $$ delete from public.profiles where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'user cannot delete profiles'
);
select ok(
  not has_function_privilege('public.handle_new_user()', 'execute'),
  'user cannot call handle_new_user directly'
);
reset role;

-- Username rules (as bob) -----------------------------------------------------
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$ update public.profiles set username = 'ALICE_01'
     where id = '22222222-2222-2222-2222-222222222222' $$,
  '23505', null,
  'username is unique regardless of case'
);
select throws_ok(
  $$ update public.profiles set username = 'ab'
     where id = '22222222-2222-2222-2222-222222222222' $$,
  '23514', null,
  'username shorter than 3 characters is rejected'
);
select throws_ok(
  $$ update public.profiles set username = 'has space'
     where id = '22222222-2222-2222-2222-222222222222' $$,
  '23514', null,
  'username with invalid characters is rejected'
);
select throws_ok(
  $$ update public.profiles set username = repeat('a', 21)
     where id = '22222222-2222-2222-2222-222222222222' $$,
  '23514', null,
  'username longer than 20 characters is rejected'
);
reset role;

-- Cascade -------------------------------------------------------------------
delete from auth.users where id = '22222222-2222-2222-2222-222222222222';
select is(
  (select count(*)::int from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  0,
  'deleting the auth user deletes the profile'
);

select * from finish();
rollback;
