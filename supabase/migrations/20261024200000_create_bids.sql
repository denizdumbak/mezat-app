-- bids: every accepted bid, newest last. Written only by place_bid() (next migration),
-- a security definer function; clients may read but never write.

create table public.bids (
  id uuid primary key default gen_random_uuid(),
  auction_id uuid not null references public.auctions (id) on delete cascade,
  bidder_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(12, 2) not null,
  -- True when the system bid for the user from their maximum bid, not a tap.
  is_auto boolean not null default false,
  created_at timestamptz not null default now(),
  constraint bids_amount_positive check (amount > 0)
);

-- The room shows the latest bids of one auction; "today's total" reads one bidder's.
create index bids_auction_id_created_at_idx on public.bids (auction_id, created_at desc);
create index bids_bidder_id_created_at_idx on public.bids (bidder_id, created_at desc);

-- Row Level Security --------------------------------------------------------
alter table public.bids enable row level security;

create policy "Bids are readable by everyone"
  on public.bids for select
  to anon, authenticated
  using (true);

-- No insert/update/delete policy and no privileges: a client cannot write a bid, even
-- one that would pass every rule. Only place_bid() (security definer) writes here.
revoke insert, update, delete, truncate on public.bids from anon, authenticated;
grant select on public.bids to anon, authenticated;
