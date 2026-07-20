import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/main.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/adventure_launch_screen.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/rail_state.dart';

/// Every side-navigation rail in the app must be STATIC: expanding / collapsing
/// it is INSTANT, with no slide/reveal animation. Each rail is keyed by its
/// extended state, so toggling replaces it with a fresh instance already at the
/// target layout (its extend controller initialises AT the target) instead of
/// animating to it. This test drives the toggle and asserts nothing animates
/// between the first frame after the toggle and the settled state.
Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: home),
    );

/// Toggles the (collapsed) rail once and asserts the expand is instant: the rail
/// is already wider on the first frame after the toggle, and its width does not
/// change afterwards (no animation).
Future<void> _expectInstantExpand(WidgetTester tester) async {
  double railWidth() => tester.getSize(find.byType(NavigationRail)).width;
  final collapsed = railWidth();

  await tester.tap(find.byIcon(Symbols.side_navigation));
  await tester.pump(); // exactly one frame after the toggle
  final atFirstFrame = railWidth();

  await tester.pumpAndSettle();
  final settled = railWidth();

  // Expanded already on the first frame (not still collapsed, not mid-animation).
  expect(atFirstFrame, greaterThan(collapsed + 100),
      reason: 'rail did not expand instantly '
          '(collapsed=$collapsed firstFrame=$atFirstFrame)');
  // Nothing animated between that first frame and settled.
  expect(settled, atFirstFrame,
      reason: 'rail width animated after the toggle '
          '(firstFrame=$atFirstFrame settled=$settled)');
}

void main() {
  // The rail's open/closed state is app-wide and shared across views, so reset
  // it to collapsed before each case (these tests assume a collapsed start).
  setUp(() => RailState.extended.value = false);

  testWidgets('app shell rail expands instantly (static)', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();

    await _expectInstantExpand(tester);
  });

  testWidgets('play view rail expands instantly (static)', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scene = Scene.fromJson({
      'name': 'Scene',
      'scene_uuid': 's1',
      'scene_type': 'standard',
      'description': 'A room.',
    });
    await tester.pumpWidget(_app(PlayScreen(
      scene: scene,
      mode: PlayMode.gameplay,
      keyEvents: const [],
      nextScenes: const [],
      npcs: const [],
      notes: const [],
      images: const [],
      seenNotes: const [],
      onExit: () {},
    )));
    await tester.pumpAndSettle();

    await _expectInstantExpand(tester);
  });

  testWidgets('adventure launch rail expands instantly (static)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const AdventureLaunchScreen(
      adventure: AdventureSummary(slug: 'demo', name: 'Demo'),
    )));
    // The launch screen shows a perpetual loading spinner while it reads its
    // data, so it never `pumpAndSettle`s — drive it with fixed pumps instead.
    // The rail stays visible during loading, so the toggle still works.
    await tester.pump(const Duration(milliseconds: 50));

    double railWidth() => tester.getSize(find.byType(NavigationRail)).width;
    final collapsed = railWidth();

    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pump(); // one frame after the toggle
    final atFirstFrame = railWidth();

    await tester.pump(const Duration(milliseconds: 300)); // past any animation
    final later = railWidth();

    expect(atFirstFrame, greaterThan(collapsed + 100),
        reason: 'launch rail did not expand instantly '
            '(collapsed=$collapsed firstFrame=$atFirstFrame)');
    expect(later, atFirstFrame,
        reason: 'launch rail width animated after the toggle '
            '(firstFrame=$atFirstFrame later=$later)');
  });
}
