import 'package:converternow/main.dart';
import 'package:converternow/ui/plot_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tabs render and converter computes R-A-P-D', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ConverterApp());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '3370');
    await t.pumpAndSettle();
    expect(find.text('Hill system · पहाड'), findsOneWidget);
    // 3370 sq ft → 0-9-3-1.5
    expect(find.text('9'), findsWidgets);

    for (final tab in ['Scan', 'Plot', 'Saved', 'Convert']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
    }
  });

  testWidgets('plot editor opens from grid and tape mode works', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ConverterApp());
    await t.pumpAndSettle();
    await t.tap(find.text('Plot').last);
    await t.pumpAndSettle();

    final fields = find.descendant(
        of: find.byType(PlotScreen), matching: find.byType(TextField));
    for (final (i, v) in [(0, '50'), (1, '40'), (2, '50'), (3, '40'), (4, '64.0312')]) {
      await t.enterText(fields.at(i), v);
    }
    await t.pumpAndSettle();
    final scrollable = find
        .descendant(of: find.byType(PlotScreen), matching: find.byType(Scrollable))
        .first;
    await t.scrollUntilVisible(find.text('Open in plotter & save'), 300,
        scrollable: scrollable);
    // 50x40 rectangle (diagonal 64.03) = 2000 ft² → 0-5-3-1.73 R-A-P-D
    expect(find.text('Open in plotter & save'), findsOneWidget);
    expect(find.text('2,000'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Draw on a grid'), -300,
        scrollable: scrollable);

    await t.tap(find.text('Draw on a grid'));
    await t.pumpAndSettle();
    expect(find.text('CALCULATED AREA'), findsOneWidget);
    // 20 x 15 m = 300 m² = 3229.2 sq ft
    expect(find.text('3,229.2'), findsOneWidget);
  });
}
