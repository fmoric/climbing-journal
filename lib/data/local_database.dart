// Opens the on-device database: a file on Android/iOS, IndexedDB in a
// browser.
export 'local_database_io.dart'
    if (dart.library.js_interop) 'local_database_web.dart';
