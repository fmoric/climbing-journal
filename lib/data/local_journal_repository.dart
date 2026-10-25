import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/sector.dart';
import 'journal_repository.dart';
import 'local_codec.dart';

/// On-device logbook (local mode): no account, no network.
///
/// Data lives in a sembast database on the phone (IndexedDB in a browser).
/// It survives app updates but not uninstalling, so [exportBackup] and
/// [importBackup] let the user keep a copy (FR-10).
class LocalJournalRepository implements JournalRepository {
  LocalJournalRepository(this._db, {this.onWriteError});

  final Database _db;
  final void Function(Object error, StackTrace stack)? onWriteError;

  static const _uuid = Uuid();
  static const backupFormat = 'climbing-journal-backup';
  static const backupVersion = 1;

  final _crags = stringMapStoreFactory.store('crags');
  final _sectors = stringMapStoreFactory.store('sectors');
  final _routes = stringMapStoreFactory.store('routes');
  final _ascents = stringMapStoreFactory.store('ascents');
  final _settings = stringMapStoreFactory.store('settings');

  List<StoreRef<String, Map<String, Object?>>> get _dataStores =>
      [_crags, _sectors, _routes, _ascents];

  @override
  String get uid => 'me';

  @override
  bool get isDemo => false;

  @override
  String newId() => _uuid.v4();

  Stream<List<T>> _watch<T>(
    StoreRef<String, Map<String, Object?>> store,
    T Function(String id, Map<String, dynamic> m) fromMap, {
    Filter? filter,
    List<SortOrder>? sort,
  }) {
    return store
        .query(finder: Finder(filter: filter, sortOrders: sort))
        .onSnapshots(_db)
        .map((snaps) =>
            snaps.map((s) => fromMap(s.key, decodeMap(s.value))).toList());
  }

  void _put(StoreRef<String, Map<String, Object?>> store, String id,
      Map<String, dynamic> data) {
    _fire(store.record(id).put(_db, encodeMap(data)));
  }

  void _fire(Future<Object?> write) {
    unawaited(write.catchError((Object e, StackTrace s) {
      onWriteError?.call(e, s);
      return null;
    }));
  }

  // ---- Crags -------------------------------------------------------------

  @override
  Stream<List<Crag>> watchCrags() =>
      _watch(_crags, Crag.fromMap, sort: [SortOrder('name')]);

  @override
  void createCrag(Crag crag) => _put(_crags, crag.id, crag.toMap());

  @override
  void updateCrag(Crag crag) => createCrag(crag);

  // ---- Sectors -----------------------------------------------------------

  @override
  Stream<List<Sector>> watchSectors(String cragId) => _watch(
        _sectors,
        Sector.fromMap,
        filter: Filter.equals('cragId', cragId),
        sort: [SortOrder('name')],
      );

  @override
  void createSector(Sector sector) =>
      _put(_sectors, sector.id, sector.toMap());

  @override
  void updateSector(Sector sector) => createSector(sector);

  // ---- Routes ------------------------------------------------------------

  @override
  Stream<List<ClimbRoute>> watchRoutes(String cragId) => _watch(
        _routes,
        ClimbRoute.fromMap,
        filter: Filter.equals('cragId', cragId),
        sort: [SortOrder('name')],
      );

  @override
  Stream<List<ClimbRoute>> watchAllRoutes() =>
      _watch(_routes, ClimbRoute.fromMap);

  @override
  void createRoute(ClimbRoute route) =>
      _put(_routes, route.id, route.toMap());

  @override
  void updateRoute(ClimbRoute route) => createRoute(route);

  // ---- Ascents -----------------------------------------------------------

  /// Sorted in Dart: dates are stored as {"_ts": ms} maps, which the
  /// database cannot order by.
  @override
  Stream<List<Ascent>> watchMyAscents() =>
      _watch(_ascents, Ascent.fromMap).map(
          (list) => list..sort((a, b) => b.date.compareTo(a.date)));

  @override
  void createAscent(Ascent ascent) =>
      _put(_ascents, ascent.id, ascent.toMap());

  @override
  void updateAscent(Ascent ascent) => createAscent(ascent);

  @override
  void deleteAscent(String id) => _fire(_ascents.record(id).delete(_db));

  // ---- Settings ----------------------------------------------------------

  /// The climber's name, printed on the yearly report.
  Future<String?> climberName() async {
    final rec = await _settings.record('profile').get(_db);
    final name = rec?['name'];
    return name is String && name.trim().isNotEmpty ? name : null;
  }

  Future<void> setClimberName(String name) =>
      _settings.record('profile').put(_db, {'name': name.trim()});

  // ---- Backup (FR-10) ----------------------------------------------------

  /// The whole logbook as one JSON document.
  Future<String> exportBackup({DateTime? now}) async {
    Future<List<Map<String, Object?>>> dump(
        StoreRef<String, Map<String, Object?>> store) async {
      final snaps = await store.find(_db);
      return [
        for (final s in snaps) {'id': s.key, ...s.value},
      ];
    }

    final doc = {
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'climber': await climberName(),
      'crags': await dump(_crags),
      'sectors': await dump(_sectors),
      'routes': await dump(_routes),
      'ascents': await dump(_ascents),
    };
    return const JsonEncoder.withIndent(' ').convert(doc);
  }

  /// Counts in a backup file, for the confirmation dialog. Throws a
  /// [FormatException] if the file is not a Climbing Journal backup.
  static BackupInfo inspectBackup(String json) {
    final Object? doc;
    try {
      doc = jsonDecode(json);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (doc is! Map || doc['format'] != backupFormat) {
      throw const FormatException('This is not a Climbing Journal backup.');
    }
    final version = doc['version'];
    if (version is! int || version > backupVersion) {
      throw const FormatException(
          'This backup was made by a newer version of the app.');
    }
    int count(String key) => doc[key] is List ? (doc[key] as List).length : 0;
    return BackupInfo(
      crags: count('crags'),
      routes: count('routes'),
      ascents: count('ascents'),
      exportedAt: DateTime.tryParse('${doc['exportedAt']}'),
    );
  }

  /// Replaces the whole logbook with the backup's contents.
  Future<void> importBackup(String json) async {
    inspectBackup(json);
    final doc = jsonDecode(json) as Map<String, dynamic>;
    await _db.transaction((txn) async {
      for (final store in _dataStores) {
        await store.delete(txn);
      }
      Future<void> load(
          StoreRef<String, Map<String, Object?>> store, String key) async {
        for (final item in (doc[key] as List? ?? const [])) {
          final m = Map<String, Object?>.from(item as Map);
          final id = m.remove('id');
          if (id is String && id.isNotEmpty) {
            await store.record(id).put(txn, m);
          }
        }
      }

      await load(_crags, 'crags');
      await load(_sectors, 'sectors');
      await load(_routes, 'routes');
      await load(_ascents, 'ascents');
      final climber = doc['climber'];
      if (climber is String && climber.trim().isNotEmpty) {
        await _settings.record('profile').put(txn, {'name': climber.trim()});
      }
    });
  }
}

class BackupInfo {
  const BackupInfo({
    required this.crags,
    required this.routes,
    required this.ascents,
    this.exportedAt,
  });

  final int crags;
  final int routes;
  final int ascents;
  final DateTime? exportedAt;
}
