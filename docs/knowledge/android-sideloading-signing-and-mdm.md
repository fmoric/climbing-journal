---
title: Distributing a personal Android app outside the Play Store
tags: [android, apk, signing, sideloading, mdm, work-profile, google-play]
created: 2026-10-25
source: Climbing Journal project
summary: What signing does and does not solve for sideloaded APKs, how to give users a stable download link, and why a managed work profile can block installs entirely.
---

# Distributing a personal Android app outside the Play Store

## Signing keeps updates working; it does not remove warnings

- Android installs an update only if it is signed with the **same key** as the installed app. A different key means uninstall first, which **deletes the app's on-device data**.
- Flutter's template signs release builds with the debug key. On CI the debug key is regenerated per run, so every build would have a new key. Use a fixed release key.
- The "Install unknown apps" prompt is about the **install source** (a browser or file manager), not the signature. It is granted once per source app. Play Protect may additionally show an "unrecognised app" warning; "Install anyway" proceeds.

## Stable download link from CI

1. Build with `flutter build apk --release --build-number=${{ github.run_number }}` so each build's versionCode increases.
2. Replace a GitHub release tagged `latest` on every push to main:
   ```
   gh release delete latest --yes --cleanup-tag || true
   gh release create latest app.apk --target "$GITHUB_SHA"
   ```
3. The link `https://github.com/OWNER/REPO/releases/download/latest/app.apk` then always serves the newest build.

## Where to keep the key

Ideal: a GitHub Actions secret (base64 keystore + password). If secrets cannot be set from where you work, committing a dedicated sideload key works for personal use, but anyone with the repo can sign with it. Replace it, and keep the replacement private, before any store release or wider sharing.

## Managed work profiles can block everything

If the phone has a **work profile** from a company device-management (MDM) policy, the admin can block unknown sources for the **whole device**, including the personal profile (Android restriction `DISALLOW_INSTALL_UNKNOWN_SOURCES_GLOBALLY`). Signing cannot get around this. Options:

| Option | Cost | Notes |
| --- | --- | --- |
| Progressive web app (Add to home screen) | Free | Not an APK install, so the policy does not apply. Data lives in browser storage |
| Google Play internal testing | $25 once + identity verification | Up to 100 testers, installs and updates from the Play Store |
| Ask the admin | — | Usually refused on managed devices |

## Developer verification (2026–2027)

Google is rolling out mandatory developer registration for apps installed on certified Android devices: from 30 September 2026 in Brazil, Indonesia, Singapore and Thailand, globally in 2027. Unregistered apps will need an "advanced" sideloading flow with a 24-hour wait, or ADB. A free limited-distribution account (up to 20 devices, no ID or fee) is planned for hobby use. Registration ties the app to a signing key, so that key must be private. Source: [Android Authority timeline](https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/).
