import 'dart:typed_data';

import 'package:climbing_journal/data/local_journal_repository.dart';
import 'package:climbing_journal/data/photo_store.dart';
import 'package:climbing_journal/models/ascent.dart';
import 'package:climbing_journal/models/climb_route.dart';
import 'package:climbing_journal/models/crag.dart';
import 'package:climbing_journal/models/enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<LocalJournalRepository> _open(String name) async =>
    LocalJournalRepository(
        await newDatabaseFactoryMemory().openDatabase(name));

/// Writes are fire-and-forget; give them a moment to land.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> _seed(LocalJournalRepository repo) async {
  repo.createCrag(const Crag(
      id: 'c1', name: 'Kamenjak', location: GeoPoint(45.35, 14.55)));
  repo.createRoute(const ClimbRoute(
    id: 'r1',
    cragId: 'c1',
    name: 'Žuta ploča',
    discipline: Discipline.sport,
    grade: '6a+',
    gradeSystem: GradeSystem.french,
  ));
  repo.createAscent(Ascent(
    id: 'a1',
    userId: repo.uid,
    routeId: 'r1',
    cragId: 'c1',
    date: DateTime(2026, 5, 1),
    style: AscentStyle.redpoint,
    attempts: 3,
    notes: 'Šuma',
  ));
  repo.createAscent(Ascent(
    id: 'a2',
    userId: repo.uid,
    routeId: 'r1',
    cragId: 'c1',
    date: DateTime(2026, 6, 1),
    style: AscentStyle.onsight,
  ));
  await _settle();
}

void main() {
  test('stores and reads back crags, routes and ascents', () async {
    final repo = await _open('a.db');
    await _seed(repo);

    final crags = await repo.watchCrags().first;
    expect(crags.single.name, 'Kamenjak');
    expect(crags.single.location!.latitude, 45.35);

    final routes = await repo.watchRoutes('c1').first;
    expect(routes.single.name, 'Žuta ploča');
    expect(routes.single.grade, '6a+');

    final ascents = await repo.watchMyAscents().first;
    expect(ascents.map((a) => a.id), ['a2', 'a1'], reason: 'newest first');
    expect(ascents.last.date, DateTime(2026, 5, 1));
    expect(ascents.last.notes, 'Šuma');
  });

  test('delete removes an ascent', () async {
    final repo = await _open('b.db');
    await _seed(repo);
    repo.deleteAscent('a1');
    await _settle();
    expect((await repo.watchMyAscents().first).map((a) => a.id), ['a2']);
  });

  test('streams update after a write', () async {
    final repo = await _open('c.db');
    final seen = <int>[];
    final sub = repo.watchCrags().listen((c) => seen.add(c.length));
    await _settle();
    repo.createCrag(const Crag(id: 'x', name: 'New'));
    await _settle();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  test('backup round-trips into another logbook', () async {
    final source = await _open('d.db');
    await _seed(source);
    await source.setClimberName('Filip');
    final json = await source.exportBackup(now: DateTime.utc(2026, 10, 25));

    final info = LocalJournalRepository.inspectBackup(json);
    expect(info.ascents, 2);
    expect(info.routes, 1);
    expect(info.crags, 1);

    final target = await _open('e.db');
    target.createCrag(const Crag(id: 'old', name: 'Replaced'));
    await _settle();
    await target.importBackup(json);

    final crags = await target.watchCrags().first;
    expect(crags.map((c) => c.id), ['c1']);
    expect(crags.single.location!.longitude, 14.55);
    final ascents = await target.watchMyAscents().first;
    expect(ascents.length, 2);
    expect(ascents.last.date, DateTime(2026, 5, 1));
    expect(await target.climberName(), 'Filip');
  });

  test('rejects files that are not a backup', () {
    expect(() => LocalJournalRepository.inspectBackup('not json'),
        throwsFormatException);
    expect(() => LocalJournalRepository.inspectBackup('{"a": 1}'),
        throwsFormatException);
    expect(
        () => LocalJournalRepository.inspectBackup(
            '{"format": "climbing-journal-backup", "version": 99}'),
        throwsFormatException);
  });

  test('climber name is stored', () async {
    final repo = await _open('f.db');
    expect(await repo.climberName(), isNull);
    await repo.setClimberName('  Filip  ');
    expect(await repo.climberName(), 'Filip');
  });

  test('route photo IDs are stored with the route', () async {
    final repo = await _open('g.db');
    await _seed(repo);
    final route = (await repo.watchRoutes('c1').first).single;
    expect(route.photoIds, isEmpty);
    repo.updateRoute(route.copyWith(photoIds: ['p1.jpg', 'p2.jpg']));
    await _settle();
    final back = (await repo.watchRoutes('c1').first).single;
    expect(back.photoIds, ['p1.jpg', 'p2.jpg']);
    expect(back.name, 'Žuta ploča');
  });

  test('memory photo store saves, loads and deletes', () async {
    final store = MemoryPhotoStore();
    final id = await store.save(Uint8List.fromList([1, 2, 3]));
    expect(id, endsWith('.jpg'));
    expect(await store.load(id), [1, 2, 3]);
    await store.delete(id);
    expect(await store.load(id), isNull);
  });
}
