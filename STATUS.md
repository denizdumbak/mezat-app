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
| M2 Create/list auctions | In progress: (a) schema done 2026-10-24; (b) app side next |
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
- **Tests**: 55 unit/widget tests (`test/`), 63 pgTAP tests (`supabase/tests/`), 10 tests of
  the real repositories against local Supabase (`test_supabase/`), 1 end-to-end UI test on
  the Windows desktop (`integration_test/`). Only `test/` runs in CI.

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
  CLAUDE.md). The developer runs all git commands; Claude supplies them.
- No Android emulator yet (licenses not accepted).

## Next steps

1. Delete the old copy `C:\Users\USER\projects\mezat-app` once no session uses it.
2. M2, plan agreed on 2026-10-24: (a) schema: done; (b) `Money` (integer kuruş),
   `AuctionRepository` (map the error codes above to Turkish), create form with
   `image_picker`, delete the uploaded photo if the insert fails; (c) home list
   (live / upcoming, seller username via the `seller_id` foreign key), detail screen with
   "start" for the seller, tests, README.

## Open items

- **GitHub Actions does not run:** the GitHub account is locked for a billing reason unrelated
  to this repo (public repos are free). Branch protection on `main` is removed (no PRs since
  2026-10-24); once CI runs again it reports on every push instead of gating merges.
- `test_supabase/`, `integration_test/` and SQL tests are not in CI (need Docker). Revisit at M3.
- Hosted Supabase project not created yet; copy auth settings from `config.toml` when it is.
