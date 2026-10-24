import 'package:geolocator/geolocator.dart';

/// Wraps the device location. Every failure (service off, permission
/// denied, timeout) returns null, so the app falls back to recent crags.
class LocationService {
  const LocationService();

  Future<({double lat, double lng})?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }
}
