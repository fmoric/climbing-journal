import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:uuid/uuid.dart';

import 'photo_store.dart';

/// In the browser (installed web app), photos live in IndexedDB next to
/// the logbook. The demo uses [MemoryPhotoStore] instead.
Future<PhotoStore> openPhotoStore() async =>
    IndexedDbPhotoStore(await databaseFactoryWeb.openDatabase(
        'climbing_journal_photos'));

class IndexedDbPhotoStore implements PhotoStore {
  IndexedDbPhotoStore(this._db);

  final Database _db;
  final _store = stringMapStoreFactory.store('photos');
  static const _uuid = Uuid();

  @override
  Future<String> save(Uint8List bytes) async {
    final id = '${_uuid.v4()}.jpg';
    await _store.record(id).put(_db, {'jpg': Blob(bytes)});
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async {
    final rec = await _store.record(id).get(_db);
    final blob = rec?['jpg'];
    return blob is Blob ? blob.bytes : null;
  }

  @override
  Future<void> delete(String id) => _store.record(id).delete(_db);
}
