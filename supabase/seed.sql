-- Demo data for local development: the same ten collectables as the app's
-- mock catalogue (lib/data/mock_auction_feed_repository.dart). Loaded by
-- `npx supabase db reset` (config.toml: [db.seed] sql_paths = ["./seed.sql"]);
-- never on the hosted project.
--
-- Times are relative to the moment of the reset, so right after it four
-- auctions are live, three are coming up, one is planned and two are sold.
-- Live ones stay 'live' after their time is up until M5's
-- finalize_ended_auctions() exists.
--
-- Photos: auction-images is a Storage bucket, which SQL cannot fill, so
-- image_path stays null here and the app shows its placeholder. The app's
-- demo mode (MOCK_FEED) uses the photos in assets/mock/.
--
-- The users have no password: they exist to own auctions and bids, not to
-- sign in. Sign up in the app to bid on them.

-- Sellers and bidders. Profiles come from the on_auth_user_created trigger.
insert into auth.users (id, email) values
  ('d0000000-0000-0000-0000-000000000001', 'analogdukkan@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000002', 'kartkoleksiyon@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000003', 'saatciusta@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000004', 'formakoleksiyon@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000005', 'kasetcafe@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000006', 'plakarsivi@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000007', 'antikacimehmet@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000008', 'eskiyazi@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000011', 'retro_avcisi@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000012', 'analogsever@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000013', 'foto_arsiv@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000014', 'albumcu_90lar@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000015', 'stickerhane@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000016', 'saatsever@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000017', 'kurmali_kol@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000018', 'sari_lacivert@seed.mezat.test'),
  ('d0000000-0000-0000-0000-000000000019', 'tribun_arsiv@seed.mezat.test');

update public.profiles p
set username = split_part(u.email, '@', 1)
from auth.users u
where u.id = p.id and u.email like '%@seed.mezat.test';

-- Auctions open as 'scheduled' (the insert trigger insists, and refuses a
-- start in the past); the live and sold ones are moved on right after.
insert into public.auctions
  (id, seller_id, title, description, start_price, min_increment, duration_minutes, starts_at)
values
  ('a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001',
   'Canon AE-1 Program, 50mm f/1.8 lens', 'Işık ölçeri çalışıyor, lens temiz.',
   3500.00, 25.00, 15, now()),
  ('a0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002',
   '1998 Panini Dünya Kupası albümü, tam set', 'Tüm çıkartmalar yerinde.',
   2500.00, 50.00, 20, now()),
  ('a0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000003',
   'Seiko 5 otomatik saat, 1970’ler, orijinal kordon', 'Bakımı yeni yapıldı.',
   2400.00, 10.00, 15, now()),
  ('a0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000004',
   'Fenerbahçe 1996 iç saha forması, imzalı', 'Sertifikalı imza.',
   15000.00, 250.00, 30, now()),
  ('a0000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000005',
   'Sony Walkman WM-F10, kasetli, çalışır', 'Radyo ve kaset bölümü çalışıyor.',
   900.00, 10.00, 15, now() + interval '2 hours'),
  ('a0000000-0000-0000-0000-000000000006', 'd0000000-0000-0000-0000-000000000006',
   '1970’ler Türk pop 45’lik plak seti, 12 adet', 'Kapaklar orijinal.',
   650.00, 10.00, 20, now() + interval '1 day'),
  ('a0000000-0000-0000-0000-000000000007', 'd0000000-0000-0000-0000-000000000007',
   'Antika kurmalı kol saati, 1950’ler, gümüş kasa', 'Kasa ayarlı gümüş.',
   5500.00, 100.00, 30, now() + interval '2 days 3 hours'),
  ('a0000000-0000-0000-0000-000000000008', 'd0000000-0000-0000-0000-000000000008',
   'Olivetti Lettera 32 daktilo, Türkçe klavye', 'Çantası ile birlikte.',
   2300.00, 10.00, 5, now() + interval '30 minutes'),
  ('a0000000-0000-0000-0000-000000000009', 'd0000000-0000-0000-0000-000000000002',
   '1990’lar futbolcu kartları, 200 adet', 'Lig ve milli takım kartları.',
   900.00, 50.00, 10, now()),
  ('a0000000-0000-0000-0000-000000000010', 'd0000000-0000-0000-0000-000000000001',
   'Helios 44-2 58mm lens, M42 bağlantı', 'Mantar ve çizik yok.',
   1400.00, 50.00, 60, now());

-- Live: started a few minutes ago, current price and leader from the bids.
update public.auctions a
set status = 'live',
    starts_at = now() - make_interval(mins => v.started_mins_ago),
    ends_at = now() + make_interval(secs => v.ends_in_secs),
    current_price = v.price,
    current_winner_id = v.winner
from (values
  ('a0000000-0000-0000-0000-000000000001'::uuid, 8, 240, 4250.00,
   'd0000000-0000-0000-0000-000000000011'::uuid),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 3, 720, 3100.00,
   'd0000000-0000-0000-0000-000000000014'::uuid),
  ('a0000000-0000-0000-0000-000000000003'::uuid, 11, 50, 2750.00,
   'd0000000-0000-0000-0000-000000000017'::uuid),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 20, 420, 18500.00,
   'd0000000-0000-0000-0000-000000000018'::uuid)
) as v(id, started_mins_ago, ends_in_secs, price, winner)
where a.id = v.id;

-- Sold.
update public.auctions a
set status = 'ended',
    starts_at = now() - v.started_ago,
    ends_at = now() - v.ended_ago,
    current_price = v.price,
    current_winner_id = v.winner
from (values
  ('a0000000-0000-0000-0000-000000000009'::uuid, interval '3 hours',
   interval '2 hours 50 minutes', 1150.00,
   'd0000000-0000-0000-0000-000000000014'::uuid),
  ('a0000000-0000-0000-0000-000000000010'::uuid, interval '1 day 1 hour',
   interval '1 day', 1600.00, 'd0000000-0000-0000-0000-000000000012'::uuid)
) as v(id, started_ago, ended_ago, price, winner)
where a.id = v.id;

-- The bids behind those prices, oldest first, 25 seconds apart.
insert into public.bids (auction_id, bidder_id, amount, created_at)
select v.auction_id, v.bidder_id, v.amount,
       a.ends_at - make_interval(secs => v.secs_before_end)
from (values
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'd0000000-0000-0000-0000-000000000011'::uuid, 3900.00, 340),
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'd0000000-0000-0000-0000-000000000012'::uuid, 4000.00, 315),
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'd0000000-0000-0000-0000-000000000013'::uuid, 4150.00, 290),
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'd0000000-0000-0000-0000-000000000011'::uuid, 4250.00, 265),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'd0000000-0000-0000-0000-000000000014'::uuid, 2900.00, 795),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'd0000000-0000-0000-0000-000000000015'::uuid, 3000.00, 770),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'd0000000-0000-0000-0000-000000000014'::uuid, 3100.00, 745),
  ('a0000000-0000-0000-0000-000000000003'::uuid, 'd0000000-0000-0000-0000-000000000016'::uuid, 2600.00, 100),
  ('a0000000-0000-0000-0000-000000000003'::uuid, 'd0000000-0000-0000-0000-000000000017'::uuid, 2750.00, 75),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 'd0000000-0000-0000-0000-000000000018'::uuid, 17000.00, 495),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 'd0000000-0000-0000-0000-000000000019'::uuid, 17750.00, 470),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 'd0000000-0000-0000-0000-000000000018'::uuid, 18500.00, 445),
  ('a0000000-0000-0000-0000-000000000009'::uuid, 'd0000000-0000-0000-0000-000000000015'::uuid, 1000.00, 60),
  ('a0000000-0000-0000-0000-000000000009'::uuid, 'd0000000-0000-0000-0000-000000000014'::uuid, 1150.00, 35),
  ('a0000000-0000-0000-0000-000000000010'::uuid, 'd0000000-0000-0000-0000-000000000013'::uuid, 1500.00, 60),
  ('a0000000-0000-0000-0000-000000000010'::uuid, 'd0000000-0000-0000-0000-000000000012'::uuid, 1600.00, 35)
) as v(auction_id, bidder_id, amount, secs_before_end)
join public.auctions a on a.id = v.auction_id;
