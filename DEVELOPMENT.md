# Local Development Setup

Run the OR Scheduler locally using Firebase emulators for Firestore and Storage.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.5+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Node.js | 18+ | [nodejs.org](https://nodejs.org) |
| Java | 11+ | `brew install openjdk` (macOS) |
| Firebase CLI | 13+ | `npm install -g firebase-tools` |

## Quick Start

```bash
# 1. Clone and install dependencies
git clone <repo-url> && cd schedule-OR
make setup

# 2. Start everything (emulators + seed data + app)
make dev
```

The app opens at **http://localhost:3000**.

## Test Credentials

Seeded into the Firebase Auth emulator:

| Role | Email | Password |
|------|-------|----------|
| Doctor | `doctor@test.com` | `password123` |
| Nurse | `nurse@test.com` | `password123` |
| Technologist | `tech@test.com` | `password123` |
| Admin | `admin@test.com` | `password123` |

## How It Works

When the app detects it's running on `localhost`, it automatically connects to Firebase emulators:

| Service | Production | Local Emulator |
|---------|-----------|----------------|
| Auth | Firebase Auth | `:9099` |
| Firestore | Cloud Firestore | `:8181` |
| Storage | Cloud Storage | `:9199` |
| Emulator UI | — | http://localhost:4000 |

Detection is in `lib/main.dart` (`_connectToEmulatorsIfLocal`) and `web/index.html` (JS-level auth emulator for the compat SDK).

## Available Commands

```bash
make setup        # Install dependencies and check tools
make dev          # Start emulators + seed + run app (all-in-one)
make emulators    # Start Firebase emulators only
make seed         # Seed test data into emulators
make seed-reset   # Clear all emulator data and re-seed
make run          # Run the Flutter app (emulators must be running)
make stop         # Stop Firebase emulators
make analyze      # Run Flutter static analysis
make test         # Run tests
make clean        # Stop emulators and clean build artifacts
```

## Step-by-Step (Manual)

```bash
# Terminal 1: Start emulators
firebase emulators:start --only auth,firestore,storage

# Terminal 2: Seed test data (wait for emulators to be ready)
node scripts/seed.js

# Terminal 3: Run the app
flutter run -d chrome --web-port 3000
```

## Emulator Data Persistence

Emulator data persists between restarts via `emulator-data/`:

- `make emulators` auto-imports and exports data
- `make seed-reset` clears everything and re-seeds
- `make clean` deletes the saved data

## Firestore/Storage Rules

Emulators use permissive rules (`firestore.emulator.rules`, `storage.emulator.rules`) so you can develop without permission issues. Production deploys use the strict `firestore.rules` and `storage.rules`.

## Known Limitation: Auth Emulator on Web

Flutter's `firebase_auth_web` package has a known issue where `connectAuthEmulator` does not fully redirect auth API calls in compiled web builds. The workaround is dual-layered:

1. **Dart-level**: `_connectToEmulatorsIfLocal()` in `main.dart` calls `useAuthEmulator` (works for Firestore/Storage)
2. **JS-level**: `web/index.html` loads the Firebase Auth compat SDK and connects it to the emulator on localhost

If you still see auth calls going to `identitytoolkit.googleapis.com`, sign up a fresh test account through the app's Sign Up form — this creates the user in Firebase Auth (which persists across sessions) and the profile in the local Firestore emulator.

## Troubleshooting

**Emulators won't start** — Check if ports are in use: `lsof -i :9099 -i :8181 -i :4000`

**"Missing or insufficient permissions"** — Emulators may have restarted without seed data. Run `make seed`.

**Auth fails with "credential is incorrect"** — The auth emulator may not have the test users. Run `make seed` to recreate them, or sign up a new account through the app.

**Composite index errors** — Some Firestore queries need composite indexes. The emulator auto-creates these, but you may see warnings on first query.
