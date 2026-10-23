# NOTES

Decisions and technical debt. Newest on top within each section.

## Open work

- Android licenses are not accepted on the dev machine (`flutter doctor --android-licenses`,
  interactive). Not needed for tests; needed before the first Android build.

## Technical debt

- `test_supabase/` (real repositories vs. local Supabase) is not run in CI, same reason as
  the SQL tests. Revisit together at M3.
- The hosted Supabase project must get the same auth settings as `config.toml`
  (minimum password length 8). Dashboard settings are not migrations; check on first deploy.
- SQL tests (`supabase test db`) are not run in CI. That would need Docker + `supabase start`
  in the workflow (slow). Revisit at M3 when `place_bid` tests exist; they are the most
  important tests in the repo and should gate merges.
- Dependencies are pinned to versions resolved on 2026-10-23. `go_router` 18 and
  `flutter_riverpod` 3.4 are already out; upgrade deliberately, one at a time.

## Decisions

- **GitHub Flow instead of Git Flow (2026-10-23).** One developer, no release trains: a
  long-lived `develop` branch would only add a second place to merge into. `main` is protected
  (PR + green CI required) and every change goes through a short-lived branch and a PR, which
  is what a reviewer of the repo expects to see. Squash merge keeps `main` one commit per PR.
  Revisit (add `develop`/release branches) only if there are store releases to stabilise.
- **CLAUDE.md, STATUS.md and `.claude/agents/` are committed.** They hold no secrets and
  document how the project is built; personal, machine-specific notes would go in
  `CLAUDE.local.md` (git-ignored by Claude Code convention) instead.

- **"Configuration error" on the first desktop run (2026-10-23) was the VS Code run button**,
  which does not pass `--dart-define-from-file=.env`: all three values were missing, `.env`
  itself was fine. Fix: `.vscode/settings.json` sets `dart.flutterRunAdditionalArgs` (checked
  in the installed Dart extension 3.144.0; scope is the workspace). Not put in
  `launch.json` `args`: those go to the app's `main`, not to `flutter run` (`toolArgs` would),
  and having it in both places would pass it twice. `main.dart` also prints the problem.
- **Desktop (Windows) is for local trying only; targets stay android + ios.** `windows/` is
  git-ignored and regenerated with `flutter create --platforms=windows .` when needed.
  Copying the project with robocopy turns the plugin symlinks in
  `windows/flutter/ephemeral/` into real folders; delete that folder after a copy.
- **Project moved to `D:\Flutter\mezat-app` (2026-10-23)** because C: is nearly full. Supabase
  data lives in Docker volumes keyed by `project_id`, so it survived the move.
- **Integration test waits for the first screen before signing out.** `Supabase.initialize`
  restores a saved session in the background; a sign-out sent before that finishes is undone.
  Not an app bug (a person cannot sign out within milliseconds of launch), but the test hit it.
- **`integration_test/` drives the real app against local Supabase** (sign-up → username →
  sign-out → sign-in). Passed on Windows desktop on 2026-10-23. Like `test_supabase/`, not
  in CI.

- **`AuthFailure` enum carries the user-facing message.** Repositories translate every
  Supabase error (auth `error_code`, Postgres SQLSTATE, connection errors) into it via
  `toAuthFailure`; anything unrecognised becomes `unknown`, so raw technical text never
  reaches the screen. The codes were checked against the local Auth server, not guessed.
- **Navigation is one pure function, `redirectFor(SessionStatus, location)`.** Screens never
  navigate after sign-in/sign-out; they change the session and go_router's redirect moves
  the user. Fewer places to get it wrong, and every case is unit tested.
- **One controller instance per form (`authControllerProvider(AuthForm.x)`).** A shared one
  let a sign-in error show up on the sign-up form. Controllers ignore a second submit while
  one is running (double-tap protection), and buttons are disabled meanwhile.
- **Email is trimmed and lowercased before every auth call; sign-up asks for the password
  twice.** Both target "I signed up but cannot log in", one of the most common auth complaints.
  Passwords are never trimmed.
- **Minimum password length 8**, in `config.toml` and the form (`minPasswordLength`).
- **`http` declared as a direct dependency (1.6.0, same as resolved).** Network failures
  surface as its `ClientException`, which `supabase_errors.dart` must match by type.
- **`test_supabase/` for tests that need the local stack.** Kept out of `test/` so plain
  `flutter test` (and CI) stays fast and offline.

- **profiles: RLS for rows, column grants for columns.** RLS only limits *which rows* an
  update may touch; it cannot stop a user changing `id` or `created_at` on their own row.
  So `authenticated` gets `UPDATE` only on `(username, avatar_url)`; insert/delete are
  revoked (rows come from the `handle_new_user` trigger and go with the auth.users cascade).
- **Profile row created by a trigger on `auth.users`, username null until chosen.** Sign-up
  and "choose username" are separate steps, so a taken username never blocks account
  creation, and every user is guaranteed a profile row. The router sends users with a null
  username to the choose-username screen.
- **Usernames normalized in the database** (trim + lowercase in a `before` trigger, format
  check `^[a-z0-9_]{3,20}$`). Uniqueness is then effectively case-insensitive without the
  `citext` extension, and the rule holds no matter which client writes.
- **Attacker checks for profiles (2026-10-23), against the local REST API:** no token, anon
  update, editing another user's row, changing `id`, direct insert/delete, calling
  `handle_new_user` over RPC and a forged JWT were all rejected; only a user's own
  username update succeeded. Locally a request without an `apikey` header is served as
  `anon`; harmless here (anon can only read public profiles) but worth re-checking on the
  hosted project.

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
