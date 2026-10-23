# NOTES

Decisions and technical debt. Newest on top within each section.

## Open work

- Android licenses are not accepted on the dev machine (`flutter doctor --android-licenses`,
  interactive). Not needed for tests; needed before the first Android build.

## Technical debt

- SQL tests (`supabase test db`) are not run in CI. That would need Docker + `supabase start`
  in the workflow (slow). Revisit at M3 when `place_bid` tests exist; they are the most
  important tests in the repo and should gate merges.
- Dependencies are pinned to versions resolved on 2026-10-23. `go_router` 18 and
  `flutter_riverpod` 3.4 are already out; upgrade deliberately, one at a time.

## Decisions

- **Local Supabase ports moved from 543xx to 553xx.** On the dev machine Windows reserves
  54145–54819 (`netsh interface ipv4 show excludedportrange protocol=tcp`), so
  `supabase start` failed to bind 54322. Moving the ports in `config.toml` is permanent and
  needs no admin rights; restarting `winnat` would only help until the next reboot.
- **Supabase CLI as a pinned npm devDependency (`supabase` 2.122.0).** The CLI version is
  recorded in the repo, so CI and every machine run the same one; no global install.
  Cost: a root `package.json`. Use it via `npx supabase`.
- **Email confirmation off locally** (`enable_confirmations = false`, Supabase's local
  default): sign-up logs the user in immediately. The "email not confirmed" error still gets
  its own message and test, so turning confirmation on later needs no app change.
- **pgTAP in the `extensions` schema**, enabled by the first migration.

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
