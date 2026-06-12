# FitTrack

> Offline-first fitness tracker built with Flutter. Tracks gym workouts, home bodyweight exercises, timed sessions, and EMOM circuits — all stored locally on device. No accounts, no sync, your data stays on your phone.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-sqflite-003B57?logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🏋️ Gym Mode
- 6 muscle groups: Chest, Back, Triceps, Biceps, Shoulders, Legs
- Multi-group workout sessions ("Train multiple groups")
- Per-set reps and weight logging with rest timer (1–3 min presets)
- Custom exercises per muscle group

### 🏠 Home Mode
- **Bodyweight reps:** Pushups, Pullups, Squats, Abs — multiple variants each
- **Stopwatch sessions:** Planks (3 variants), Rope Skipping
- **EMOM (Every Minute On the Minute):** circuit workouts with:
  - Configurable total minutes (1–60) and multi-exercise rounds
  - Saveable templates loaded with one tap
  - Audible countdown beeps + progressive haptic cues for the last 5 seconds
  - Distinct "go" tone + heavy haptic at each minute start
  - Per-minute completion tracking

### 📊 History & Tracking
- Workout history with type-coded badges (gym, home, plank, skipping, EMOM)
- Per-exercise personal-record tracking
- Sleep duration logging with charts
- Body weight log
- Notes
- Full JSON export and import for data backup

## Tech Stack

| Layer | Tech |
|-------|------|
| Framework | Flutter (Material 3, dark theme) |
| Database | SQLite via `sqflite` — versioned migrations |
| Local prefs | `shared_preferences` |
| Charts | `fl_chart` |
| Audio | `audioplayers` |
| Files | `file_picker`, `share_plus`, `path_provider` |
| State | Stateful widgets — no external state library |

## Architecture Highlights

### Versioned database migrations
The SQLite schema lives in `lib/db/db_helper.dart` and is versioned via a `_dbVersion` constant. Migrations are idempotent — running v1→v3 on an empty database has the same result as a fresh `onCreate`. Each schema bump adds tables/columns via `ALTER TABLE` and re-seeds exercise data using a name-based existence check, so user data is preserved across upgrades.

| Version | Changes |
|---------|---------|
| v1 | Initial schema (sleep, exercises, sessions, sets, notes, body_weight) |
| v2 | Added `workout_type` discriminator and `duration_seconds` to sets; seeded Legs |
| v3 | Added `emom_templates` table; seeded home exercises (Pushups, Pullups, Squats, Abs, Planks, Rope Skipping) |

### Single workout schema, multiple workout types
All workouts (gym, bodyweight, timed sessions, EMOM circuits) share the same `workout_sessions` and `workout_sets` tables. The `workout_type` field on the session and `duration_seconds` field on each set let one table model rep-based, time-based, and circuit-based exercises without separate tables.

### EMOM timing engine
The EMOM runner uses a 1-second `Timer.periodic` ticker. Each minute is a 60-second segment with a 5-second countdown window that fires a tick beep + progressive haptic on each remaining second, then a "go" beep + heavy triple haptic at the minute boundary. Per-minute completion is tracked separately from elapsed time, so total reps saved = prescribed reps × completed minutes.

## Setup

```bash
git clone https://github.com/AnasCodeVerse/fittrack.git
cd fittrack
flutter pub get
flutter run
```

**Requires:**
- Flutter 3.x
- Android NDK 27.0.12077973 (pinned in `android/app/build.gradle.kts`)
- Android SDK 21+

Open `lib/main.dart` to launch. Credentials are set on first launch via the login screen and can be changed in Settings.

## Project Structure

```
lib/
├── main.dart
├── db/
│   └── db_helper.dart                # Schema, migrations, CRUD
├── utils/
│   ├── theme.dart                    # Dark theme + color palette
│   └── auth_helper.dart
└── screens/
    ├── login_screen.dart
    ├── home_screen.dart              # Bottom nav shell
    ├── dashboard_screen.dart
    ├── workout_screen.dart           # Gym/Home toggle + history
    ├── workout_log_screen.dart       # Reps+weight or bodyweight mode
    ├── stopwatch_session_screen.dart # Planks
    ├── rope_skipping_screen.dart
    ├── emom_setup_screen.dart
    ├── emom_run_screen.dart
    ├── sleep_screen.dart
    ├── progress_screen.dart
    ├── notes_screen.dart
    └── settings_screen.dart

assets/
└── sounds/
    ├── tick.wav                      # Countdown tick (880 Hz, 90ms)
    └── go.wav                        # Minute-start tone (600 Hz, 350ms)
```

## Screenshots

_assets/Sreenshots_

## Development Notes

Built iteratively across multiple phases:

1. **Phase 1** — Core gym tracking (5 muscle groups), sleep, notes, body weight
2. **Phase 2** — Legs added, Gym/Home toggle, home bodyweight exercises, stopwatch sessions (Plank, Rope Skipping), EMOM workouts with saveable templates
3. **Phase 3** — Audio cues for EMOM (`audioplayers` + bundled WAV beeps)

This project was built with the help of Claude (Anthropic) for architecture planning, schema design, and iterative feature scoping. All product decisions, testing on-device (Xiaomi MIUI), and final implementation choices were made by me.

## License

MIT — see `LICENSE`
