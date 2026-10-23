-- profiles: one row per auth user, created automatically on sign-up.
-- username starts out null; the app sends the user to "choose username" until it is set.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique,
  avatar_url text,
  created_at timestamptz not null default now(),
  -- Stored lowercase (see normalize trigger), so "Deniz" and "deniz" collide on the
  -- unique index instead of becoming two look-alike accounts.
  constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,20}$')
);

-- Normalize before the check constraint and unique index see the value.
create function public.normalize_profile_username()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.username := lower(btrim(new.username));
  return new;
end;
$$;

create trigger profiles_normalize_username
  before insert or update of username on public.profiles
  for each row execute function public.normalize_profile_username();

-- Create the profile row when Supabase Auth creates a user. security definer because
-- the auth service inserts into auth.users as a role that cannot write public.profiles.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Functions in public are callable over the API by default; these are trigger-only.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.normalize_profile_username() from public, anon, authenticated;

-- Row Level Security: decides which rows a request may touch.
alter table public.profiles enable row level security;

create policy "Profiles are readable by everyone"
  on public.profiles for select
  to anon, authenticated
  using (true);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Column privileges: decide which columns may change at all. Rows are only ever
-- inserted by handle_new_user and deleted via the auth.users cascade.
revoke insert, update, delete, truncate on public.profiles from anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;
