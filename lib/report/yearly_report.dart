import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/stats.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/enums.dart';

/// Yearly ascent report (FR-9), built on the device.
///
/// Uses the bundled Liberation Sans (SIL OFL), so names with č, ć, š, ž
/// and đ render correctly, offline too.
Future<Uint8List> buildYearlyReport({
  required YearSummary summary,
  required Map<String, ClimbRoute> routes,
  required Map<String, Crag> crags,
  required String climber,
  DateTime? generatedAt,
}) async {
  final theme = await _theme();
  final made = generatedAt ?? DateTime.now();
  final doc = pw.Document(
    title: 'Climbing report ${summary.year}',
    author: climber,
    creator: 'Climbing Journal',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$climber · Climbing report ${summary.year}',
              style: const pw.TextStyle(fontSize: 8, color: _quiet)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _quiet)),
        ],
      ),
      build: (ctx) => [
        _header(summary.year, climber, made),
        pw.SizedBox(height: 18),
        _totals(summary),
        pw.SizedBox(height: 22),
        _sectionTitle('Ascents per month'),
        pw.SizedBox(height: 8),
        _monthChart(summary.perMonth),
        pw.SizedBox(height: 22),
        if (summary.pyramids.isNotEmpty) ...[
          _sectionTitle('Grade pyramids (sends)'),
          pw.SizedBox(height: 8),
          for (final e in summary.pyramids.entries)
            _pyramid(e.key, e.value),
          pw.SizedBox(height: 12),
        ],
        _sectionTitle('All ascents'),
        pw.SizedBox(height: 8),
        _ascentTable(summary, routes, crags),
      ],
    ),
  );
  return doc.save();
}

const _ink = PdfColor.fromInt(0xFF1C1F1D);
const _quiet = PdfColor.fromInt(0xFF5B605D);
const _accent = PdfColor.fromInt(0xFF0F6E6A);
const _ground = PdfColor.fromInt(0xFFF4F2EE);
const _line = PdfColor.fromInt(0xFFD5D0C6);

pw.ThemeData? _cachedTheme;

Future<pw.ThemeData> _theme() async {
  final cached = _cachedTheme;
  if (cached != null) return cached;
  final base = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
  final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
  return _cachedTheme = pw.ThemeData.withFont(base: base, bold: bold);
}

pw.Widget _header(int year, String climber, DateTime made) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Climbing report $year',
          style: pw.TextStyle(
              fontSize: 26, fontWeight: pw.FontWeight.bold, color: _ink)),
      pw.SizedBox(height: 4),
      pw.Text('$climber · generated ${formatDate(made)}',
          style: const pw.TextStyle(fontSize: 11, color: _quiet)),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: _accent),
    ],
  );
}

pw.Widget _sectionTitle(String text) => pw.Text(text,
    style: pw.TextStyle(
        fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink));

pw.Widget _totals(YearSummary s) {
  pw.Widget box(String value, String label) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: _ground,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: _quiet)),
            ],
          ),
        ),
      );

  final hardest = [
    for (final e in s.hardest.entries)
      '${disciplineLabel(e.key)}: ${e.value.grade} (${e.value.name})',
  ];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(children: [
        box('${s.ascents.length}', 'Ascents logged'),
        pw.SizedBox(width: 8),
        box('${s.sends}', 'Sends (onsight, flash, redpoint)'),
        pw.SizedBox(width: 8),
        box('${s.days}', 'Climbing days'),
      ]),
      if (hardest.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text('Hardest sends',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        for (final h in hardest)
          pw.Text(h, style: const pw.TextStyle(fontSize: 10)),
      ],
    ],
  );
}

pw.Widget _monthChart(List<int> perMonth) {
  const maxH = 90.0;
  final max = perMonth.fold<int>(0, (m, v) => v > m ? v : m);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 12; i++)
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(perMonth[i] == 0 ? '' : '${perMonth[i]}',
                    style: const pw.TextStyle(fontSize: 8, color: _ink)),
                pw.SizedBox(height: 2),
                pw.Container(
                  height: max == 0 ? 0 : maxH * perMonth[i] / max,
                  color: _accent,
                ),
                pw.Container(height: 0.5, color: _line),
                pw.SizedBox(height: 3),
                pw.Text(monthShort[i],
                    style: const pw.TextStyle(fontSize: 8, color: _quiet)),
              ],
            ),
          ),
        ),
    ],
  );
}

pw.Widget _pyramid(Discipline d, List<PyramidRow> rows) {
  const maxW = 260.0;
  final max = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(disciplineLabel(d),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        for (final r in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 36,
                  child: pw.Text(r.grade,
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  width: maxW * r.count / max,
                  height: 10,
                  color: _accent,
                ),
                pw.SizedBox(width: 6),
                pw.Text('${r.count}',
                    style: const pw.TextStyle(fontSize: 9, color: _quiet)),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _ascentTable(
  YearSummary s,
  Map<String, ClimbRoute> routes,
  Map<String, Crag> crags,
) {
  if (s.ascents.isEmpty) {
    return pw.Text('No ascents logged in ${s.year}.',
        style: const pw.TextStyle(fontSize: 10, color: _quiet));
  }
  final data = <List<String>>[
    for (final a in s.ascents)
      [
        formatDate(a.date),
        crags[a.cragId]?.name ?? '',
        routes[a.routeId]?.name ?? '(deleted route)',
        routes[a.routeId] == null
            ? ''
            : disciplineLabel(routes[a.routeId]!.discipline),
        routes[a.routeId]?.grade ?? '',
        styleLabel(a.style),
        '${a.attempts}',
      ],
  ];
  return pw.TableHelper.fromTextArray(
    headers: const [
      'Date', 'Crag', 'Route', 'Discipline', 'Grade', 'Style', 'Tries',
    ],
    data: data,
    headerStyle: pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: _ink),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellHeight: 18,
    oddRowDecoration: const pw.BoxDecoration(color: _ground),
    border: null,
    cellAlignments: const {
      0: pw.Alignment.centerLeft,
      4: pw.Alignment.center,
      6: pw.Alignment.center,
    },
  );
}

/// Opens the share sheet on phones, or downloads the file in a browser.
Future<void> shareYearlyReport(Uint8List bytes, int year) =>
    Printing.sharePdf(bytes: bytes, filename: 'climbing-report-$year.pdf');
