import 'package:cloud_firestore/cloud_firestore.dart';

class Sector {
  const Sector({
    required this.id,
    required this.cragId,
    required this.name,
    this.location,
  });

  final String id;
  final String cragId;
  final String name;
  final GeoPoint? location;

  Map<String, dynamic> toMap() => {
        'cragId': cragId,
        'name': name,
        'location': location,
      };

  factory Sector.fromMap(String id, Map<String, dynamic> m) => Sector(
        id: id,
        cragId: m['cragId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        location: m['location'] as GeoPoint?,
      );
}
