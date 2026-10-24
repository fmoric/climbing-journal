import '../models/enums.dart';

/// Grade systems and display-only conversion (M1-03).
///
/// Grades are stored exactly as entered. These tables only rank grades
/// (for sorting and the pyramid) and convert them for display. Conversions
/// are approximate, as in any published chart.
///
/// Two families: route grades (French, UIAA, YDS) and boulder grades
/// (Font, V scale). Conversion never crosses families.
class Grades {
  Grades._();

  /// Route grades, one row per step: French, UIAA, YDS.
  static const List<List<String>> _routeRows = [
    ['3', 'III', '5.3'],
    ['4a', 'IV', '5.4'],
    ['4b', 'IV+', '5.5'],
    ['4c', 'V', '5.6'],
    ['5a', 'V+', '5.7'],
    ['5b', 'VI-', '5.8'],
    ['5c', 'VI', '5.9'],
    ['6a', 'VI+', '5.10a'],
    ['6a+', 'VII-', '5.10b'],
    ['6b', 'VII', '5.10c'],
    ['6b+', 'VII+', '5.10d'],
    ['6c', 'VIII-', '5.11a'],
    ['6c+', 'VIII', '5.11b'],
    ['7a', 'VIII+', '5.11d'],
    ['7a+', 'IX-', '5.12a'],
    ['7b', 'IX', '5.12b'],
    ['7b+', 'IX+', '5.12c'],
    ['7c', 'X-', '5.12d'],
    ['7c+', 'X', '5.13a'],
    ['8a', 'X+', '5.13b'],
    ['8a+', 'XI-', '5.13c'],
    ['8b', 'XI', '5.13d'],
    ['8b+', 'XI+', '5.14a'],
    ['8c', 'XII-', '5.14b'],
    ['8c+', 'XII', '5.14c'],
    ['9a', 'XII+', '5.14d'],
    ['9a+', 'XIII-', '5.15a'],
    ['9b', 'XIII', '5.15b'],
    ['9b+', 'XIII+', '5.15c'],
    ['9c', 'XIV-', '5.15d'],
  ];

  /// Boulder grades, one row per step: Font, V scale.
  static const List<List<String>> _boulderRows = [
    ['4', 'V0'],
    ['5', 'V1'],
    ['5+', 'V2'],
    ['6A', 'V3'],
    ['6A+', 'V3'],
    ['6B', 'V4'],
    ['6B+', 'V4'],
    ['6C', 'V5'],
    ['6C+', 'V5'],
    ['7A', 'V6'],
    ['7A+', 'V7'],
    ['7B', 'V8'],
    ['7B+', 'V8'],
    ['7C', 'V9'],
    ['7C+', 'V10'],
    ['8A', 'V11'],
    ['8A+', 'V12'],
    ['8B', 'V13'],
    ['8B+', 'V14'],
    ['8C', 'V15'],
    ['8C+', 'V16'],
    ['9A', 'V17'],
  ];

  static bool isBoulderSystem(GradeSystem s) =>
      s == GradeSystem.font || s == GradeSystem.vScale;

  static List<List<String>> _rows(GradeSystem s) =>
      isBoulderSystem(s) ? _boulderRows : _routeRows;

  static int _column(GradeSystem s) {
    switch (s) {
      case GradeSystem.french:
        return 0;
      case GradeSystem.uiaa:
        return 1;
      case GradeSystem.yds:
        return 2;
      case GradeSystem.font:
        return 0;
      case GradeSystem.vScale:
        return 1;
    }
  }

  static String _norm(String g) => g.trim().toLowerCase().replaceAll(' ', '');

  /// The grades of a system in ascending order, as they should be offered
  /// in a picker. Duplicates (e.g. V3 for 6A and 6A+) appear once.
  static List<String> scale(GradeSystem s) {
    final col = _column(s);
    final out = <String>[];
    for (final row in _rows(s)) {
      if (out.isEmpty || out.last != row[col]) out.add(row[col]);
    }
    return out;
  }

  /// Position of a grade in its family, lowest = 0. Null if unknown.
  /// Grades from different systems of the same family share one scale,
  /// so 6a (French) and VI+ (UIAA) get the same rank.
  static int? rank(String grade, GradeSystem s) {
    final col = _column(s);
    final g = _norm(grade);
    final rows = _rows(s);
    for (var i = 0; i < rows.length; i++) {
      if (_norm(rows[i][col]) == g) return i;
    }
    return null;
  }

  /// Converts a grade for display. Null when the grade is unknown or the
  /// systems belong to different families.
  static String? convert(String grade, GradeSystem from, GradeSystem to) {
    if (isBoulderSystem(from) != isBoulderSystem(to)) return null;
    final r = rank(grade, from);
    if (r == null) return null;
    return _rows(to)[r][_column(to)];
  }

  /// Orders grades from easiest to hardest; unknown grades sort first.
  static int compare(String a, GradeSystem sa, String b, GradeSystem sb) =>
      (rank(a, sa) ?? -1).compareTo(rank(b, sb) ?? -1);

  /// The usual system for a discipline, used as a form default.
  static GradeSystem defaultFor(Discipline d) =>
      d == Discipline.boulder ? GradeSystem.font : GradeSystem.french;

  static String systemLabel(GradeSystem s) {
    switch (s) {
      case GradeSystem.french:
        return 'French';
      case GradeSystem.uiaa:
        return 'UIAA';
      case GradeSystem.yds:
        return 'YDS';
      case GradeSystem.font:
        return 'Font';
      case GradeSystem.vScale:
        return 'V scale';
    }
  }
}
