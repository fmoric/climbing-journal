import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint, Timestamp;

/// Converts model maps (which use Firestore's Timestamp and GeoPoint) to
/// plain JSON values for on-device storage and backup files, and back.
///
/// Timestamp → {"_ts": milliseconds}, GeoPoint → {"_geo": [lat, lng]}.
Object? encodeValue(Object? v) {
  if (v is Timestamp) return {'_ts': v.millisecondsSinceEpoch};
  if (v is GeoPoint) return {'_geo': [v.latitude, v.longitude]};
  if (v is Map) {
    return {for (final e in v.entries) e.key as String: encodeValue(e.value)};
  }
  if (v is List) return v.map(encodeValue).toList();
  return v;
}

Object? decodeValue(Object? v) {
  if (v is Map) {
    if (v.length == 1 && v['_ts'] is num) {
      return Timestamp.fromMillisecondsSinceEpoch((v['_ts'] as num).toInt());
    }
    if (v.length == 1 && v['_geo'] is List) {
      final g = v['_geo'] as List;
      return GeoPoint((g[0] as num).toDouble(), (g[1] as num).toDouble());
    }
    return {for (final e in v.entries) e.key as String: decodeValue(e.value)};
  }
  if (v is List) return v.map(decodeValue).toList();
  return v;
}

Map<String, Object?> encodeMap(Map<String, dynamic> m) =>
    encodeValue(m) as Map<String, Object?>;

Map<String, dynamic> decodeMap(Map<String, Object?> m) =>
    (decodeValue(m) as Map).cast<String, dynamic>();
