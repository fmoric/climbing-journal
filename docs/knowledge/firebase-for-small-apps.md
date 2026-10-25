---
title: Firebase for a small invite-only app
tags: [firebase, firestore, authentication, security-rules, offline]
created: 2026-10-25
source: Climbing Journal project
summary: What Firebase provides, how invite-only access works with security rules, and the console setup steps for a Flutter app.
---

# Firebase for a small invite-only app

## What it is

Firebase is Google's hosted backend for mobile and web apps: the app talks directly to Google's services instead of a server you run.

- **Authentication** stores accounts and passwords and tells the app who is signed in.
- **Firestore** is a document database with built-in **offline sync**: a full local cache on the phone, writes applied locally at once and uploaded when back online.
- **Security rules** run on Google's side and decide who can read or write each document, so a modified app cannot bypass them.

The free Spark plan covers a small group comfortably (roughly 1 GB of Firestore storage and tens of thousands of reads and writes per day).

## Invite-only with rules

No sign-up screen. The admin creates each user in **Authentication → Users** and adds a document `members/<uid>` with `role: "admin"` or `"member"`. Rules then check `exists(/databases/$(database)/documents/members/$(request.auth.uid))` for every read and write. Shared data (crags, routes) is writable by members with an `updatedBy == request.auth.uid` stamp; personal records (ascents) are readable and writable only by their owner unless marked shared.

## Console setup (works from a phone browser)

1. console.firebase.google.com → Create project (Analytics off).
2. Authentication → Get started → Email/Password on; Users → Add user; copy the UID.
3. Firestore → Create database → EU location (e.g. `europe-west3`) → Production mode.
4. Data → Start collection `members` → document ID = your UID → field `role` = `admin`.
5. Rules → paste the project's rules → Publish.
6. Indexes → composite indexes for each query that filters on one field and sorts on another.
7. Project settings → add Web and Android apps; the config values (apiKey, appId, projectId, messagingSenderId) identify the project and are not secret.

Console deep links take the form `https://console.firebase.google.com/project/PROJECT_ID/firestore/rules`.

## Lesson

Even with good instructions, this setup is awkward on a phone. Shipping a local-only first version and adding Firebase later kept the app usable without it.

## Gotcha

Never `await` a Firestore write in the UI: offline, the Future completes only after the server acknowledges it, so the UI would hang until signal returns.
