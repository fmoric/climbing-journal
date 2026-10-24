import 'package:cloud_firestore/cloud_firestore.dart';

import 'convert.dart';
import 'enums.dart';

class Crag {
  const Crag({
    required this.id,
    required this.name,
    this.type = CragType.outdoor,
    this.location,
  });

  final String id;
  final String name;
  final CragType type;

  /// Used for nearest-crag detection (FR-2). Optional for gyms.
  final GeoPoint? location;

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'location': location,
      };

  factory Crag.fromMap(String id, Map<String, dynamic> m) => Crag(
        id: id,
        name: m['name'] as String? ?? '',
        type: enumFromName(CragType.values, m['type'], CragType.outdoor),
        location: m['location'] as GeoPoint?,
      );
}
