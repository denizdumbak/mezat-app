-- auction-images bucket: settings and storage.objects policies.
-- Size and type limits are enforced by the Storage API, not the database; they are
-- checked by the attacker script against the running API instead.
begin;
select plan(8);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');

create function pg_temp.act_as(user_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
$$;
create function pg_temp.act_as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
$$;

select results_eq(
  $$ select public, file_size_limit, allowed_mime_types
     from storage.buckets where id = 'auction-images' $$,
  $$ values (true, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp']) $$,
  'bucket is public, 5 MB, images only'
);

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('auction-images', '11111111-1111-1111-1111-111111111111/camera.jpg') $$,
  'user can upload to their own folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('auction-images', '22222222-2222-2222-2222-222222222222/fake.jpg') $$,
  '42501', null,
  'user cannot upload to someone else''s folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('auction-images', 'loose.jpg') $$,
  '42501', null,
  'user cannot upload outside a folder'
);
reset role;

select pg_temp.act_as_anon();
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('auction-images', '11111111-1111-1111-1111-111111111111/anon.jpg') $$,
  '42501', null,
  'anon cannot upload'
);
reset role;

-- Storage blocks plain SQL deletes unless this is set; the Storage API sets it for its own
-- queries. Setting it here makes the deletes below behave like API calls (RLS still applies).
select set_config('storage.allow_delete_query', 'true', true);

-- bob cannot see or delete alice's photo through the API (RLS hides the row).
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
delete from storage.objects
where bucket_id = 'auction-images' and name = '11111111-1111-1111-1111-111111111111/camera.jpg';
reset role;
select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'auction-images' and name = '11111111-1111-1111-1111-111111111111/camera.jpg'),
  1,
  'user cannot delete someone else''s photo'
);

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'auction-images'),
  1,
  'user sees only their own photos through the API'
);
delete from storage.objects
where bucket_id = 'auction-images' and name = '11111111-1111-1111-1111-111111111111/camera.jpg';
reset role;
select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'auction-images' and name = '11111111-1111-1111-1111-111111111111/camera.jpg'),
  0,
  'user can delete their own photo'
);

select * from finish();
rollback;
