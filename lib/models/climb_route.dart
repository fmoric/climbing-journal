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

  bool get isMultiPitch => pitches > 1;

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
      );
}
