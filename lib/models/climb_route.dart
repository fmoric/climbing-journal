import 'convert.dart';
import 'enums.dart';

/// Named ClimbRoute to avoid clashing with Flutter's navigation Route.
class ClimbRoute {
  const ClimbRoute({
    required this.id,
    required this.cragId,
    required this.name,
    required this.discipline,
    required this.grade,
    required this.gradeSystem,
    this.sectorId,
    this.pitches = 1,
    this.setDate,
    this.retiredDate,
    this.photoIds = const [],
  });

  final String id;
  final String cragId;

  /// Optional: small crags and gyms may have no sectors.
  final String? sectorId;
  final String name;
  final Discipline discipline;

  /// Stored as entered, e.g. "6b+", "7A", "V5".
  final String grade;
  final GradeSystem gradeSystem;
  final int pitches;

  /// Gym routes only: when the route was set and taken down.
  final DateTime? setDate;
  final DateTime? retiredDate;

  /// Photos of the route (topo, the wall with the line), oldest first.
  /// IDs point into the device's photo store; the images are not part of
  /// the route record.
  final List<String> photoIds;

  bool get isMultiPitch => pitches > 1;

  ClimbRoute copyWith({List<String>? photoIds}) => ClimbRoute(
        id: id,
        cragId: cragId,
        sectorId: sectorId,
        name: name,
        discipline: discipline,
        grade: grade,
        gradeSystem: gradeSystem,
        pitches: pitches,
        setDate: setDate,
        retiredDate: retiredDate,
        photoIds: photoIds ?? this.photoIds,
      );

  Map<String, dynamic> toMap() => {
        'cragId': cragId,
        'sectorId': sectorId,
        'name': name,
        'discipline': discipline.name,
        'grade': grade,
        'gradeSystem': gradeSystem.name,
        'pitches': pitches,
        'setDate': timestampFrom(setDate),
        'retiredDate': timestampFrom(retiredDate),
        'photoIds': photoIds,
      };

  factory ClimbRoute.fromMap(String id, Map<String, dynamic> m) => ClimbRoute(
        id: id,
        cragId: m['cragId'] as String? ?? '',
        sectorId: m['sectorId'] as String?,
        name: m['name'] as String? ?? '',
        discipline:
            enumFromName(Discipline.values, m['discipline'], Discipline.sport),
        grade: m['grade'] as String? ?? '',
        gradeSystem: enumFromName(
            GradeSystem.values, m['gradeSystem'], GradeSystem.french),
        pitches: (m['pitches'] as num?)?.toInt() ?? 1,
        setDate: dateFrom(m['setDate']),
        retiredDate: dateFrom(m['retiredDate']),
        photoIds: (m['photoIds'] as List?)?.whereType<String>().toList() ??
            const [],
      );
}
