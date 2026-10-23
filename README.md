# Mezat

[![CI](https://github.com/denizdumbak/mezat-app/actions/workflows/ci.yml/badge.svg)](https://github.com/denizdumbak/mezat-app/actions/workflows/ci.yml)

A live-streamed auction app. A seller goes live and shows an item on camera; viewers place
bids in real time, and the highest bidder wins when the timer runs out.

> Status: **M0 – project setup.** Features land milestone by milestone (see below).

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
- Docker Desktop + Supabase CLI (for the local backend, not set up yet)

### Run

```sh
cp .env.example .env          # fill in the values
flutter pub get
flutter run --dart-define-from-file=.env
```

If `.env` is missing or invalid, the app starts on a configuration error screen that lists
what is wrong.

### Commands

| Task | Command |
| --- | --- |
| Run the app | `flutter run --dart-define-from-file=.env` |
| Static analysis | `flutter analyze` |
| Tests | `flutter test` |
| Local Supabase | _coming with the local backend setup_ |

## Project structure

```
lib/
  app/          # App widget, router, theme
  core/         # env config, Supabase client provider, shared widgets
  data/         # repositories (all Supabase access)
  features/     # auth, auctions, live_room
supabase/       # migrations, Edge Functions, SQL tests (coming)
test/
```

## Roadmap

- [ ] M0 Setup
- [ ] M1 Auth and profile
- [ ] M2 Create and list auctions
- [ ] M3 Live bidding (without video)
- [ ] M4 Live video
- [ ] M5 Ending and results
- [ ] M6 Polish and showcase

Decisions and known gaps are tracked in [NOTES.md](NOTES.md).
