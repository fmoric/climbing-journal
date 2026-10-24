import 'package:climbing_journal/data/demo_journal_repository.dart';
import 'package:climbing_journal/ui/home_shell.dart';
import 'package:climbing_journal/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DemoJournalRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = DemoJournalRepository.seeded(now: DateTime(2026, 12, 31));
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: HomeShell(repo: repo, climber: 'Test climber'),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('opens on the first crag with its routes', (tester) async {
    await _pump(tester);
    expect(find.text('Demo Crag North'), findsOneWidget);
    expect(find.text('Morning Slab'), findsOneWidget);
    expect(find.textContaining('Demo · sample data'), findsOneWidget);
  });

  testWidgets('quick log saves an ascent', (tester) async {
    final repo = await _pump(tester);
    final before = (await repo.watchMyAscents().first).length;

    await tester.tap(find.text('Blue Dihedral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flash'));
    await tester.pumpAndSettle();
    expect(find.text('Save · Flash'), findsOneWidget);

    await tester.ensureVisible(find.text('Save · Flash'));
    await tester.tap(find.text('Save · Flash'));
    await tester.pumpAndSettle();

    final after = await repo.watchMyAscents().first;
    expect(after.length, before + 1);
    expect(find.textContaining('Logged Blue Dihedral'), findsOneWidget);
  });

  testWidgets('add route suggests an existing route', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Add route'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'dry spel');
    await tester.pumpAndSettle();
    expect(find.text('Dry Spell'), findsOneWidget);
    expect(find.text("It's a new route"), findsOneWidget);
  });

  testWidgets('history shows the year and the report button',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    expect(find.textContaining('report (PDF)'), findsOneWidget);
    expect(find.textContaining('Grade pyramid'), findsOneWidget);
  });
}
