import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/sector.dart';
import 'journal_repository.dart';

/// Firestore implementation.
///
/// Writes are never awaited: offline, Firestore applies a write to the
/// local cache at once but completes its Future only when the server
/// acknowledges it. Server rejections arrive through [onWriteError].
class FirestoreJournalRepository implements JournalRepository {
  FirestoreJournalRepository({
    required FirebaseFirestore db,
    required this.uid,
    this.onWriteError,
  }) : _db = db;

  final FirebaseFirestore _db;

  @override
  final String uid;

  final void Function(Object error, StackTrace stack)? onWriteError;

  static const _uuid = Uuid();

  @override
  bool get isDemo => false;

  @override
  String newId() => _uuid.v4();

  CollectionReference<Map<String, dynamic>> get _crags =>
      _db.collection('crags');
  CollectionReference<Map<String, dynamic>> get _sectors =>
      _db.collection('sectors');
  CollectionReference<Map<String, dynamic>> get _routes =>
      _db.collection('routes');
  CollectionReference<Map<String, dynamic>> get _ascents =>
      _db.collection('ascents');

  @override
  Stream<List<Crag>> watchCrags() => _crags
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Crag.fromMap(d.id, d.data())).toList());

  @override
  void createCrag(Crag crag) => _create(_crags, crag.id, crag.toMap());

  @override
  void updateCrag(Crag crag) => _update(_crags, crag.id, crag.toMap());

  @override
  Stream<List<Sector>> watchSectors(String cragId) => _sectors
      .where('cragId', isEqualTo: cragId)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Sector.fromMap(d.id, d.data())).toList());

  @override
  void createSector(Sector sector) =>
      _create(_sectors, sector.id, sector.toMap());

  @override
  void updateSector(Sector sector) =>
      _update(_sectors, sector.id, sector.toMap());

  @override
  Stream<List<ClimbRoute>> watchRoutes(String cragId) => _routes
      .where('cragId', isEqualTo: cragId)
      .orderBy('name')
      .snapshots()
      .map(_toRoutes);

  @override
  Stream<List<ClimbRoute>> watchAllRoutes() =>
      _routes.snapshots().map(_toRoutes);

  List<ClimbRoute> _toRoutes(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => ClimbRoute.fromMap(d.id, d.data())).toList();

  @override
  void createRoute(ClimbRoute route) =>
      _create(_routes, route.id, route.toMap());

  @override
  void updateRoute(ClimbRoute route) =>
      _update(_routes, route.id, route.toMap());

  @override
  Stream<List<Ascent>> watchMyAscents() => _ascents
      .where('userId', isEqualTo: uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Ascent.fromMap(d.id, d.data())).toList());

  @override
  void createAscent(Ascent ascent) {
    _assertOwner(ascent);
    _create(_ascents, ascent.id, ascent.toMap());
  }

  @override
  void updateAscent(Ascent ascent) {
    _assertOwner(ascent);
    _update(_ascents, ascent.id, ascent.toMap());
  }

  @override
  void deleteAscent(String id) => _fire(_ascents.doc(id).delete());

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
