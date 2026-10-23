# STATUS

Where the project stands, so the next session can continue without re-reading history.
Read at the start of a session; update at the end. Decisions and their reasons live in
NOTES.md; this file is only the current state.

_Last updated: 2026-10-23_

## Milestones

| Milestone | State |
| --- | --- |
| M0 Setup | Done |
| M1 Auth + profile | Code and tests done; waiting for a manual run from VS Code (see below) |
| M2 Create/list auctions | Not started |
| M3–M6 | Not started |

## What exists

- **Database** (`supabase/migrations/`): pgTAP extension; `profiles` table with sign-up
  trigger, username normalization (trim + lowercase, `^[a-z0-9_]{3,20}$`, unique), RLS
  (everyone reads, owner updates) and column grants (only `username`, `avatar_url`).
- **App** (`lib/`): email/password sign-up and sign-in, choose-username, sign-out.
  `AuthFailure` maps every Supabase error to a Turkish message. Navigation is one pure
  function, `redirectFor` in `lib/app/routes.dart`, driven by `sessionStatusProvider`.
- **Tests**: 55 unit/widget tests (`test/`), 19 pgTAP tests (`supabase/tests/`), 10 tests of
  the real repositories against local Supabase (`test_supabase/`), 1 end-to-end UI test on
  the Windows desktop (`integration_test/`). Only `test/` runs in CI.

## Environment

- Project path: `D:\Flutter\mezat-app` (moved from C: on 2026-10-23).
- Local Supabase: Docker Desktop must be running, then `npx supabase start`.
  Ports are 553xx (API `55321`, DB `55322`, Studio `55323`), not the default 543xx.
- Run on Windows desktop (targets are still android + ios; `windows/` is local only):
  VS Code Run/F5 passes `.env` via `.vscode/settings.json`, or
  `flutter run -d windows --dart-define-from-file=.env`.
- No Android emulator yet (licenses not accepted, C: nearly full).

## Next steps

1. Run the app from VS Code with `D:\Flutter\mezat-app` open; if sign-in appears, tick M1
   in CLAUDE.md.
2. Move Docker Desktop's disk image to D: (C: has ~9 GB free; Docker uses ~11 GB).
3. Start M2: plan first (CLAUDE.md working rules), then auctions table + RLS + Storage.

## Open items

- `test_supabase/`, `integration_test/` and SQL tests are not in CI (need Docker). Revisit at M3.
- Hosted Supabase project not created yet; copy auth settings from `config.toml` when it is.
