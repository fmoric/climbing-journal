#!/usr/bin/env bash
# One-time setup for Climbing Journal on your machine.
# Needs: Flutter SDK, Firebase CLI (`npm i -g firebase-tools`) and
# `firebase login` done once.
set -euo pipefail
cd "$(dirname "$0")"

flutter pub get

# Link to your Firebase project; writes lib/firebase_options.dart.
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios,web

# Deploy security rules and indexes.
firebase deploy --only firestore

flutter test

echo
echo "Done. Before first run, follow 'Create your account' in README.md."
