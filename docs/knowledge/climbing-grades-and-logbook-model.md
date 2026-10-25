---
title: Climbing grades and a logbook data model
tags: [climbing, grades, data-model, domain]
created: 2026-10-25
source: Climbing Journal project
summary: How grade systems relate, why grades should be stored as entered, what counts as a send, and the crag–sector–route–ascent model.
---

# Climbing grades and a logbook data model

## Grade systems come in two families

- **Routes:** French (6a, 6a+), UIAA (VI+, VII-), YDS (5.10b).
- **Boulders:** Font (6A, 7B+), V scale (V3, V8).

Conversions are only meaningful within a family, and every published chart is approximate. Font has more steps than V, so several Font grades map to one V grade (6A and 6A+ are both V3).

## Store grades as entered

Keep the grade text and its system exactly as the climber entered them. Convert only for display and statistics, using a ranked table per family where each row is one step. This keeps the original fidelity and makes sorting and pyramids easy: rank = row index.

## What counts as a send

Onsight, flash and redpoint are sends. Top-rope, attempts and project burns are logged but not counted in pyramids or "hardest send".

## Model

| Entity | Key fields |
| --- | --- |
| Crag | name, type (outdoor / gym), GPS location |
| Sector | crag, name (optional for small crags and gyms) |
| Route | crag, sector, name, discipline, grade + system, pitches, photos |
| Ascent | route, user, date, style, attempts, notes, visibility |

- Multi-pitch is a route with `pitches > 1`, not a separate discipline.
- A gym is a crag with `type = gym`; gym routes carry set and retired dates.
- Ascents copy the crag ID so history can filter by crag without a lookup.
- IDs are generated on the device (UUID v4) so records can be created offline.

## Duplicate routes

When adding a route, compare the typed name with existing routes after folding case, spaces and diacritics (č→c, đ→d), allowing a Levenshtein distance of 1 (2 for long names). Show matches in the same sector first and let the user pick one instead of creating a duplicate.

## Nearest crag

Haversine distance from the phone to each crag with a saved location; propose the nearest within 1.5 km, otherwise fall back to the list. Save a crag's location when it is created on site, or later with "save my current location".
