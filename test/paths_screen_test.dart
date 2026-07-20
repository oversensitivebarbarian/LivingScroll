import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/paths/paths_controller.dart';
import 'package:living_scroll/screens/paths_screen.dart';
import 'package:living_scroll/widgets/path_tile.dart';

PathsController _makeController() =>
    PathsController([for (final c in pathColors) c.id]);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key))).enabled;

void main() {
  testWidgets('Paths list shows one row per fixed path colour', (tester) async {
    final controller = _makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PathsScreen(
          controller: controller,
          onSave: () async => controller.save(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game.paths.list')), findsOneWidget);
    expect(find.byType(PathTile), findsNWidgets(6));
    expect(pathColors.length, 6);

    // Each row's leading disc has its exact colour and a contrasting border.
    for (final color in pathColors) {
      final swatch = find.byKey(ValueKey('path.tile.${color.id}.swatch'));
      expect(swatch, findsOneWidget);
      final decoration =
          tester.widget<Container>(swatch).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, color.color);
      expect(decoration.border, isNotNull);
    }
  });

  testWidgets('A path with no name shows no name label', (tester) async {
    final controller = _makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PathsScreen(
          controller: controller,
          onSave: () async => controller.save(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('path.tile.green.name')), findsNothing);
  });

  testWidgets('Tapping a tile opens the edit form; Save persists and returns', (
    tester,
  ) async {
    final controller = _makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PathsScreen(
          controller: controller,
          onSave: () async => controller.save(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the edit form for the green path.
    await tester.tap(find.byKey(const ValueKey('path.tile.green')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game.paths.edit.field.name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('game.paths.edit.field.description')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('game.paths.edit.swatch')),
      findsOneWidget,
    );

    // Save is disabled until something changes.
    expect(_enabled(tester, 'game.paths.edit.save'), isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('game.paths.edit.field.name')),
      'Forest route',
    );
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'game.paths.edit.save'), isTrue);

    await tester.tap(find.byKey(const ValueKey('game.paths.edit.save')));
    await tester.pumpAndSettle();

    // Back on the list; the tile now shows the saved name.
    expect(find.byKey(const ValueKey('game.paths.list')), findsOneWidget);
    expect(controller.name('green'), 'Forest route');
    expect(find.byKey(const ValueKey('path.tile.green.name')), findsOneWidget);
    expect(find.text('Forest route'), findsOneWidget);
  });
}
