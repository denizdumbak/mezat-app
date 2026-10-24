# STATUS

Where the project stands, so the next session can continue without re-reading history.
Read at the start of a session; update at the end. Decisions and their reasons live in
NOTES.md; this file is only the current state.

_Last updated: 2026-10-25_

## Milestones

| Milestone | State |
| --- | --- |
| M0 Setup | Done |
| M1 Auth + profile | Done (manual run from VS Code on 2026-10-23: sign-up → username → home) |
| M2 Create/list auctions | Done 2026-10-24: end-to-end test (create → Yayın aç → go live → Keşfet) and the developer's hand check (room shows "Teklif verme henüz açık değil.", as intended until M3) |
| Design foundation | Done 2026-10-24: tokens, dark theme, fonts, shared widgets, 4-tab shell, live room on mock data |
| M3 Live bidding | In progress: steps 1–3 and 5–7 of 9 done (bids, place_bid, concurrency tests, spending limit on the server: sliding window the user picks, reset, switch-off; seller-set increment chips; real bidding from the app with the raise-the-limit flow); step 4 (maximum bids) dropped (NOTES.md) |
| M4–M6 | Not started |

## What exists

- **Database** (`supabase/migrations/`): pgTAP extension; `profiles` table with sign-up
  trigger, username normalization (trim + lowercase, `^[a-z0-9_]{3,20}$`, unique), RLS
  (everyone reads, owner updates) and column grants (only `username`, `avatar_url`).
  `auctions` table (opens `scheduled`, server sets status/price/winner/times; clients insert
  only form columns, no update/delete), `start_auction(id)` RPC (seller only, `scheduled` →
  `live`), optional `bid_increments` (up to 3 chips, each >= the minimum, ascending),
  public `auction-images` bucket (5 MB, jpeg/png/webp, uploads to own folder).
  Domain errors are raised as a code in the message (`INVALID_START_TIME`,
  `NOT_AUCTION_SELLER`, `AUCTION_NOT_SCHEDULED`, `AUCTION_NOT_FOUND`, `INVALID_INCREMENTS`).
  `bids` table (everyone reads, no client writes) and `place_bid(auction_id, amount)`:
  row lock, bidder from the JWT, anti-sniping (last 30 s → +30 s), codes `INVALID_AMOUNT`,
  `USERNAME_REQUIRED`, `AUCTION_NOT_LIVE`, `AUCTION_ENDED`, `SELLER_CANNOT_BID`,
  `ALREADY_WINNING`, `BID_TOO_LOW`, `SPENDING_LIMIT_EXCEEDED`, called by the live room.
  Spending limit in `spending_limits` (own row only; amount, period, on/off,
  reset; default on, ₺2.000 in 1 day), `committed_in_window()` and
  `reset_spending_window()`; the Profil screen edits all of it.
- **App** (`lib/`): email/password sign-up and sign-in, choose-username, sign-out.
  `AuthFailure` maps every Supabase error to a Turkish message. Navigation is one pure
  function, `redirectFor` in `lib/app/routes.dart`, driven by `sessionStatusProvider`.
  Create auction (`/auctions/new`, from the Sat tab): photo via `image_picker`, title,
  description, start price, min increment, up to three increment chips (optional, sorted by
  the app), duration, start now / later. `Money` (int kuruş,
  Turkish input, "₺1.250"), `AuctionRepository` (create, upload/delete photo), `AuctionFailure`.
  Locale fixed to Turkish (`flutter_localizations`).
- **Design** (`DESIGN.md`, `PRODUCT.md`, `lib/app/design_tokens.dart`, `lib/app/theme.dart`):
  two themes (light browse, dark live room; amber accent, red for live), Manrope bundled, shared widgets in
  `lib/core/widgets` (primary button, increment chip, rolling price, countdown with
  extension chip, bid feed row, sold stamp, loader, empty/error/connection states, app
  message). Tabs: Keşfet, Sat, Tekliflerim (still an empty state; not in the M3 plan), Profil
  (`lib/app/app_shell.dart`); live auctions are on Keşfet, with local search and category
  chips. Live room
  (`/auctions/:id/live`) with bid panel, high-bid confirmation, spending limit
  (Profil); a bid over the limit opens "Limit aşıldı" → "Limiti artır" → "Emin misin?",
  which raises the limit by the overage and bids. The leader cannot bid again. Bid safety rules in `lib/features/live_room/bid_safety.dart`.
- **Feed** (`AuctionFeedRepository`): `SupabaseAuctionFeedRepository` (default) serves the
  real lists (Keşfet: live + others' upcoming; Sat: your planned), `start_auction`, the room
  (last 20 bids with usernames, winner once the time is up), `place_bid` and the total from
  `committed_in_window()`. No realtime yet: lists reload by pulling down or after
  create/start; the room and the total reload after your own bid and at the end. `--dart-define=MOCK_FEED=true` switches to the demo mock with
  simulated bidders.
- **Tests**: 275 unit/widget tests (`test/`, screens also at 360×640), 188 pgTAP tests
  (`supabase/tests/`, incl. dblink tests of bids racing for the locks), 38 tests of the
  real repositories and concurrent bids against local Supabase
  (`test_supabase/`), 2 end-to-end UI tests on the Windows desktop (`integration_test/`, run
  one file at a time),
  19 screenshots for design review (`flutter test test_screenshots --update-goldens`, PNGs in
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

1. M3, approved plan (2026-10-24), steps left: 8 Realtime for the room and lists (feed the
   repository's change signal from Realtime instead of only the user's own bids);
   9 end-to-end test with two bidders, the developer's hand check, docs. Step 4 (maximum
   bids) was dropped by the developer: no automatic bidding.

## Open items

- **GitHub Actions does not run:** the GitHub account is locked for a billing reason unrelated
  to this repo (public repos are free). Branch protection on `main` is removed (no PRs since
  2026-10-24); once CI runs again it reports on every push instead of gating merges.
- `test_supabase/`, `integration_test/` and SQL tests are not in CI (need Docker) and will
  not be added; they run locally before commits (see NOTES.md).
- Hosted Supabase project not created yet; copy auth settings from `config.toml` when it is.
