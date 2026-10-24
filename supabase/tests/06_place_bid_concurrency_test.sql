-- place_bid under concurrency, deterministically: two real sessions (dblink) bid on
-- the same auction while the first one still holds the row lock.
--   1. A bids 120 and does not commit; B sends 125, which beats the old price (100) but
--      not A's. B must wait for the lock, then be refused: no lost update.
--   2. Near the end, A's bid extends the auction; B, waiting behind it, must see the new
--      end and not extend a second time. (Checked with the lock removed: case 1 fails,
--      case 2 still passes, because the UPDATE reads the latest end either way.)
--   3. One bidder, two auctions at once: each bid fits the daily limit, both together do
--      not. The second must wait for the first (bidder's profile row lock) and then be
--      refused, instead of each checking the old total.
-- Other sessions only see committed rows, so the data is set up and removed through a
-- third session. The extension is created inside this test's transaction and rolled
-- back with it; nothing about dblink reaches the real schema.
begin;
select plan(15);
-- A broken lock should fail the test, not hang it.
set local statement_timeout = '60s';

create extension if not exists dblink schema extensions;

-- dblink needs a password login: the container's own address uses one (127.0.0.1 is
-- trusted, which dblink refuses for non-superusers). Local default credentials only.
-- options sets a statement timeout in the new session too.
create function pg_temp.connect(name text) returns text language sql as $$
  select extensions.dblink_connect(name, format(
    'host=%s port=5432 dbname=postgres user=postgres password=postgres '
    'options=''-c statement_timeout=15s''',
    host(inet_server_addr())));
$$;

-- Session-wide JWT claims, so every later statement in that session is that user.
create function pg_temp.sign_in(name text, user_id uuid) returns text language sql as $$
  select v from extensions.dblink(name, format(
    $q$ select set_config('request.jwt.claims', '{"sub":"%s","role":"authenticated"}', false) $q$,
    user_id)) as t(v text);
$$;

-- True once the backend is blocked on a lock (pg_locks is live, not a snapshot). Takes
-- the pid, not the session name: a session busy with a query cannot be asked for it.
create function pg_temp.waits_for_lock(v_pid int) returns boolean language plpgsql as $$
begin
  for i in 1..100 loop
    if exists (select 1 from pg_locks where pid = v_pid and not granted) then
      return true;
    end if;
    perform pg_sleep(0.05);
  end loop;
  return false;
end;
$$;

-- Reads committed state through the setup session.
create function pg_temp.committed(query text) returns text language sql as $$
  select v from extensions.dblink('setup', query) as t(v text);
$$;

select lives_ok(
  $$ select pg_temp.connect('setup'), pg_temp.connect('a'), pg_temp.connect('b') $$,
  'three sessions connect'
);
create temp table b_session as
  select pid from extensions.dblink('b', 'select pg_backend_pid()') as t(pid int);

-- Seller s, bidders a and b. "Race" has 30 minutes left, "Closing" 20 seconds,
-- "Wallet 1" and "Wallet 2" 30 minutes.
-- Starts by removing what an interrupted earlier run may have left behind.
select extensions.dblink_exec('setup', $$
  delete from auth.users where email like '%@concurrency.test';
  insert into auth.users (id, email) values
    ('c0000000-0000-0000-0000-000000000001', 's@concurrency.test'),
    ('c0000000-0000-0000-0000-000000000002', 'a@concurrency.test'),
    ('c0000000-0000-0000-0000-000000000003', 'b@concurrency.test');
  update public.profiles set username = 'conc_s' where id = 'c0000000-0000-0000-0000-000000000001';
  update public.profiles set username = 'conc_a' where id = 'c0000000-0000-0000-0000-000000000002';
  update public.profiles set username = 'conc_b' where id = 'c0000000-0000-0000-0000-000000000003';
  insert into public.auctions
    (id, seller_id, title, start_price, min_increment, duration_minutes, starts_at)
  values
    ('c0000000-aaaa-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
     'Race', 100.00, 10.00, 30, now()),
    ('c0000000-aaaa-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001',
     'Closing', 100.00, 10.00, 30, now()),
    ('c0000000-aaaa-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001',
     'Wallet 1', 100.00, 10.00, 30, now()),
    ('c0000000-aaaa-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001',
     'Wallet 2', 100.00, 10.00, 30, now());
  update public.auctions set status = 'live', ends_at = now() + interval '30 minutes'
  where id in ('c0000000-aaaa-0000-0000-000000000001', 'c0000000-aaaa-0000-0000-000000000003',
               'c0000000-aaaa-0000-0000-000000000004');
  update public.auctions set status = 'live', ends_at = now() + interval '20 seconds'
  where id = 'c0000000-aaaa-0000-0000-000000000002';
$$);
select pg_temp.sign_in('a', 'c0000000-0000-0000-0000-000000000002');
select pg_temp.sign_in('b', 'c0000000-0000-0000-0000-000000000003');

-- 1. No lost update ---------------------------------------------------------
select extensions.dblink_exec('a', 'begin');
select * from extensions.dblink('a',
  $$ select public.place_bid('c0000000-aaaa-0000-0000-000000000001', 120.00)::text $$)
  as t(r text);
select extensions.dblink_send_query('b',
  $$ select public.place_bid('c0000000-aaaa-0000-0000-000000000001', 125.00)::text $$);

select ok(pg_temp.waits_for_lock((select pid from b_session)), 'B waits while A holds the auction row');

select extensions.dblink_exec('a', 'commit');
select is(
  (select count(*) from extensions.dblink_get_result('b', false) as t(r text)),
  0::bigint, 'B gets no result row'
);
select matches(
  extensions.dblink_error_message('b'), 'BID_TOO_LOW',
  'B is judged against A''s price (120), not the price it saw (100)'
);
select count(*) from extensions.dblink_get_result('b', false) as t(r text); -- drain

select is(pg_temp.committed($$ select current_price::text from public.auctions
  where id = 'c0000000-aaaa-0000-0000-000000000001' $$), '120.00', 'the price is A''s bid');
select is(pg_temp.committed($$ select current_winner_id::text from public.auctions
  where id = 'c0000000-aaaa-0000-0000-000000000001' $$),
  'c0000000-0000-0000-0000-000000000002', 'A leads');
select is(pg_temp.committed($$ select count(*)::text from public.bids
  where auction_id = 'c0000000-aaaa-0000-0000-000000000001' $$), '1', 'only A''s bid is recorded');

-- 2. Anti-sniping extends once ----------------------------------------------
create temp table closing_end as
  select pg_temp.committed($$ select ends_at::text from public.auctions
    where id = 'c0000000-aaaa-0000-0000-000000000002' $$)::timestamptz as ends_at;

select extensions.dblink_exec('a', 'begin');
select * from extensions.dblink('a',
  $$ select public.place_bid('c0000000-aaaa-0000-0000-000000000002', 110.00)::text $$)
  as t(r text);
select extensions.dblink_send_query('b',
  $$ select (public.place_bid('c0000000-aaaa-0000-0000-000000000002', 120.00)).current_price::text $$);

select ok(pg_temp.waits_for_lock((select pid from b_session)), 'B waits behind A near the end');

select extensions.dblink_exec('a', 'commit');
select is(
  (select r from extensions.dblink_get_result('b') as t(r text)),
  '120.00', 'B''s higher bid is accepted after A''s'
);
select count(*) from extensions.dblink_get_result('b', false) as t(r text); -- drain

select is(
  pg_temp.committed($$ select ends_at::text from public.auctions
    where id = 'c0000000-aaaa-0000-0000-000000000002' $$)::timestamptz,
  (select ends_at + interval '30 seconds' from closing_end),
  'the end moved 30 seconds once: B saw the extended end, not the old one'
);
select is(pg_temp.committed($$ select count(*)::text from public.bids
  where auction_id = 'c0000000-aaaa-0000-0000-000000000002' $$), '2', 'both bids are recorded');

-- 3. One bidder's total, two auctions at once -------------------------------
-- a leads "Race" at 120 and has the default limit of 2000: 120 + 1000 fits, a second
-- 1000 does not. Session b now acts as a too.
select pg_temp.sign_in('b', 'c0000000-0000-0000-0000-000000000002');
select extensions.dblink_exec('a', 'begin');
select * from extensions.dblink('a',
  $$ select public.place_bid('c0000000-aaaa-0000-0000-000000000003', 1000.00)::text $$)
  as t(r text);
select extensions.dblink_send_query('b',
  $$ select public.place_bid('c0000000-aaaa-0000-0000-000000000004', 1000.00)::text $$);

select ok(pg_temp.waits_for_lock((select pid from b_session)),
  'the same bidder''s second bid waits, although it is on another auction');

select extensions.dblink_exec('a', 'commit');
select is(
  (select count(*) from extensions.dblink_get_result('b', false) as t(r text)),
  0::bigint, 'the second bid gets no result row'
);
select matches(
  extensions.dblink_error_message('b'), 'DAILY_LIMIT_EXCEEDED',
  'the second bid is judged against the total including the first'
);
select count(*) from extensions.dblink_get_result('b', false) as t(r text); -- drain
select is(pg_temp.committed($$ select count(*)::text from public.bids
  where auction_id = 'c0000000-aaaa-0000-0000-000000000004' $$), '0',
  'nothing is recorded on the second auction');

-- Clean-up: the users take their profiles, auctions and bids with them.
select extensions.dblink_exec('setup', $$ delete from auth.users where email like '%@concurrency.test' $$);
select extensions.dblink_disconnect('setup');
select extensions.dblink_disconnect('a');
select extensions.dblink_disconnect('b');

select * from finish();
rollback;
