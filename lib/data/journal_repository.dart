import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/sector.dart';

/// Single access point to Firestore.
///
/// Offline rule (FR-5): writes are never awaited. Firestore applies a write
/// to the local cache immediately, but its Future completes only when the
/// server acknowledges it, which never happens without signal. Streams
/// update from the cache at once, so the UI stays correct offline.
///
/// IDs are generated on the device so records can be created offline.
class JournalRepository {
  JournalRepository({
    required FirebaseFirestore db,
    required this.uid,
    this.onWriteError,
  }) : _db = db;

  final FirebaseFirestore _db;
  final String uid;

  /// Called when the server rejects a write after sync (e.g. rules).
  final void Function(Object error, StackTrace stack)? onWriteError;

  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  CollectionReference<Map<String, dynamic>> get _crags =>
      _db.collection('crags');
  CollectionReference<Map<String, dynamic>> get _sectors =>
      _db.collection('sectors');
  CollectionReference<Map<String, dynamic>> get _routes =>
      _db.collection('routes');
  CollectionReference<Map<String, dynamic>> get _ascents =>
      _db.collection('ascents');

  // ---- Crags -------------------------------------------------------------

  Stream<List<Crag>> watchCrags() => _crags
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Crag.fromMap(d.id, d.data())).toList());

  void createCrag(Crag crag) => _create(_crags, crag.id, crag.toMap());
  void updateCrag(Crag crag) => _update(_crags, crag.id, crag.toMap());

  // ---- Sectors -----------------------------------------------------------

  Stream<List<Sector>> watchSectors(String cragId) => _sectors
      .where('cragId', isEqualTo: cragId)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Sector.fromMap(d.id, d.data())).toList());

  void createSector(Sector sector) =>
      _create(_sectors, sector.id, sector.toMap());
  void updateSector(Sector sector) =>
      _update(_sectors, sector.id, sector.toMap());

  // ---- Routes ------------------------------------------------------------

  Stream<List<ClimbRoute>> watchRoutes(String cragId) => _routes
      .where('cragId', isEqualTo: cragId)
      .orderBy('name')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => ClimbRoute.fromMap(d.id, d.data())).toList());

  void createRoute(ClimbRoute route) =>
      _create(_routes, route.id, route.toMap());
  void updateRoute(ClimbRoute route) =>
      _update(_routes, route.id, route.toMap());

  // ---- Ascents (owner only) ----------------------------------------------

  Stream<List<Ascent>> watchMyAscents() => _ascents
      .where('userId', isEqualTo: uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Ascent.fromMap(d.id, d.data())).toList());

  void createAscent(Ascent ascent) {
    _assertOwner(ascent);
    _create(_ascents, ascent.id, ascent.toMap());
  }

  void updateAscent(Ascent ascent) {
    _assertOwner(ascent);
    _update(_ascents, ascent.id, ascent.toMap());
  }

  void deleteAscent(String id) => _fire(_ascents.doc(id).delete());

  // ---- Internals ---------------------------------------------------------

  void _assertOwner(Ascent ascent) {
    if (ascent.userId != uid) {
      throw ArgumentError('Ascents can only be written by their owner.');
    }
  }

  Map<String, dynamic> _audit({required bool isNew}) => {
        if (isNew) 'createdBy': uid,
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  void _create(CollectionReference<Map<String, dynamic>> col, String id,
          Map<String, dynamic> data) =>
      _fire(col.doc(id).set({...data, ..._audit(isNew: true)}));

  void _update(CollectionReference<Map<String, dynamic>> col, String id,
          Map<String, dynamic> data) =>
      _fire(col.doc(id).update({...data, ..._audit(isNew: false)}));

  void _fire(Future<void> write) {
    unawaited(write.catchError((Object e, StackTrace s) {
      onWriteError?.call(e, s);
    }));
  }
}
