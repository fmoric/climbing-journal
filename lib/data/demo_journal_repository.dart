import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:uuid/uuid.dart';

import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/enums.dart';
import '../models/sector.dart';
import 'journal_repository.dart';

/// In-memory repository for the demo build. Starts with sample data;
/// changes last until the page is reloaded.
class DemoJournalRepository implements JournalRepository {
  DemoJournalRepository._();

  factory DemoJournalRepository.seeded({DateTime? now}) {
    final repo = DemoJournalRepository._();
    repo._seed(now ?? DateTime.now());
    return repo;
  }

  static const _uuid = Uuid();

  final Map<String, Crag> _crags = {};
  final Map<String, Sector> _sectors = {};
  final Map<String, ClimbRoute> _routes = {};
  final Map<String, Ascent> _ascents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  String get uid => 'demo-user';

  @override
  bool get isDemo => true;

  @override
  String newId() => _uuid.v4();

  Stream<List<T>> _watch<T>(List<T> Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  void _changed() => _changes.add(null);

  @override
  Stream<List<Crag>> watchCrags() => _watch(() =>
      _crags.values.toList()..sort((a, b) => a.name.compareTo(b.name)));

  @override
  void createCrag(Crag crag) {
    _crags[crag.id] = crag;
    _changed();
  }

  @override
  void updateCrag(Crag crag) => createCrag(crag);

  @override
  Stream<List<Sector>> watchSectors(String cragId) => _watch(() =>
      _sectors.values.where((s) => s.cragId == cragId).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  @override
  void createSector(Sector sector) {
    _sectors[sector.id] = sector;
    _changed();
  }

  @override
  void updateSector(Sector sector) => createSector(sector);

  @override
  Stream<List<ClimbRoute>> watchRoutes(String cragId) => _watch(() =>
      _routes.values.where((r) => r.cragId == cragId).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Stream<List<ClimbRoute>> watchAllRoutes() =>
      _watch(() => _routes.values.toList());

  @override
  void createRoute(ClimbRoute route) {
    _routes[route.id] = route;
    _changed();
  }

  @override
  void updateRoute(ClimbRoute route) => createRoute(route);

  @override
  Stream<List<Ascent>> watchMyAscents() => _watch(() =>
      _ascents.values.where((a) => a.userId == uid).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));

  @override
  void createAscent(Ascent ascent) {
    _ascents[ascent.id] = ascent;
    _changed();
  }

  @override
  void updateAscent(Ascent ascent) => createAscent(ascent);

  @override
  void deleteAscent(String id) {
    _ascents.remove(id);
    _changed();
  }

  // ---- Sample data ---------------------------------------------------------

  void _seed(DateTime now) {
    const north = 'demo-crag-north';
    const sea = 'demo-crag-sea';
    const gym = 'demo-gym';
    _crags[north] = const Crag(
        id: north,
        name: 'Demo Crag North',
        location: GeoPoint(45.40, 14.30));
    _crags[sea] = const Crag(
        id: sea, name: 'Demo Sea Cliff', location: GeoPoint(45.20, 14.50));
    _crags[gym] =
        const Crag(id: gym, name: 'Demo Gym', type: CragType.gym);

    void sector(String id, String cragId, String name) =>
        _sectors[id] = Sector(id: id, cragId: cragId, name: name);
    sector('s-left', north, 'Left wing');
    sector('s-main', north, 'Main wall');
    sector('s-cave', north, 'Cave');
    sector('s-slabs', sea, 'Slabs');

    void route(String id, String cragId, String? sectorId, String name,
        Discipline d, String grade, GradeSystem system,
        {int pitches = 1}) {
      _routes[id] = ClimbRoute(
        id: id,
        cragId: cragId,
        sectorId: sectorId,
        name: name,
        discipline: d,
        grade: grade,
        gradeSystem: system,
        pitches: pitches,
      );
    }

    const sport = Discipline.sport;
    const fr = GradeSystem.french;
    route('r1', north, 's-left', 'Morning Slab', sport, '5c', fr);
    route('r2', north, 's-left', 'Dry Spell', sport, '6a+', fr);
    route('r3', north, 's-left', 'Blue Dihedral', sport, '6b', fr);
    route('r4', north, 's-left', 'Short Fuse', sport, '6c', fr);
    route('r5', north, 's-main', 'Long Lunch', sport, '7a', fr);
    route('r6', north, 's-main', 'Quiet Crack', sport, '6a', fr);
    route('r7', north, 's-main', 'Last Light', Discipline.trad, 'V+',
        GradeSystem.uiaa,
        pitches: 3);
    route('r8', north, 's-cave', 'Low Roof', Discipline.boulder, '6B+',
        GradeSystem.font);
    route('r9', north, 's-cave', 'Pocket Party', Discipline.boulder, '6A',
        GradeSystem.font);
    route('r10', sea, 's-slabs', 'Salt Line', sport, '5b', fr);
    route('r11', sea, 's-slabs', 'High Tide', sport, '6a', fr);
    route('r12', sea, 's-slabs', 'Green Ledge', sport, '6b+', fr);
    route('r13', gym, null, 'Yellow circuit', Discipline.gym, '6b', fr);
    route('r14', gym, null, 'Blue arete', Discipline.gym, '6a', fr);

    // A year of sample ascents, so history and the yearly report have data.
    final y = now.year;
    var n = 0;
    void ascent(String routeId, int month, int day, AscentStyle style,
        {int attempts = 1, String notes = ''}) {
      final date = DateTime(y, month, day);
      if (date.isAfter(now)) return;
      final r = _routes[routeId]!;
      n++;
      _ascents['a$n'] = Ascent(
        id: 'a$n',
        userId: uid,
        routeId: routeId,
        cragId: r.cragId,
        date: date,
        style: style,
        attempts: attempts,
        notes: notes,
      );
    }

    const os = AscentStyle.onsight;
    const fl = AscentStyle.flash;
    const rp = AscentStyle.redpoint;
    const tr = AscentStyle.topRope;
    const at = AscentStyle.attempt;
    const pr = AscentStyle.project;
    ascent('r14', 1, 11, tr);
    ascent('r13', 1, 25, at, attempts: 2);
    ascent('r13', 2, 8, fl);
    ascent('r10', 3, 15, os);
    ascent('r11', 3, 15, fl);
    ascent('r12', 3, 15, at, attempts: 2);
    ascent('r1', 4, 5, os);
    ascent('r6', 4, 5, os);
    ascent('r2', 4, 19, rp, attempts: 3, notes: 'Crux is the second bolt.');
    ascent('r9', 5, 3, fl);
    ascent('r8', 5, 3, at, attempts: 4);
    ascent('r12', 5, 24, rp, attempts: 2);
    ascent('r3', 6, 7, rp, attempts: 2);
    ascent('r7', 6, 21, os, notes: 'Three pitches, long day.');
    ascent('r8', 7, 12, rp, attempts: 2);
    ascent('r4', 9, 6, pr, attempts: 2);
    ascent('r4', 9, 20, pr, attempts: 3);
    ascent('r11', 10, 4, os);
    ascent('r4', 10, 18, rp, attempts: 2, notes: 'Finally.');
    ascent('r5', 10, 18, at);
  }
}
