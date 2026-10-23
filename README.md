# Mezat

[![CI](https://github.com/denizdumbak/mezat-app/actions/workflows/ci.yml/badge.svg)](https://github.com/denizdumbak/mezat-app/actions/workflows/ci.yml)

A live-streamed auction app. A seller goes live and shows an item on camera; viewers place
bids in real time, and the highest bidder wins when the timer runs out.

> Status: **M2 – auctions.** Sign-up, profiles, creating auctions with a photo, and the
> lists of live and upcoming auctions work against Supabase. Live bidding arrives in M3; until
> then the live room is read-only (a demo mode with simulated bidding is available, see below).

## Design

Dark "navy and gold" look, Fraunces for headings and Manrope for text, built for one-handed
use in Turkish. The visual language and its tokens are in [DESIGN.md](DESIGN.md), the product
rules (tabs, live room, bidding, spending limits) in [PRODUCT.md](PRODUCT.md).

## Stack

| Layer | Technology |
| --- | --- |
| Mobile | Flutter (stable), Dart, Riverpod, go_router |
| Backend | Supabase: Auth, Postgres, Realtime, Storage, Edge Functions |
| Live video | LiveKit Cloud + `livekit_client` |
| Tests | `flutter test`, pgTAP via `supabase test db` |

## Architecture

```
Widget → controller/provider (Riverpod) → repository (lib/data) → Supabase
```

Bids are validated only on the server: the client calls the `place_bid` Postgres function,
which locks the auction row, checks the rules and writes the bid. Row Level Security is on
for every table. The LiveKit secret never reaches the app; tokens come from an Edge Function.

## Getting started

### Prerequisites

- Flutter **3.41.4** (stable). CI uses the same version.
- Android SDK (for running on Android)
- Docker Desktop (running) and Node.js. The Supabase CLI is a pinned npm devDependency,
  so `npm install` is enough; use it through `npx supabase`.

### Run

```sh
npm install                   # installs the pinned Supabase CLI
npx supabase start            # local backend; prints the API URL and publishable key
cp .env.example .env          # put the publishable key into SUPABASE_ANON_KEY
flutter pub get
flutter run --dart-define-from-file=.env
```

Local ports are in the 553xx range (API `55321`, DB `55322`, Studio `55323`) instead of
Supabase's default 543xx, which Windows often reserves for Hyper-V/WSL.

If `.env` is missing or invalid, the app starts on a configuration error screen that lists
what is wrong (also printed to the console).

**IDE run buttons** do not pass `--dart-define-from-file=.env` by themselves, which leads
to exactly that screen. VS Code is set up in the repo: `.vscode/settings.json` adds the arg
to every `flutter run` (F5, the Run/Debug links above `main()`). Android Studio / IntelliJ:
*Edit Configurations* → `main.dart` → *Additional run args* → `--dart-define-from-file=.env`.

### Commands

| Task | Command |
| --- | --- |
| Run the app | `flutter run --dart-define-from-file=.env` |
| Run in demo mode (simulated auctions and bidders) | `flutter run --dart-define-from-file=.env --dart-define=MOCK_FEED=true` |
| Static analysis | `flutter analyze` |
| Tests | `flutter test` |
| Start / stop local Supabase | `npx supabase start` / `npx supabase stop` |
| Apply new migrations | `npx supabase migration up` |
| Rebuild DB from migrations | `npx supabase db reset` |
| SQL tests (pgTAP) | `npx supabase test db` |
| Repository tests against local Supabase | `flutter test test_supabase --dart-define-from-file=.env` |
| End-to-end UI test (real app + local Supabase), one file at a time on Windows | `flutter test integration_test/auth_flow_test.dart -d windows --dart-define-from-file=.env` (same for `auction_flow_test.dart`) |
| Screenshots of every screen for design review | `flutter test test_screenshots --update-goldens` (PNGs in `test_screenshots/goldens/`) |

## Development workflow

Trunk-based: a single developer commits straight to `main`, which stays green because
`flutter analyze` and `flutter test` (plus SQL tests when the schema changes) run locally
before every commit. Commit messages are one short sentence.

## Project structure

```
lib/
  app/              # App widget, router, tab shell, theme, design tokens
  core/             # env, Supabase client, Money, failures, shared widgets
  data/             # repositories (all Supabase access) and the demo mock
  features/         # auth, auctions, live_room, profile
assets/fonts/       # Fraunces and Manrope (SIL OFL)
supabase/           # config.toml, migrations, SQL tests (Edge Functions from M4)
test/               # unit and widget tests (run in CI)
test_supabase/      # repositories against local Supabase
integration_test/   # the real app, end to end
test_screenshots/   # renders every screen to PNG for design review
```

## Roadmap

- [x] M0 Setup
- [x] M1 Auth and profile
- [x] M2 Create and list auctions
- [ ] M3 Live bidding (without video)
- [ ] M4 Live video
- [ ] M5 Ending and results
- [ ] M6 Polish and showcase

Decisions and known gaps are tracked in [NOTES.md](NOTES.md).
