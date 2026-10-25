import 'photo_store.dart';

/// The browser build is the demo; photos last until the page reloads.
Future<PhotoStore> openPhotoStore() async => MemoryPhotoStore();
