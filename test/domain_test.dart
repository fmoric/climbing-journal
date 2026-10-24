import 'package:climbing_journal/data/demo_journal_repository.dart';
import 'package:climbing_journal/domain/geo.dart';
import 'package:climbing_journal/domain/grades.dart';
import 'package:climbing_journal/domain/similarity.dart';
import 'package:climbing_journal/domain/stats.dart';
import 'package:climbing_journal/models/climb_route.dart';
import 'package:climbing_journal/models/crag.dart';
import 'package:climbing_journal/models/enums.dart';
import 'package:climbing_journal/report/yearly_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter_test/flutter_test.dart';

ClimbRoute _route(String id, String name,
        {String grade = '6a', String? sector}) =>
    ClimbRoute(
      id: id,
      cragId: 'c',
      sectorId: sector,
      name: name,
      discipline: Discipline.sport,
      grade: grade,
      gradeSystem: GradeSystem.french,
    );

void main() {
  group('Grades', () {
    test('route systems share one scale', () {
      final fr = Grades.rank('6a', GradeSystem.french);
      expect(fr, isNotNull);
      expect(Grades.rank('VI+', GradeSystem.uiaa), fr);
      expect(Grades.rank('5.10a', GradeSystem.yds), fr);
    });

    test('converts within a family only', () {
      expect(Grades.convert('7a', GradeSystem.french, GradeSystem.yds),
          '5.11d');
      expect(Grades.convert('6A', GradeSystem.font, GradeSystem.vScale), 'V3');
      expect(
          Grades.convert('6a', GradeSystem.french, GradeSystem.font), isNull);
      expect(Grades.convert('nonsense', GradeSystem.french, GradeSystem.uiaa),
          isNull);
    });

    test('ignores case and spaces', () {
      expect(Grades.rank('6A+', GradeSystem.french),
          Grades.rank(' 6a+ ', GradeSystem.french));
    });

    test('orders grades', () {
      expect(
          Grades.compare(
              '6b', GradeSystem.french, '6a+', GradeSystem.french),
          greaterThan(0));
      expect(
          Grades.compare('VII', GradeSystem.uiaa, '6b', GradeSystem.french),
          0);
    });

    test('scales have no repeated entries', () {
      for (final s in GradeSystem.values) {
        final scale = Grades.scale(s);
        expect(scale.toSet().length, scale.length, reason: s.name);
      }
    });
  });

  group('Geo', () {
    test('one degree of latitude is about 111 km', () {
      expect(distanceMetres(45, 14, 46, 14), closeTo(111195, 300));
    });

    test('picks the nearest crag within range', () {
      const crags = [
        Crag(id: 'far', name: 'Far', location: GeoPoint(45.0100, 14.0)),
        Crag(id: 'near', name: 'Near', location: GeoPoint(45.0010, 14.0)),
        Crag(id: 'gym', name: 'Gym', type: CragType.gym),
      ];
      final m = nearestCrag(crags, 45.0, 14.0);
      expect(m?.crag.id, 'near');
      expect(m!.distance, closeTo(111, 5));
      expect(nearestCrag(crags, 46.0, 14.0), isNull);
    });

    test('formats distances', () {
      expect(formatDistance(120.4), '120 m');
      expect(formatDistance(1460), '1.5 km');
    });
  });

  group('Duplicate suggestion', () {
    final routes = [
      _route('1', 'Dry Spell'),
      _route('2', 'Quiet Crack'),
      _route('3', 'Šuma'),
    ];

    test('matches typos, case and diacritics', () {
      expect(similarRoutes('dry spel', routes).map((r) => r.id), ['1']);
      expect(similarRoutes('Suma', routes).map((r) => r.id), ['3']);
    });

    test('does not match unrelated names', () {
      expect(similarRoutes('Long Lunch', routes), isEmpty);
      expect(similarRoutes('ab', routes), isEmpty);
    });
  });

  group('Year summary', () {
    late DemoJournalRepository repo;
    setUp(() => repo = DemoJournalRepository.seeded(now: DateTime(2026, 12, 31)));

    test('counts the demo year', () async {
      final ascents = await repo.watchMyAscents().first;
      final routes = {
        for (final r in await repo.watchAllRoutes().first) r.id: r,
      };
      final s = summarizeYear(2026, ascents, routes);
      expect(s.ascents.length, 20);
      expect(s.sends, 13);
      expect(s.days, 15);
      expect(s.perMonth, [2, 1, 3, 3, 3, 2, 1, 0, 2, 3, 0, 0]);
      expect(s.hardest[Discipline.sport]?.grade, '6c');
      expect(s.hardest[Discipline.boulder]?.grade, '6B+');
      expect(s.pyramids[Discipline.sport]!.first.grade, '6c');
      final sixA = s.pyramids[Discipline.sport]!
          .firstWhere((r) => r.grade == '6a');
      expect(sixA.count, 3);
    });

    test('builds a PDF report', () async {
      final ascents = await repo.watchMyAscents().first;
      final routes = {
        for (final r in await repo.watchAllRoutes().first) r.id: r,
      };
      final crags = {for (final c in await repo.watchCrags().first) c.id: c};
      final bytes = await buildYearlyReport(
        summary: summarizeYear(2026, ascents, routes),
        routes: routes,
        crags: crags,
        climber: 'Test climber',
        generatedAt: DateTime(2026, 12, 31),
        useWebFonts: false,
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(2000));
    });

    test('empty year still builds', () async {
      final bytes = await buildYearlyReport(
        summary: summarizeYear(1999, const [], const {}),
        routes: const {},
        crags: const {},
        climber: 'Test climber',
        useWebFonts: false,
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('Demo repository', () {
    test('streams update after a write', () async {
      final repo = DemoJournalRepository.seeded(now: DateTime(2026, 12, 31));
      final stream = repo.watchMyAscents();
      final first = await stream.first;
      repo.deleteAscent(first.first.id);
      final after = await repo.watchMyAscents().first;
      expect(after.length, first.length - 1);
    });
  });
}
