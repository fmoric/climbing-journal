---
title: Publishing a Flutter web build to GitHub Pages from Actions
tags: [github-pages, flutter-web, github-actions, deployment]
created: 2026-10-25
source: Climbing Journal project
summary: Deploy a Flutter web build to GitHub Pages by force-pushing it to a gh-pages branch, and the one manual setting this needs.
---

# Publishing a Flutter web build to GitHub Pages from Actions

## Build for a project page

A project page is served under `/REPO/`, so the base href must match:

```
flutter build web --release --base-href /climbing-journal/
```

## Push the build to `gh-pages`

```
cd build/web
touch .nojekyll
git init -q -b gh-pages
git add -A && git commit -q -m "Web build"
git push -q --force "https://x-access-token:${{ github.token }}@github.com/${{ github.repository }}.git" gh-pages
```

The workflow needs `permissions: contents: write`. `.nojekyll` stops Jekyll from dropping folders that start with `_`.

## The manual step

Pages must be switched on once in **Settings → Pages → Build and deployment**: Source "Deploy from a branch", branch `gh-pages`, folder `/ (root)`. The Pages REST endpoints may not be callable from restricted environments, so this is a phone-friendly task for the repo owner. After that, GitHub runs a "pages build and deployment" workflow on every push to the branch; its green tick in the Actions tab is the status.

## Why a branch rather than the Pages artifact actions

`actions/deploy-pages` requires Pages to be configured for "GitHub Actions" as the source first, which needs the same settings access. A branch push works with only `contents: write` and can be switched on afterwards.

## Notes

- Private repositories need a paid plan for Pages.
- A demo build can be separated from the real app with a compile-time flag: `--dart-define=DEMO=true` read via `bool.fromEnvironment('DEMO')`.
