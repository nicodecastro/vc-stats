# VC SETS

VC SETS (Statistics & Event Tracking System) is a local-first indoor volleyball tournament and statistics application for the UPLB Volleyball Club. It runs as a native Windows or Android app and as an installable offline PWA for iPhone, iPad, macOS, and Linux.

## What works

- Tournament-specific teams and rosters
- Round-robin and multi-pool fixture generation
- Optional pool-to-knockout and knockout-only formats
- Cross-pool qualification, configurable match formats, and optional third-place playoffs
- Independent two-device rally scoring
- Standard volleyball action events and event-derived statistics
- Hashed `.vcgame` exchange packages with duplicate-import protection
- Per-rally reconciliation and official match finalization
- Versioned full backups and CSV reports
- Native SQLite and browser SQLite/WASM persistence

## Local development

Flutter is expected on `PATH`. From the `app` directory:

```powershell
flutter pub get
flutter test
flutter run -d windows
flutter run -d chrome
```

The web build needs `web/sqlite3.wasm` and `web/drift_worker.js`. They are checked in so the PWA can start without a runtime CDN.

## Match-day workflow

1. Create a tournament, teams, rosters, and fixtures on the tournament device.
2. Export the fixture as a `.vcgame` starter package and import it on the second device.
3. On each device, select the assigned team and the same first server.
4. Both scorers award every rally; each records player actions only for its assigned team.
5. Export the second scorer’s completed `.vcgame` and import it on the tournament device.
6. Resolve every highlighted score discrepancy and finalize the combined official record.
7. Export a full backup after the match day.

Packages and backups are plain JSON and can contain player information. Store them appropriately.

## Free PWA deployment

The included GitHub Pages workflow publishes only the compiled application shell. All volleyball data remains in the device’s local browser database until the user exports it.
