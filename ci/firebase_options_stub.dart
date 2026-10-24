// CI-only stand-in for the file `flutterfire configure` generates.
// It lets the app compile in GitHub Actions; the APK it produces cannot
// reach Firebase. Never copy this into a real build.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'ci-stub',
        appId: '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'ci-stub',
      );
}
