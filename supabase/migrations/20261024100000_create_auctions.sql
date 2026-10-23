-- auctions: created by any user with a username, opened as 'scheduled'.
-- The seller starts it with start_auction(); bidding (M3) and finishing (M5) come later.

create table public.auctions (
  id uuid primary key default gen_random_uuid(),
  -- Filled from the caller's JWT; the column is not writable by clients.
  seller_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title text not null,
  description text not null default '',
  -- Object path inside the auction-images bucket ('<seller_id>/<file>'), not a full URL:
  -- the URL depends on the host (local, emulator, hosted), so the app builds it.
  image_path text,
  start_price numeric(12, 2) not null,
  min_increment numeric(12, 2) not null,
  -- How long the auction runs once the seller starts it.
  duration_minutes integer not null,
  status text not null default 'scheduled',
  -- Planned start while 'scheduled'; the actual start once start_auction() runs.
  starts_at timestamptz not null,
  -- Null until the auction is live.
  ends_at timestamptz,
  current_price numeric(12, 2) not null,
  current_winner_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint auctions_title_length check (char_length(title) between 3 and 80),
  constraint auctions_description_length check (char_length(description) <= 2000),
  constraint auctions_start_price_positive check (start_price > 0),
  constraint auctions_min_increment_positive check (min_increment > 0),
  constraint auctions_duration_range check (duration_minutes between 5 and 180),
  constraint auctions_status_valid check (status in ('scheduled', 'live', 'ended', 'cancelled')),
  constraint auctions_live_has_end check (status = 'scheduled' or ends_at is not null)
);

-- Home screen lists live and upcoming auctions ordered by time.
create index auctions_status_starts_at_idx on public.auctions (status, starts_at);
create index auctions_seller_id_idx on public.auctions (seller_id);

-- Server-owned fields are set here, whatever the insert sent. Column privileges already
-- keep clients away from them; this also covers inserts made with higher privileges.
create function public.prepare_new_auction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.description := btrim(coalesce(new.description, ''));
  new.status := 'scheduled';
  new.current_price := new.start_price;
  new.current_winner_id := null;
  new.ends_at := null;
  new.created_at := now();
  -- A few minutes of slack for "start now" sent from a phone whose clock is slightly off.
  -- Not a check constraint: those run again on every update, when now() has moved on.
  if new.starts_at < now() - interval '5 minutes'
     or new.starts_at > now() + interval '30 days' then
    raise exception 'INVALID_START_TIME';
  end if;
  return new;
end;
$$;

create trigger auctions_prepare_new
  before insert on public.auctions
  for each row execute function public.prepare_new_auction();

-- Row Level Security --------------------------------------------------------
alter table public.auctions enable row level security;

create policy "Auctions are readable by everyone"
  on public.auctions for select
  to anon, authenticated
  using (true);

create policy "Users with a username can create their own auctions"
  on public.auctions for insert
  to authenticated
  with check (
    seller_id = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.username is not null
    )
    -- The photo must be one the seller uploaded (their own folder in the bucket).
    and (image_path is null or (storage.foldername(image_path))[1] = (select auth.uid())::text)
  );

-- Column privileges: clients write only what the seller types in the form. Status,
-- price, winner and times change only through security definer functions.
-- No update/delete for clients in the MVP.
revoke insert, update, delete, truncate on public.auctions from anon, authenticated;
grant select on public.auctions to anon, authenticated;
grant insert (title, description, image_path, start_price, min_increment, duration_minutes, starts_at)
  on public.auctions to authenticated;

-- start_auction: the seller goes live. Errors are raised with a code as the message
-- (same convention place_bid will use), which the app maps to Turkish text.
create function public.start_auction(p_auction_id uuid)
returns public.auctions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auction public.auctions;
begin
  -- Lock the row so a double tap cannot start it twice.
  select * into v_auction from public.auctions where id = p_auction_id for update;

  if not found then
    raise exception 'AUCTION_NOT_FOUND';
  end if;
  if v_auction.seller_id is distinct from auth.uid() then
    raise exception 'NOT_AUCTION_SELLER';
  end if;
  if v_auction.status <> 'scheduled' then
    raise exception 'AUCTION_NOT_SCHEDULED';
  end if;

  update public.auctions
  set status = 'live',
      starts_at = now(),
      ends_at = now() + make_interval(mins => duration_minutes)
  where id = p_auction_id
  returning * into v_auction;

  return v_auction;
end;
$$;

-- Functions in public are callable over the API by default.
revoke execute on function public.prepare_new_auction() from public, anon, authenticated;
revoke execute on function public.start_auction(uuid) from public, anon, authenticated;
grant execute on function public.start_auction(uuid) to authenticated;
