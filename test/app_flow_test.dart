import 'package:climbing_journal/data/demo_journal_repository.dart';
import 'package:climbing_journal/data/photo_store.dart';
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
    home: HomeShell(
        repo: repo, photos: MemoryPhotoStore(), climber: 'Test climber'),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('opens on the first crag with its routes', (tester) async {
    await _pump(tester);
    expect(find.text('Demo Crag North'), findsOneWidget);
    expect(find.text('Blue Dihedral'), findsOneWidget);
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
    // Typing letter by letter: short names must not break the screen.
    for (final partial in ['d', 'dr', 'dry', 'dry spel']) {
      await tester.enterText(find.byType(TextField).first, partial);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'typing "$partial"');
    }
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

  testWidgets('Start opens climbing mode with a Log button', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Start: show photo while climbing').first);
    await tester.pumpAndSettle();
    expect(find.text('No photo of this route yet'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save ·'), findsOneWidget);
  });
}
