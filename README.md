# Climbing Journal

Offline-first climbing logbook for a small, invite-only circle. Flutter (Android + iOS) on Firebase.

The functional spec is the living document in the Clibing Journal project. This repo covers M1-01 and M1-02.

## Setup

1. Install the Flutter SDK and the Firebase CLI (`npm i -g firebase-tools`), then run `firebase login`.
2. Create a Firebase project in the console. Enable **Authentication → Email/Password** and **Firestore**.
3. Run `./setup.sh`. When `flutterfire configure` asks, pick the project from step 2.

## Create your account

There is no sign-up screen; membership is invite-only.

1. In **Authentication → Users**, add a user with your email and a password. Copy the user's UID.
2. In **Firestore**, create the document `members/<UID>` with the field `role` = `admin` (string).

Without that member document, the security rules refuse every read and write.

## Run

```
flutter run
```

Sign in, add a crag, then try it in airplane mode: the crag appears at once and syncs when you reconnect.

## Layout

| Path | Purpose |
| --- | --- |
| `lib/models/` | Crag, Sector, ClimbRoute, Ascent and enums; plain maps to and from Firestore |
| `lib/data/journal_repository.dart` | All reads and writes; client IDs, audit stamps, non-awaited writes |
| `lib/screens/` | Sign-in and a crag list used as a smoke test |
| `firestore.rules` | Members only; shared crags/sectors/routes; owner-only ascents |
| `firestore.indexes.json` | Composite indexes for the repository's queries |
| `test/models_test.dart` | Model round-trip tests |

## Data model

Flat top-level collections, linked by IDs:

- `members/{uid}`: `role` (`admin` or `member`)
- `crags/{id}`: `name`, `type` (`outdoor` or `gym`), `location`
- `sectors/{id}`: `cragId`, `name`, `location`
- `routes/{id}`: `cragId`, `sectorId`, `name`, `discipline`, `grade`, `gradeSystem`, `pitches`, `setDate`, `retiredDate`
- `ascents/{id}`: `userId`, `routeId`, `cragId`, `date`, `style`, `attempts`, `notes`, `visibility`

Shared documents also carry `createdBy`, `createdAt`, `updatedBy` and `updatedAt`.

## Conventions

- **Never await a write.** Offline, Firestore resolves a write only after the server acknowledges it. The repository fires writes and reports server rejections through `onWriteError`.
- **IDs come from the device** (UUID v4), so anything can be created offline.
- **Grades are stored as entered** with their system; conversion is display-only (M1-03).
