-- bid_increments: the increment chips the seller picks on the create form ("+₺50").
-- Empty means the seller did not choose; the app then shows its defaults.
-- The chips only help the bidder pick an amount: place_bid still checks every bid
-- against current_price + min_increment, so they cannot make a bid valid or invalid.

alter table public.auctions
  add column bid_increments numeric(12, 2)[] not null default '{}';

-- Written once, at insert (the column is not updatable by clients), so the check is a
-- trigger like the start-time one and raises its own code for the app.
create function public.check_bid_increments()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_previous numeric(12, 2);
  v_increment numeric(12, 2);
begin
  if cardinality(new.bid_increments) > 3 then
    raise exception 'INVALID_INCREMENTS';
  end if;
  -- Each chip at least the minimum, smallest first, no repeats: the room shows them in
  -- this order and selects the first one.
  foreach v_increment in array new.bid_increments loop
    if v_increment is null
       or v_increment < new.min_increment
       or v_increment <= v_previous then
      raise exception 'INVALID_INCREMENTS';
    end if;
    v_previous := v_increment;
  end loop;
  return new;
end;
$$;

create trigger auctions_check_bid_increments
  before insert on public.auctions
  for each row execute function public.check_bid_increments();

revoke execute on function public.check_bid_increments() from public, anon, authenticated;

grant insert (bid_increments) on public.auctions to authenticated;
