import 'dart:math' as math;

import '../models/crag.dart';

/// Distance between two coordinates in metres (haversine).
double distanceMetres(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

class CragMatch {
  const CragMatch(this.crag, this.distance);
  final Crag crag;
  final double distance;
}

/// The nearest crag within [maxMetres] of the position (FR-2), or null.
/// Crags without a location (e.g. some gyms) are skipped.
CragMatch? nearestCrag(
  List<Crag> crags,
  double lat,
  double lng, {
  double maxMetres = 1500,
}) {
  CragMatch? best;
  for (final c in crags) {
    final loc = c.location;
    if (loc == null) continue;
    final d = distanceMetres(lat, lng, loc.latitude, loc.longitude);
    if (d <= maxMetres && (best == null || d < best.distance)) {
      best = CragMatch(c, d);
    }
  }
  return best;
}

/// "120 m" or "1.4 km".
String formatDistance(double metres) => metres < 1000
    ? '${metres.round()} m'
    : '${(metres / 1000).toStringAsFixed(1)} km';
