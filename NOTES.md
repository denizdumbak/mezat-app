# NOTES

Decisions and technical debt. Newest on top within each section.

## Open work

- **M0 step 6, local Supabase (blocked on Docker):** install Docker Desktop (WSL2) and the
  Supabase CLI, then: `supabase init` (creates `supabase/config.toml`), `supabase start`,
  put the printed API URL and anon/publishable key into `.env`, add the first migration
  enabling pgTAP, and a smoke test under `supabase/tests/` run with `supabase test db`.
  Also fill in the Supabase commands in README and CLAUDE.md.
- Android licenses are not accepted on the dev machine (`flutter doctor --android-licenses`,
  interactive). Not needed for tests; needed before the first Android build.

## Technical debt

- SQL tests (`supabase test db`) are not run in CI. That would need Docker + `supabase start`
  in the workflow (slow). Revisit at M3 when `place_bid` tests exist; they are the most
  important tests in the repo and should gate merges.
- Dependencies are pinned to versions resolved on 2026-10-23. `go_router` 18 and
  `flutter_riverpod` 3.4 are already out; upgrade deliberately, one at a time.

## Decisions

- **Config via `--dart-define-from-file=.env` (no dotenv package).** Flutter reads the
  `KEY=value` file at build time and compiles the values in as constants. No extra
  dependency, and `.env` is not bundled as an asset. Verified that comments in `.env` are fine.
  `Env.parse` validates at startup; a bad config shows `ConfigErrorApp` instead of crashing.
- **`SUPABASE_ANON_KEY` is passed as `publishableKey`.** supabase_flutter 2.18 deprecated
  `anonKey` in favour of `publishableKey`; the package source shows it is a pure rename.
  The env var keeps the name used in CLAUDE.md.
- **`supabaseClientProvider` is the only way to reach Supabase.** Repositories depend on it;
  tests override it. Widgets never import `supabase_flutter` directly.
- **`livekit_client` not added yet.** It is first needed in M4; adding it now would only add
  native build weight and upgrade churn.
- **Platforms: android + ios folders.** iOS publishing is out of MVP scope, but the folder costs
  nothing and keeps the option open.
- **Flutter 3.41.4 (stable) pinned in CI** to match the dev machine.
