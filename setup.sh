#!/usr/bin/env bash
# One-time setup for Climbing Journal (M1-01).
# Needs: Flutter SDK, Firebase CLI (`npm i -g firebase-tools`), and
# a Firebase project you can access (`firebase login` first).
set -euo pipefail
cd "$(dirname "$0")"

# 1. Generate Android/iOS folders and pubspec. Existing lib/ and test/ files
#    are kept; flutter create only adds what is missing.
flutter create --org hr.climbingjournal --project-name climbing_journal \
  --platforms=android,ios .

# The generated sample test references a counter app that does not exist.
rm -f test/widget_test.dart

# 2. Dependencies at their current versions.
flutter pub add firebase_core firebase_auth cloud_firestore uuid

# 3. Link to Firebase; writes lib/firebase_options.dart.
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios

# 4. Deploy security rules and indexes.
firebase deploy --only firestore

# 5. Model tests.
flutter test

echo
echo "Done. Before first run, follow 'Create your account' in README.md."
