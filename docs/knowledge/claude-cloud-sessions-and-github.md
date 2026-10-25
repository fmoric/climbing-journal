---
title: Connecting GitHub to Claude cloud sessions
tags: [claude, claude-code, github, cloud-session, troubleshooting]
created: 2026-10-25
source: Climbing Journal project
summary: Why a Claude cloud session may not push to GitHub even with the Claude GitHub App installed, and how the connection is actually made.
---

# Connecting GitHub to Claude cloud sessions

## Two separate pieces

1. **The Claude GitHub App** (github.com/apps/claude), installed on your GitHub account with access to the repository. This is the repository side.
2. **Your claude.ai account linked to GitHub.** This is made at **claude.ai/code**, which prompts "connect GitHub" on first use. It is not in the regular Connectors list.

A session can push only when both exist. With only the App installed, attempts fail with "No linked GitHub account" or "link your GitHub account". A running session may only pick up a new link after a new session starts. On Team and Enterprise plans an owner must first enable the GitHub connector for the organization. Source: [Get started with Claude Code in the cloud](https://code.claude.com/docs/en/web-quickstart).

## Symptoms seen

- The connect page opened and returned immediately without linking.
- Making the repo public allowed reading but not pushing; the session's git proxy injects credentials only for repositories attached to the session.

## Workarounds

- **Git bundle:** `git bundle create repo.bundle main` packs the whole history into one file. On any computer: `git clone repo.bundle repo`, set the remote URL, `git push -u origin main`.
- Once linked, the session attaches the repo with push access and can also run GitHub Actions through the REST API.

## Restrictions to expect inside the session

- GraphQL is blocked: use `gh api` REST calls (e.g. workflow dispatch via `POST .../actions/workflows/FILE/dispatches`).
- Pages settings, Actions secrets, job logs and artifact downloads may be blocked; plan for the repo owner to do those steps, and surface CI errors as annotations.
