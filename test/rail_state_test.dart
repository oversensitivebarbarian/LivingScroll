import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/adventure_launch_screen.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/rail_state.dart';

/// The navigation rail's open/closed state ("roller") is app-wide and PRESERVED
/// between views: expanding it on one screen keeps it expanded when the user
/// moves to another. It is backed by a single shared [RailState.extended]
/// notifier that every rail screen reads and writes.
Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: home),
    );

Widget _playView() {
  final scene = Scene.fromJson({
    'name': 'Scene',
    'scene_uuid': 's1',
    'scene_type': 'standard',
    'description': 'A room.',
  });
  return _app(PlayScreen(
    scene: scene,
    mode: PlayMode.gameplay,
    keyEvents: const [],
    nextScenes: const [],
    npcs: const [],
    notes: const [],
    images: const [],
    seenNotes: const [],
    onExit: () {},
  ));
}

Widget _launchView() => _app(const AdventureLaunchScreen(
      adventure: AdventureSummary(slug: 'demo', name: 'Demo'),
    ));

void main() {
  double railWidth(WidgetTester tester) =>
      tester.getSize(find.byType(NavigationRail)).width;

  group('RailState (shared model)', () {
    setUp(() => RailState.extended.value = false);

    test('starts collapsed and toggle flips the shared value', () {
      expect(RailState.extended.value, isFalse);
      RailState.toggle();
      expect(RailState.extended.value, isTrue);
      RailState.toggle();
      expect(RailState.extended.value, isFalse);
    });

    test('notifies listeners on change', () {
      var notified = 0;
      void listener() => notified++;
      RailState.extended.addListener(listener);
      addTearDown(() => RailState.extended.removeListener(listener));
      RailState.toggle();
      RailState.toggle();
      expect(notified, 2);
    });
  });

  group('preserved between views', () {
    setUp(() => RailState.extended.value = false);

    testWidgets('expanding the rail on one view keeps it expanded on the next',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // View 1 — the Play view. Rail starts collapsed.
      await tester.pumpWidget(_playView());
      await tester.pumpAndSettle();
      final collapsed = railWidth(tester);

      // Expand it here.
      await tester.tap(find.byIcon(Symbols.side_navigation));
      await tester.pumpAndSettle();
      expect(railWidth(tester), greaterThan(collapsed + 100));
      expect(RailState.extended.value, isTrue);

      // Navigate to a DIFFERENT view (the launch screen), freshly built.
      await tester.pumpWidget(_launchView());
      await tester.pump(const Duration(milliseconds: 50));

      // Its rail is ALREADY expanded on the first frame — the state carried over
      // rather than resetting to the default collapsed layout.
      expect(railWidth(tester), greaterThan(collapsed + 100),
          reason: 'the second view did not inherit the expanded rail state');
    });

    testWidgets('collapsing the rail on one view keeps it collapsed on the next',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pre-expand the shared state, then open view 1 already expanded.
      RailState.extended.value = true;
      await tester.pumpWidget(_playView());
      await tester.pumpAndSettle();
      final expanded = railWidth(tester);

      // Collapse it here.
      await tester.tap(find.byIcon(Symbols.side_navigation));
      await tester.pumpAndSettle();
      expect(railWidth(tester), lessThan(expanded - 100));
      expect(RailState.extended.value, isFalse);

      // A different, freshly built view starts collapsed too.
      await tester.pumpWidget(_launchView());
      await tester.pump(const Duration(milliseconds: 50));
      expect(railWidth(tester), lessThan(expanded - 100),
          reason: 'the second view did not inherit the collapsed rail state');
    });
  });
}
