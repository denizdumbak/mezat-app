# STATUS

Where the project stands, so the next session can continue without re-reading history.
Read at the start of a session; update at the end. Decisions and their reasons live in
NOTES.md; this file is only the current state.

_Last updated: 2026-10-24_

## Milestones

| Milestone | State |
| --- | --- |
| M0 Setup | Done |
| M1 Auth + profile | Done (manual run from VS Code on 2026-10-23: sign-up → username → home) |
| M2 Create/list auctions | Done 2026-10-24: end-to-end test (create → Yayın aç → go live → Keşfet) and the developer's hand check (room shows "Teklif verme henüz açık değil.", as intended until M3) |
| Design foundation | Done 2026-10-24: tokens, dark theme, fonts, shared widgets, 4-tab shell, live room on mock data |
| M3 Live bidding | In progress: steps 1–3 of 9 done (bids, place_bid, concurrency tests); maximum bids built and removed (NOTES.md) |
| M4–M6 | Not started |

## What exists

- **Database** (`supabase/migrations/`): pgTAP extension; `profiles` table with sign-up
  trigger, username normalization (trim + lowercase, `^[a-z0-9_]{3,20}$`, unique), RLS
  (everyone reads, owner updates) and column grants (only `username`, `avatar_url`).
  `auctions` table (opens `scheduled`, server sets status/price/winner/times; clients insert
  only form columns, no update/delete), `start_auction(id)` RPC (seller only, `scheduled` →
  `live`), public `auction-images` bucket (5 MB, jpeg/png/webp, uploads to own folder).
  Domain errors are raised as a code in the message (`INVALID_START_TIME`,
  `NOT_AUCTION_SELLER`, `AUCTION_NOT_SCHEDULED`, `AUCTION_NOT_FOUND`).
  `bids` table (everyone reads, no client writes) and `place_bid(auction_id, amount)`:
  row lock, bidder from the JWT, anti-sniping (last 30 s → +30 s), codes `INVALID_AMOUNT`,
  `USERNAME_REQUIRED`, `AUCTION_NOT_LIVE`, `AUCTION_ENDED`, `SELLER_CANNOT_BID`,
  `ALREADY_WINNING`, `BID_TOO_LOW`. Not called by the app yet (step 7).
- **App** (`lib/`): email/password sign-up and sign-in, choose-username, sign-out.
  `AuthFailure` maps every Supabase error to a Turkish message. Navigation is one pure
  function, `redirectFor` in `lib/app/routes.dart`, driven by `sessionStatusProvider`.
  Create auction (`/auctions/new`, from the Yayın aç tab): photo via `image_picker`, title,
  description, start price, min increment, duration, start now / later. `Money` (int kuruş,
  Turkish input, "₺1.250"), `AuctionRepository` (create, upload/delete photo), `AuctionFailure`.
  Locale fixed to Turkish (`flutter_localizations`).
- **Design** (`DESIGN.md`, `PRODUCT.md`, `lib/app/design_tokens.dart`, `lib/app/theme.dart`):
  dark "Lacivert + altın" theme, Fraunces + Manrope bundled, shared widgets in
  `lib/core/widgets` (primary button, increment chip, rolling price, countdown with
  extension chip, bid feed row, sold stamp, loader, empty/error/connection states, app
  message). Tabs: Keşfet, Canlı, Yayın aç, Profil (`lib/app/app_shell.dart`). Live room
  (`/auctions/:id/live`) with bid panel, high-bid confirmation, daily limit
  (Profil). Bid safety rules in `lib/features/live_room/bid_safety.dart`.
- **Feed** (`AuctionFeedRepository`): `SupabaseAuctionFeedRepository` (default) serves the
  real lists (Keşfet: live + others' upcoming; Yayın aç: your planned), `start_auction`, and a
  read-only room ("Teklif verme henüz açık değil."). No realtime: pull down to refresh; lists
  reload after create/start. `--dart-define=MOCK_FEED=true` switches to the demo mock with
  simulated bidders.
- **Tests**: 212 unit/widget tests (`test/`, screens also at 360×640), 128 pgTAP tests
  (`supabase/tests/`, incl. a dblink test of two bids racing for the lock), 29 tests of the
  real repositories and concurrent bids against local Supabase
  (`test_supabase/`), 2 end-to-end UI tests on the Windows desktop (`integration_test/`, run
  one file at a time),
  13 screenshots for design review (`flutter test test_screenshots --update-goldens`, PNGs in
  `test_screenshots/goldens/`, git-ignored). Only `test/` runs in CI.

## Environment

- Project path: `D:\Flutter\mezat-app` (moved from C: on 2026-10-23).
- Local Supabase: Docker Desktop must be running, then `npx supabase start`.
  Ports are 553xx (API `55321`, DB `55322`, Studio `55323`), not the default 543xx.
- Run on Windows desktop (targets are still android + ios; `windows/` is local only):
  VS Code Run/F5 passes `.env` via `.vscode/settings.json`, or
  `flutter run -d windows --dart-define-from-file=.env`.
- Docker Desktop's disk image is on `D:\Docker` (moved 2026-10-23; data kept). The first
  `supabase start` after the move hit a health-check timeout; a second start worked.
- Git: commits go straight to `main` after local `flutter analyze` + `flutter test` (see
  CLAUDE.md). Claude commits and pushes after each step; messages are one short sentence
  with no prefix.
- No Android emulator yet (licenses not accepted).

## Next steps

1. M3, approved plan (2026-10-24), steps left: 5 daily limit in `profiles`, enforced in
   `place_bid` (`DAILY_LIMIT_EXCEEDED`, `committed_today()`); 6 seller-set increments
   (`bid_increments`, form field); 7 `SupabaseAuctionFeedRepository.placeBid` + bid feed,
   error codes mapped to Turkish in `AuctionFailure`; 8 Realtime for the room and lists;
   9 end-to-end test with two bidders, the developer's hand check, docs. Step 4 (maximum
   bids) was dropped by the developer: no automatic bidding.

## Open items

- **GitHub Actions does not run:** the GitHub account is locked for a billing reason unrelated
  to this repo (public repos are free). Branch protection on `main` is removed (no PRs since
  2026-10-24); once CI runs again it reports on every push instead of gating merges.
- `test_supabase/`, `integration_test/` and SQL tests are not in CI (need Docker) and will
  not be added; they run locally before commits (see NOTES.md).
- Hosted Supabase project not created yet; copy auth settings from `config.toml` when it is.
