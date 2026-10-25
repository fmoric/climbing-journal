---
title: Making a Flutter web app installable and offline (2026)
tags: [flutter-web, pwa, service-worker, offline, indexeddb, mdm]
created: 2026-10-25
source: Climbing Journal project
summary: Flutter's generated service worker no longer caches anything; how to add your own, bundle CanvasKit, keep data in IndexedDB, and why a PWA gets around managed-phone install blocks.
---

# Making a Flutter web app installable and offline (2026)

## Why a web app

A phone with a company work profile blocked APK installs on the whole device. A progressive web app is opened in Chrome and added to the home screen, which is not an app install, so the policy does not apply. It runs full screen like an app.

## Flutter no longer gives you offline support

In Flutter 3.47 the generated `flutter_service_worker.js` only **unregisters itself** and reloads the page. `--pwa-strategy` is hidden and deprecated; `--pwa-strategy=none` emits an empty worker. For offline use, write your own service worker.

## Build

```
flutter build web --release --pwa-strategy=none --no-web-resources-cdn \
  --base-href /climbing-journal/app/ --output build/web-app
```

`--no-web-resources-cdn` bundles CanvasKit instead of loading it from Google's CDN, which would fail offline.

## Service worker that works on the first visit

The first page load happens before the worker controls the page, so runtime caching alone leaves the rendering engine uncached; the first offline open is then a blank page. Fix:

1. At build time, list every file in the build (skip `*.symbols`, `skwasm*` for a JS build) and write the list into the worker, with a cache name derived from a hash of the files.
2. On `install`, `cache.add` each file (`Promise.allSettled`, so one failure does not abort the rest), then `skipWaiting()`.
3. On `activate`, delete other caches and `clients.claim()`.
4. On `fetch`, stale-while-revalidate: answer from cache, refresh in the background; for navigations with no network, fall back to the cached `./`.

Register it from a small script injected into `index.html`, and call `navigator.storage.persist()` to ask Chrome not to evict the app's storage.

Verified with Playwright: load online, wait for `navigator.serviceWorker.ready`, `context.setOffline(true)`, reload, screenshot.

## Data in the browser

- Records: sembast with `sembast_web` (IndexedDB).
- Photos: a separate sembast database storing `Blob(bytes)` values (`package:sembast/blob.dart`).
- Clearing the browser's site data deletes everything, so a backup export matters even more than on native.

## What works on the web build

GPS (`geolocator`, needs HTTPS), camera and gallery (`image_picker`), keep screen on (`wakelock_plus`), share or download files (`share_plus`, `printing`), file import (`file_picker`).

## A blank page means an uncaught build error

In a release web build, an exception thrown while building a widget gives no red error screen: the page simply goes blank. The first one seen here: a helper returned `const []` (read-only) for short input, and the screen called `.sort()` on it, so the page went blank after the first typed letter. Lessons: never return `const` lists from functions whose callers may mutate the result, and make widget tests type text **letter by letter**, checking `tester.takeException()` after each step.

## Testing on canvas-rendered UIs

Flutter draws to a canvas, so tests click coordinates: take a screenshot at a fixed viewport (390×844), read the target position, divide by the device scale factor, then `page.mouse.click(x, y)`. Grant geolocation in the browser context to test GPS paths.
