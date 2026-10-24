import 'convert.dart';
import 'enums.dart';

class Ascent {
  const Ascent({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.cragId,
    required this.date,
    required this.style,
    this.attempts = 1,
    this.notes = '',
    this.visibility = AscentVisibility.private,
  });

  final String id;
  final String userId;
  final String routeId;

  /// Copied from the route so history can filter by crag without a join.
  final String cragId;
  final DateTime date;
  final AscentStyle style;
  final int attempts;
  final String notes;
  final AscentVisibility visibility;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'routeId': routeId,
        'cragId': cragId,
        'date': timestampFrom(date),
        'style': style.name,
        'attempts': attempts,
        'notes': notes,
        'visibility': visibility.name,
      };

  factory Ascent.fromMap(String id, Map<String, dynamic> m) => Ascent(
        id: id,
        userId: m['userId'] as String? ?? '',
        routeId: m['routeId'] as String? ?? '',
        cragId: m['cragId'] as String? ?? '',
        date: dateFrom(m['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        style:
            enumFromName(AscentStyle.values, m['style'], AscentStyle.attempt),
        attempts: (m['attempts'] as num?)?.toInt() ?? 1,
        notes: m['notes'] as String? ?? '',
        visibility: enumFromName(AscentVisibility.values, m['visibility'],
            AscentVisibility.private),
      );
}
