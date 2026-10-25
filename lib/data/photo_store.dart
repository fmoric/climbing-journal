import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'photo_store_io.dart' if (dart.library.js_interop) 'photo_store_web.dart'
    as platform;

/// Route photos (FR-12). Images are kept apart from the logbook records:
/// on the phone as files in the app's folder, in memory in the demo.
abstract class PhotoStore {
  /// The store for the current platform: files on Android/iOS, memory
  /// in a browser.
  static Future<PhotoStore> open() => platform.openPhotoStore();

  /// Saves a JPEG and returns its ID.
  Future<String> save(Uint8List bytes);

  /// The image, or null if it is missing (e.g. after restoring a backup on
  /// another phone, since backups hold records but not photos).
  Future<Uint8List?> load(String id);

  Future<void> delete(String id);
}

/// Keeps photos in memory. Used by the demo, the web build and tests.
class MemoryPhotoStore implements PhotoStore {
  final Map<String, Uint8List> _photos = {};
  static const _uuid = Uuid();

  @override
  Future<String> save(Uint8List bytes) async {
    final id = '${_uuid.v4()}.jpg';
    _photos[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> load(String id) async => _photos[id];

  @override
  Future<void> delete(String id) async => _photos.remove(id);
}
