# NOTES

Decisions and technical debt. Newest on top within each section.

## Open work

- Android licenses are not accepted on the dev machine (`flutter doctor --android-licenses`,
  interactive). Not needed for tests; needed before the first Android build.

## Technical debt

- **End-to-end test files must run one at a time on Windows.** `flutter test integration_test
  -d windows` passes the first file, then fails to launch the app for the second ("Error
  waiting for a debug connection: The log reader stopped unexpectedly"); each file passes on
  its own. Looks like a desktop tooling issue; revisit on a Flutter upgrade or on Android.
- **The live room is read-only on real auctions until M3.** `SupabaseAuctionFeedRepository`
  serves the lists, start and the room's auction data, but no bids, bid feed, today's total or
  realtime (lists refresh by pulling down). The room shows "Teklif verme henüz açık değil."
- **Auctions whose time is up stay `live` in the database until M5** (`finalize_ended_auctions`
  with pg_cron). The client hides them by `ends_at`; the server rule comes with M5.
- **Pull to refresh uses Material's `RefreshIndicator` spinner** (gold on stageRaised), the one
  place the stock progress indicator remains; a custom one is not worth it before M6.
- **Bid safety is client-side only.** The daily limit lives in memory
  (`InMemorySpendingLimitRepository`, lost on restart) and is checked in the screen. M3: store
  it in `profiles` and enforce it in `place_bid`, or a modified client can ignore it.
- **Seller-set increment chips have no column yet.** The room shows `defaultIncrements`
  (+₺10/+₺50/+₺100); the create form does not ask for them. M3: `bid_increments numeric[]`
  on `auctions` (each >= `min_increment`) and a field in the form.
- **Maximum (proxy) bids exist only in the mock.** `place_bid` needs the server-side version
  in M3 (store the max, answer outbids one step at a time inside the same transaction).
- **Screenshots are rendered in the test engine, not on a device** (`test_screenshots/`), since
  no Android emulator is set up. Real fonts and layout, but no platform chrome, keyboard or
  real video. Check on a phone before M6.

- **On desktop the photo is not scaled down** (`image_picker` ignores `maxWidth` there), so a
  large original hits the 5 MB bucket limit and shows the "too large" message. Phones are
  the target; fine for local trying.

- **Orphan photos:** a photo uploaded for an auction that is never created stays in the
  bucket. The app deletes it when the insert fails, but a crash in between leaves it.
  A periodic cleanup (objects not referenced by any `auctions.image_path`) can come later.
- **Image type is trusted from the upload's `Content-Type`.** Storage checks the declared
  type against `allowed_mime_types`, not the bytes; a non-image declared as `image/jpeg` is
  accepted (seen in the attacker run). Low risk: the bucket only serves files back with that
  type. Revisit if uploads are ever processed server-side.
- **Sellers cannot edit or cancel an auction yet** (no client update/delete on `auctions`).
  A `cancel_auction` RPC for `scheduled` auctions is the natural next step after the MVP.

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

- **M2 (c): real lists behind the same interface (2026-10-24).** `SupabaseAuctionFeedRepository`
  implements `AuctionFeedRepository`, so the screens did not change. One query per list
  (amounts as `::text`, seller via `profiles!auctions_seller_id_fkey`, photo URL built from
  `image_path`); Keşfet shows live auctions and other sellers' upcoming ones, Yayın aç your
  own planned ones. Without realtime each list is one snapshot; creating or starting an
  auction invalidates them, and pulling down reloads. The room reads the auction once and
  emits again at `ends_at` so "time is up" appears without a server push.
- **Chips respect the seller's minimum step:** with a minimum above ₺10 the chips are 1×, 5×
  and 10× of it (the server will refuse smaller steps), until sellers can set their own (M3).
- **Viewer count hidden while unknown** (0 before presence arrives with the video in M4):
  a "0" next to a live auction would look broken and discouraging.
- **Demo mode kept:** `--dart-define=MOCK_FEED=true` runs everything on the in-memory mock with
  simulated bidders, to show the bidding UI before M3.
- **No separate auction detail screen in M2.** The lists and the live room cover "live and
  upcoming auctions on the home screen"; a detail page for upcoming auctions can come with M5
  or M6 if needed.

- **Anti-sniping stays at CLAUDE.md's rule: a bid in the last 30 s extends by 30 s
  (2026-10-24).** The design brief had "last minute, +15 s"; the developer chose to keep the
  server rule for now and revisit later. Values live in `lib/core/auction_rules.dart`;
  `place_bid` (M3) must use the same numbers.

- **Design language "Lacivert + altın", dark only (2026-10-24).** Decided by the developer's
  design brief; written down in `DESIGN.md` (look, tokens, motion) and `PRODUCT.md` (tabs,
  live room, bidding, safety layer). All values come from `lib/app/design_tokens.dart`; the
  theme maps them onto a hand-built `ColorScheme` instead of `fromSeed`. Token names are
  English in code (`gold`, `urgent`, `success` for altın, zaman, onay) per the
  English-identifiers rule; DESIGN.md lists both.
- **Fonts bundled in `assets/fonts`, not `google_fonts`.** The brief allowed `google_fonts`
  for the MVP, but it downloads fonts on first launch (a request to Google, nothing offline)
  and needs workarounds in tests. Static TTFs (Fraunces 600/700, Manrope 400–800, SIL OFL)
  cost ~600 KB, need no dependency, and let `fonts_test.dart` read the files and prove every
  Turkish letter, ₺ and Manrope's tabular figures are there.
- **Review findings applied after the first screenshots:** gold fill only on the primary
  button (selected chip and segment use gold outline/text instead), disabled primary button
  filled with `line` so it still reads as a button on panels, usernames always in Manrope
  (Fraunces' "@" is ornamental), a stronger scrim for "sold"/"time is up", the video
  placeholder moved out from behind the bid feed, live-card pills and section labels allowed
  to shrink/wrap (found by the 360 px tests).
- **Safety thresholds, as interpreted:** "over the threshold" means at or above ₺1.000; the
  total-based confirmation fires when a bid takes today's total across the threshold, not on
  every bid afterwards. "Today's total" is the sum of auctions the user leads or won today; a
  new bid in the same auction replaces the old one. Threshold override:
  `--dart-define=BID_CONFIRM_THRESHOLD_TRY=1500`.
- **No live chat in the room.** The brief's layout mentions chat, but CLAUDE.md keeps live chat
  out of the MVP; the left column shows the bid feed instead.
- **Amounts display with a leading lira sign** ("₺1.250"), as the brief writes them.
- **Tests adapted to the new layout, flows unchanged:** sign-out moved from the home app bar to
  the Profil tab, the home placeholder text is now `DiscoverScreen`, the busy spinner is
  `AppLoader`, the create form opens from the Yayın aç tab. The end-to-end test was updated
  the same way and passed on Windows against local Supabase.

- **Locale fixed to Turkish (2026-10-24).** `flutter_localizations` (part of the Flutter SDK,
  no version to pin) with `locale: tr` and only `tr` supported. Every app text is Turkish, so
  following the device locale would give an English phone English date pickers and
  tooltips inside a Turkish app.

- **Money is whole kuruş in an `int` (`Money`), sent and read as text (2026-10-24).** Dart
  has no decimal type and doubles cannot hold 0.10 exactly. PostgREST returns `numeric` as a
  JSON number, which `jsonDecode` turns into a double, so reads cast in the select
  (`current_price::text`) and writes send `"1250.50"`. `Money.tryParse` reads Turkish input
  ("1.250,50"; "1.250" is 1250 TL) and also "12.5" for dot-only keyboards. Verified with the
  largest `numeric(12,2)` value against the local database. No `decimal` package needed.
- **`AppFailure` interface over per-feature failure enums.** `AuthFailure` and
  `AuctionFailure` both implement it; `failureMessage(error)` gives any widget the Turkish
  text. The shared form frame moved from `features/auth/widgets` to
  `core/widgets/form_layout.dart` (`FormLayout`, `FailureMessage`, `SubmitButton`) because
  the auction form uses it too.
- **`image_picker` 1.2.4 for the photo (the only new dependency in M2).** Official flutter.dev
  package; gallery only (no camera permission needed). Photos are scaled to 1600 px and JPEG
  quality 85 on the phone, which keeps them well under the 5 MB bucket limit. Wrapped in a
  `PhotoPicker` provider so widget tests pick a photo without a gallery. Android needs no
  permission (system photo picker); iOS got `NSPhotoLibraryUsageDescription`.
- **Photo first, then the row; the photo is deleted if the insert fails.** The row needs the
  path, so the upload must come first. Object names are random (not guessable, never
  overwrite). Remaining gap: see "Orphan photos" under technical debt.
- **Photo is optional.** An auction without one gets a placeholder; requiring it would block
  quick test auctions during development and demos.

- **The seller starts the auction; it does not start by the clock (2026-10-24).** In a live
  stream the auction should begin when the seller is on camera, not at a time they may miss.
  An auction opens as `scheduled` with a planned `starts_at` and a `duration_minutes`;
  `start_auction(id)` (seller only, row locked with `FOR UPDATE` against double taps) sets
  `live`, `starts_at = now()`, `ends_at = now() + duration`. `duration_minutes` is a column
  the first data model draft did not have. Rejected: pg_cron flipping `scheduled` to `live`
  at `starts_at` (simpler, but starts auctions with nobody streaming).
- **No seller role in the MVP (2026-10-24).** Any user with a username may create auctions.
  Ownership per auction (`seller_id`) already answers who may start it and who may not bid;
  a role would only mean something with a seller approval process (identity, payouts),
  which is out of scope. Adding one later is a `profiles` column plus one policy condition.
- **`image_path` instead of `image_url` (2026-10-24).** The column stores the object path in
  the `auction-images` bucket (`<seller_id>/<file>`); the app builds the public URL. A stored
  URL would bake in the host, which differs between local (`127.0.0.1`), the Android emulator
  (`10.0.2.2`) and hosted. The insert policy requires the path to be in the seller's own
  folder, so an auction cannot show someone else's photo.
- **Server-owned auction fields are set by a `before insert` trigger** (status `scheduled`,
  `current_price = start_price`, no winner, no end), on top of column grants that let clients
  insert only the form columns. The start-time window (5 minutes in the past to 30 days
  ahead) is checked there too, not in a check constraint: check constraints run again on
  every update, when `now()` has moved on and a valid row would suddenly fail.
- **Domain errors are raised as a code in the message** (`raise exception 'NOT_AUCTION_SELLER'`,
  SQLSTATE `P0001`). The app matches the code and shows Turkish text; `place_bid` (M3) uses
  the same convention.
- **Bucket created in a migration, not `config.toml`.** `config.toml` buckets exist only
  locally; the migration gives the hosted project the same bucket, limits and policies.
- **Attacker checks for auctions and storage (2026-10-24)**, against the local REST and
  Storage APIs: no token, anon key only, forged JWT, setting status/seller/price/winner,
  someone else's photo path, update/delete, starting someone else's auction, calling the
  trigger function, anon upload, upload into another user's folder, wrong type, over 5 MB,
  deleting another user's photo. All rejected; the legitimate paths worked.
- **pgTAP storage tests set `storage.allow_delete_query`.** Storage blocks plain SQL deletes
  on its tables unless that setting is on (the Storage API turns it on for its own queries).

- **Commit straight to `main`, no branches or PRs (2026-10-24).** Replaces the GitHub Flow
  decision of 2026-10-23. With one developer and no reviewer, a branch + PR per change was
  ceremony: nobody reviews the PR, and its main benefit, a CI gate before merge, does not
  work while GitHub Actions is blocked. The guarantee that `main` works now comes from running
  `flutter analyze` and `flutter test` locally before every commit (plus SQL tests when the
  schema changes). Given up: the PR trail as a portfolio signal and one-commit-per-feature
  history; small, conventional commits keep the log readable instead. Revisit if a second
  developer joins or store releases need stabilising.
- **Rejected: Git Flow (2026-10-23).** No release trains, so a long-lived `develop` branch
  would only add a second place to merge into.
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
