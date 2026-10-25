---
title: Using GitHub Actions as a remote Flutter build machine
tags: [flutter, github-actions, ci, remote-development, android]
created: 2026-10-25
source: Climbing Journal project
summary: How to develop and verify a Flutter app when the machine writing the code has no Flutter SDK, by letting GitHub Actions generate, analyze, test and build it.
---

# Using GitHub Actions as a remote Flutter build machine

## Situation

The code was written in a cloud workspace whose network only reaches package registries and GitHub. The Flutter SDK download host (`storage.googleapis.com`) and `pub.dev` were blocked, so nothing could be compiled locally. GitHub Actions has full internet access and a Flutter action, so it became the compiler, test runner and build server.

## Pattern

1. **Write Dart code by hand**, keeping it plain and well-known API so it is likely to compile first time.
2. **Generate what only the SDK can make** (platform folders, `pubspec.lock`) with a one-off `workflow_dispatch` workflow that runs `flutter create` and `flutter pub add`, then pushes the result to a side branch. Merge the files from that branch into `main`.
3. **Add packages the same way**: a reusable "Add dependencies" workflow with a `packages` input runs `flutter pub add $PACKAGES` and pushes `pubspec.yaml` + `pubspec.lock` to a `deps` branch. This gives correct, current version constraints without access to pub.dev.
4. **Every push runs** `flutter analyze`, `flutter test`, `flutter build apk` and `flutter build web`.

## Reading failures when logs are unreachable

Job logs and artifacts are served from Azure blob storage, which was also blocked. The fix: on failure, a step prints the important part of the log as a GitHub **annotation** (`::error title=...::message`). Annotations come back through the normal REST API:

```
gh api repos/OWNER/REPO/check-runs/JOB_ID/annotations
```

Escape newlines as `%0A` and `%` as `%25`. Filter test output to the blocks around `EXCEPTION CAUGHT` and `[E]` so the message stays under the size limit.

## Reading package APIs without pub.dev

Most Flutter packages live on GitHub. A sparse, shallow clone of the package repo at the exact version tag shows the real API:

```
git clone --depth 1 --branch share_plus-v13.3.1 --filter=blob:none --sparse https://github.com/fluttercommunity/plus_plugins.git
git sparse-checkout set packages/share_plus/share_plus/lib
```

This mattered: `file_picker` 13 replaced `FilePicker.platform.pickFiles()` with static `FilePicker.pickFile()` returning a `PlatformFile` with `readAsBytes()`.

## Lessons

- Widget tests catch layout overflow at phone width (390 px): a `Row` with two texts and `spaceBetween` overflowed by 32 px. Use `Expanded` with ellipsis.
- `gh workflow run` needs GraphQL; where only REST is allowed, dispatch with `gh api -X POST repos/O/R/actions/workflows/FILE/dispatches -f ref=main`.
- Keep the workflow's `concurrency` group per branch with `cancel-in-progress` so fast pushes don't queue.
