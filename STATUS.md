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
| M2 Create/list auctions | In progress: (a) schema, (b) create form done 2026-10-24; (c) Supabase lists next |
| Design foundation | Done 2026-10-24: tokens, dark theme, fonts, shared widgets, 4-tab shell, live room on mock data |
| M3–M6 | Not started |

## What exists

- **Database** (`supabase/migrations/`): pgTAP extension; `profiles` table with sign-up
  trigger, username normalization (trim + lowercase, `^[a-z0-9_]{3,20}$`, unique), RLS
  (everyone reads, owner updates) and column grants (only `username`, `avatar_url`).
  `auctions` table (opens `scheduled`, server sets status/price/winner/times; clients insert
  only form columns, no update/delete), `start_auction(id)` RPC (seller only, `scheduled` →
  `live`), public `auction-images` bucket (5 MB, jpeg/png/webp, uploads to own folder).
  Domain errors are raised as a code in the message (`INVALID_START_TIME`,
  `NOT_AUCTION_SELLER`, `AUCTION_NOT_SCHEDULED`, `AUCTION_NOT_FOUND`).
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
  (`/auctions/:id/live`) with bid panel, high-bid confirmation, maximum bid, daily limit
  (Profil). Lists and room run on `MockAuctionFeedRepository` behind
  `AuctionFeedRepository`; bid safety rules in `lib/features/live_room/bid_safety.dart`.
- **Tests**: 211 unit/widget tests (`test/`, screens also at 360×640), 63 pgTAP tests
  (`supabase/tests/`), 19 tests of the real repositories against local Supabase
  (`test_supabase/`), 1 end-to-end UI test on the Windows desktop (`integration_test/`),
  14 screenshots for design review (`flutter test test_screenshots --update-goldens`, PNGs in
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

1. Delete the old copy `C:\Users\USER\projects\mezat-app` once no session uses it.
2. Developer decides the anti-sniping numbers (brief: last minute / +15 s; CLAUDE.md: last
   30 s / +30 s; UI follows CLAUDE.md for now). See NOTES.md "Open work".
3. M2 (c): `SupabaseAuctionFeedRepository` for `watchDiscover`, `watchMyScheduled`,
   `startAuction` (seller username via the `seller_id` foreign key; amounts selected as
   `::text`; photo URL from `image_path`), so created auctions appear in Keşfet and Yayın
   aç; end-to-end test (sign up → create → see in list); README. The room stays on the mock
   until M3 (bids, realtime, server-side limit and proxy bids).

## Open items

- **GitHub Actions does not run:** the GitHub account is locked for a billing reason unrelated
  to this repo (public repos are free). Branch protection on `main` is removed (no PRs since
  2026-10-24); once CI runs again it reports on every push instead of gating merges.
- `test_supabase/`, `integration_test/` and SQL tests are not in CI (need Docker). Revisit at M3.
- Hosted Supabase project not created yet; copy auth settings from `config.toml` when it is.
