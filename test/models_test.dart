import 'package:climbing_journal/models/ascent.dart';
import 'package:climbing_journal/models/climb_route.dart';
import 'package:climbing_journal/models/crag.dart';
import 'package:climbing_journal/models/enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ClimbRoute round-trips through a Firestore map', () {
    final route = ClimbRoute(
      id: 'r1',
      cragId: 'c1',
      sectorId: 's1',
      name: 'Kuk',
      discipline: Discipline.trad,
      grade: 'VI+',
      gradeSystem: GradeSystem.uiaa,
      pitches: 4,
      setDate: DateTime.utc(2026, 10, 1),
    );

    final back = ClimbRoute.fromMap('r1', route.toMap());

    expect(back.name, 'Kuk');
    expect(back.grade, 'VI+');
    expect(back.gradeSystem, GradeSystem.uiaa);
    expect(back.discipline, Discipline.trad);
    expect(back.isMultiPitch, isTrue);
    expect(back.setDate!.isAtSameMomentAs(route.setDate!), isTrue);
    expect(back.retiredDate, isNull);
  });

  test('Ascent defaults to private and round-trips', () {
    final ascent = Ascent(
      id: 'a1',
      userId: 'u1',
      routeId: 'r1',
      cragId: 'c1',
      date: DateTime.utc(2026, 10, 24),
      style: AscentStyle.redpoint,
      attempts: 3,
    );

    final back = Ascent.fromMap('a1', ascent.toMap());

    expect(back.visibility, AscentVisibility.private);
    expect(back.style, AscentStyle.redpoint);
    expect(back.attempts, 3);
    expect(back.date.isAtSameMomentAs(ascent.date), isTrue);
  });

  test('Unknown enum names fall back instead of throwing', () {
    final crag = Crag.fromMap('c1', {
      'name': 'Pakleni',
      'type': 'cave',
      'location': const GeoPoint(45.3, 14.4),
    });

    expect(crag.type, CragType.outdoor);
    expect(crag.location!.latitude, 45.3);
  });
}
