# Climbing Journal

Offline-first climbing logbook. Flutter (Android, iOS, web).

The functional spec is the living document in the Clibing Journal project.

## Use it on a phone

**Web app (works on managed phones):** open https://fmoric.github.io/climbing-journal/app/ in Chrome, then menu ⋮ → **Add to home screen** (or **Install app**). It opens like an app, works offline after the first visit, and keeps the logbook and photos in the browser's storage on the phone. Clearing Chrome's site data deletes them, so export a backup from History now and then.

## Install on Android

Download **[climbing-journal.apk](https://github.com/fmoric/climbing-journal/releases/download/latest/climbing-journal.apk)** on the phone and open it. Android asks once to allow installs from your browser or file app.

Each push to `main` publishes a new build at the same link. Installing it updates the app and keeps your logbook.

**Web demo** (sample data, nothing saved): https://fmoric.github.io/climbing-journal/

Phones with a company work profile often block APK installs entirely; use the web app there.

## Modes

| Mode | Build | Storage |
| --- | --- | --- |
| Local (default, M1) | `flutter run` | On the device; no account. Backup export/import in History |
| Demo | `--dart-define=DEMO=true` | In memory, sample data |
| Cloud (M2) | `--dart-define=CLOUD=true` | Firebase sign-in and sync |

Local mode keeps data only on the phone. Uninstalling the app deletes it, so export a backup regularly.

## Signing

Release APKs are signed with `android/signing/sideload.p12`, committed so every build updates the installed app. Anyone with this repo can sign with it, which is acceptable for personal sideloading only. Replace it, and keep the new key out of the repo, before any store release.

## Cloud setup (M2)

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
| `lib/data/` | Repository interface; local (sembast), Firestore and demo implementations |
| `lib/domain/` | Grades and conversion, nearest crag, duplicate matching, stats |
| `lib/report/` | Yearly PDF report |
| `lib/ui/` | Log tab, quick log, add route, history, backup |
| `lib/screens/` | Sign-in |
| `firestore.rules` | Members only; shared crags/sectors/routes; owner-only ascents |
| `firestore.indexes.json` | Composite indexes for the repository's queries |
| `test/` | Model, domain, local storage, backup, report and screen-flow tests |

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
