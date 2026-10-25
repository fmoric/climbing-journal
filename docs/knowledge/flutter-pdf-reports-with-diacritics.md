---
title: Generating PDF reports in Flutter with Croatian characters
tags: [flutter, pdf, fonts, unicode, croatian, printing]
created: 2026-10-25
source: Climbing Journal project
summary: Build PDFs on the device with the pdf and printing packages, and bundle a TTF font so č, ć, š, ž and đ render offline.
---

# Generating PDF reports in Flutter with Croatian characters

## Packages

- `pdf` builds the document with widgets similar to Flutter's (`pw.MultiPage`, `pw.Table`, `pw.Row`).
- `printing` shares it: `Printing.sharePdf(bytes: ..., filename: ...)` opens the share sheet on phones and downloads in a browser.

## The font problem

The PDF standard fonts (Helvetica) have **no Unicode support**: letters like č, ć, š, ž, đ are missing and the `pdf` package logs "Helvetica has no Unicode support". Fetching a Google font at runtime (`PdfGoogleFonts.notoSansRegular()`) fails offline.

## Fix: bundle a TTF

1. Add an OFL-licensed font with Latin Extended coverage (Liberation Sans, Noto Sans) under `assets/fonts/`, with its license file.
2. Register it in `pubspec.yaml` under `flutter: assets:`.
3. Load it once and reuse it:
   ```dart
   final base = pw.Font.ttf(await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
   final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
   final theme = pw.ThemeData.withFont(base: base, bold: bold);
   ```
4. Tests that build a PDF need `TestWidgetsFlutterBinding.ensureInitialized()` so `rootBundle` works.

Check coverage before choosing a font: `fc-list ':charset=10d 107 161 17e 111' file`.

## Report layout that worked

A4, title and generation date, three total boxes (ascents, sends, climbing days), a 12-month bar chart drawn with plain containers, one grade pyramid per discipline, then a full table with alternating row shading and a footer with page numbers.
