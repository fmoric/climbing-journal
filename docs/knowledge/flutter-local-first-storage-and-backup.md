---
title: Local-first storage in Flutter with swappable backends and backup
tags: [flutter, dart, sembast, local-first, offline, repository-pattern, backup]
created: 2026-10-25
source: Climbing Journal project
summary: A repository interface with local, demo and cloud implementations; storing Firestore-shaped models in sembast; and a JSON backup so on-device data is not trapped on one phone.
---

# Local-first storage in Flutter with swappable backends and backup

## Decision

Start with no account and no server: everything on the device. Cloud sync (Firebase) comes later as an optional upgrade. This removed the hardest setup step (configuring Firebase from a phone) from the first release.

## One interface, three implementations

`JournalRepository` exposes streams (`watchCrags()`, `watchMyAscents()`) and fire-and-forget writes (`createRoute(...)`). Implementations:

| Mode | Build flag | Storage |
| --- | --- | --- |
| Local (default) | none | sembast database file on the device |
| Demo | `--dart-define=DEMO=true` | In memory with sample data |
| Cloud | `--dart-define=CLOUD=true` | Firestore with offline persistence |

The UI only knows the interface, so adding local mode did not touch any screen.

## sembast

- Pure Dart document store; `sembast_io` writes a file (use `path_provider` for the app's documents folder) and `sembast_web` uses IndexedDB. Pick with a conditional export: `export 'x_io.dart' if (dart.library.js_interop) 'x_web.dart';`
- Live queries: `store.query(finder: Finder(filter: ..., sortOrders: ...)).onSnapshots(db)` returns a stream, matching Firestore's `snapshots()`.
- Tests: `newDatabaseFactoryMemory().openDatabase('t.db')`.

## Storing Firestore-shaped models

The models' `toMap()` contains Firestore `Timestamp` and `GeoPoint`, which sembast and JSON cannot store. A small codec converts them recursively: `Timestamp` ↔ `{"_ts": ms}`, `GeoPoint` ↔ `{"_geo": [lat, lng]}`. Models stay unchanged, and the same codec makes backups plain JSON. Fields stored as these maps cannot be sorted by the database, so sort dates in Dart.

## Backup (essential for local-only data)

On-device data disappears when the app is uninstalled or the signing key changes. The backup is one JSON document: `format`, `version`, `exportedAt`, then arrays per collection with `id` inside each record.

- Export: `share_plus` opens the share sheet with an in-memory file (`XFile.fromData`), so users save it to Drive or email it.
- Import: `file_picker`, validate `format` and `version` (refuse newer versions), show counts, confirm, then replace everything inside one database transaction.
- Photos are not in the JSON backup; say so in the UI where a missing photo would show.

## Writes

Writes are not awaited by the UI. Firestore resolves a write's Future only when the server acknowledges it, which never happens offline; local writes follow the same contract and report failures through a callback.
