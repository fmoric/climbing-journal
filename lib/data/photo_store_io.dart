import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'photo_store.dart';

Future<PhotoStore> openPhotoStore() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'photos'));
  await dir.create(recursive: true);
  return FilePhotoStore(dir);
}

/// One JPEG file per photo in the app's own folder, so photos are removed
/// with the app and never appear in the phone's gallery.
class FilePhotoStore implements PhotoStore {
  FilePhotoStore(this.dir);

  final Directory dir;
  static const _uuid = Uuid();

  File _file(String id) => File(p.join(dir.path, p.basename(id)));

  @override
  Future<String> save(Uint8List bytes) async {
    final id = '${_uuid.v4()}.jpg';
    await _file(id).writeAsBytes(bytes, flush: true);
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async {
    final f = _file(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}
