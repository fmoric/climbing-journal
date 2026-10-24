import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/enums.dart';
import 'grades.dart';

/// Onsight, flash and redpoint count as sends. Top-rope, attempts and
/// project burns do not.
bool isSend(AscentStyle s) =>
    s == AscentStyle.onsight ||
    s == AscentStyle.flash ||
    s == AscentStyle.redpoint;

String styleLabel(AscentStyle s) {
  switch (s) {
    case AscentStyle.onsight:
      return 'Onsight';
    case AscentStyle.flash:
      return 'Flash';
    case AscentStyle.redpoint:
      return 'Redpoint';
    case AscentStyle.topRope:
      return 'Top-rope';
    case AscentStyle.attempt:
      return 'Attempt';
    case AscentStyle.project:
      return 'Project';
  }
}

String disciplineLabel(Discipline d) {
  switch (d) {
    case Discipline.sport:
      return 'Sport';
    case Discipline.boulder:
      return 'Boulder';
    case Discipline.trad:
      return 'Trad';
    case Discipline.gym:
      return 'Gym';
  }
}

/// One bar of a grade pyramid.
class PyramidRow {
  const PyramidRow(this.grade, this.system, this.count);
  final String grade;
  final GradeSystem system;
  final int count;
}

/// Sends per grade for one discipline, hardest first. Grades are grouped
/// as entered (same text and system).
List<PyramidRow> pyramid(
  Iterable<Ascent> ascents,
  Map<String, ClimbRoute> routes,
  Discipline discipline,
) {
  final counts = <String, PyramidRow>{};
  for (final a in ascents) {
    if (!isSend(a.style)) continue;
    final r = routes[a.routeId];
    if (r == null || r.discipline != discipline) continue;
    final key = '${r.gradeSystem.name}|${r.grade}';
    final prev = counts[key];
    counts[key] = PyramidRow(r.grade, r.gradeSystem, (prev?.count ?? 0) + 1);
  }
  final rows = counts.values.toList()
    ..sort((a, b) => Grades.compare(b.grade, b.system, a.grade, a.system));
  return rows;
}

/// Everything the yearly report shows.
class YearSummary {
  YearSummary({
    required this.year,
    required this.ascents,
    required this.sends,
    required this.days,
    required this.perMonth,
    required this.pyramids,
    required this.hardest,
  });

  final int year;

  /// Ascents in the year, oldest first.
  final List<Ascent> ascents;
  final int sends;
  final int days;

  /// Ascents per month, January first (12 entries).
  final List<int> perMonth;

  /// Disciplines with at least one send.
  final Map<Discipline, List<PyramidRow>> pyramids;

  /// Hardest send per discipline.
  final Map<Discipline, ClimbRoute> hardest;
}

YearSummary summarizeYear(
  int year,
  Iterable<Ascent> all,
  Map<String, ClimbRoute> routes,
) {
  final list = all.where((a) => a.date.year == year).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final perMonth = List<int>.filled(12, 0);
  final days = <String>{};
  var sends = 0;
  final hardest = <Discipline, ClimbRoute>{};
  for (final a in list) {
    perMonth[a.date.month - 1]++;
    days.add('${a.date.year}-${a.date.month}-${a.date.day}');
    if (!isSend(a.style)) continue;
    sends++;
    final r = routes[a.routeId];
    if (r == null) continue;
    final best = hardest[r.discipline];
    if (best == null ||
        Grades.compare(r.grade, r.gradeSystem, best.grade, best.gradeSystem) >
            0) {
      hardest[r.discipline] = r;
    }
  }
  final pyramids = <Discipline, List<PyramidRow>>{};
  for (final d in Discipline.values) {
    final rows = pyramid(list, routes, d);
    if (rows.isNotEmpty) pyramids[d] = rows;
  }
  return YearSummary(
    year: year,
    ascents: list,
    sends: sends,
    days: days.length,
    perMonth: perMonth,
    pyramids: pyramids,
    hardest: hardest,
  );
}

/// Years that have at least one ascent, newest first.
List<int> yearsWithAscents(Iterable<Ascent> ascents) {
  final ys = ascents.map((a) => a.date.year).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return ys;
}

const monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) => '${d.day} ${monthShort[d.month - 1]} ${d.year}';
