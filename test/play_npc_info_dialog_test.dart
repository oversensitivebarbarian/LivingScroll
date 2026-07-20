import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: home),
    );

Scene _scene() => Scene.fromJson({
      'name': 'Scene',
      'scene_uuid': 's1',
      'scene_type': 'start',
      'description': 'A room.',
    });

PlayNpc _npc({String backstory = 'Once a hero.'}) => (
      uuid: 'v1',
      name: 'The Boss',
      iconImage: null,
      fullImage: null,
      description: 'A dangerous foe.',
      backstory: backstory,
      state: 'active',
      stats: const <({String label, String value})>[],
      villain: null,
      sevenSeaStats: const {},
    );

Widget _play({String backstory = 'Once a hero.'}) => _app(PlayScreen(
      scene: _scene(),
      mode: PlayMode.gameplay,
      keyEvents: const [],
      nextScenes: const [],
      npcs: [_npc(backstory: backstory)],
      notes: const [],
      images: const [],
      onExit: () {},
    ));

// The NPC info window's original proportions (720:480 = 3:2).
const double _ratio = 720 / 480;

Future<void> _openInfo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
  await tester.pumpAndSettle();
}

Size _frame(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('play.npc.info.v1.frame')));

void main() {
  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
  }

  testWidgets('NPC info window fills 80% of the window height, 3:2 proportions',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play());
    await tester.pumpAndSettle();
    await _openInfo(tester);

    final f = _frame(tester);
    expect(f.height, closeTo(1000 * 0.8, 0.5)); // 80% of window height
    expect(f.width, closeTo(1000 * 0.8 * _ratio, 0.5)); // ratio preserved
    expect(f.width / f.height, closeTo(_ratio, 0.001));
  });

  testWidgets('NPC info window is not fixed — it tracks a window resize',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play());
    await tester.pumpAndSettle();
    await _openInfo(tester);
    expect(_frame(tester).height, closeTo(800, 0.5));

    // Resizing the window resizes the open dialog (a fixed box would not).
    await resize(tester, const Size(1600, 1200));
    final f = _frame(tester);
    expect(f.height, closeTo(1200 * 0.8, 0.5));
    expect(f.width, closeTo(1200 * 0.8 * _ratio, 0.5));
  });

  testWidgets('the backstory (Historia) window uses the same responsive frame',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play());
    await tester.pumpAndSettle();
    await _openInfo(tester);

    await tester.tap(find.byKey(const ValueKey('play.npc.info.v1.history')));
    await tester.pumpAndSettle();
    final f =
        tester.getSize(find.byKey(const ValueKey('play.npc.history.v1.frame')));
    expect(f.height, closeTo(800, 0.5));
    expect(f.width, closeTo(800 * _ratio, 0.5));
  });

  testWidgets('full_image fills the maximum dialog height (1:1.43 portrait)',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play());
    await tester.pumpAndSettle();
    await _openInfo(tester);

    final frame = _frame(tester);
    final image =
        tester.getSize(find.byKey(const ValueKey('play.npc.info.v1.image')));
    // The image is as tall as the whole dialog frame (no stats block here) and
    // keeps its 1:1.43 portrait ratio (width follows from the height).
    expect(image.height, closeTo(frame.height, 0.5));
    expect(image.width, closeTo(image.height / 1.43, 0.5));
  });

  testWidgets('a narrow window clamps the width and keeps the ratio',
      (tester) async {
    await resize(tester, const Size(800, 1200));
    await tester.pumpWidget(_play());
    await tester.pumpAndSettle();
    await _openInfo(tester);

    final f = _frame(tester);
    // Unclamped width (0.8*1200*1.5 = 1440) exceeds this narrow window, so the
    // width clamps to the available space and the height follows to keep the 3:2
    // ratio (below the 80% target). It never overflows the window.
    expect(f.width / f.height, closeTo(_ratio, 0.001)); // ratio preserved
    expect(f.width, lessThan(800)); // fits inside the window
    expect(f.height, lessThan(1200 * 0.8)); // reduced from the 80% target
    expect(f.width, greaterThan(500)); // still a sensibly large dialog
  });

  testWidgets('Historia button is shown when the NPC has a backstory',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play(backstory: 'Once a hero.'));
    await tester.pumpAndSettle();
    await _openInfo(tester);

    expect(find.byKey(const ValueKey('play.npc.info.v1.history')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('play.npc.info.v1.close')), findsOneWidget);
  });

  testWidgets('Historia button is hidden when the backstory is empty',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play(backstory: ''));
    await tester.pumpAndSettle();
    await _openInfo(tester);

    // No backstory -> no Historia button; Close is still there.
    expect(find.byKey(const ValueKey('play.npc.info.v1.history')), findsNothing);
    expect(find.byKey(const ValueKey('play.npc.info.v1.close')), findsOneWidget);
  });

  testWidgets('Historia button is hidden when the backstory is only whitespace',
      (tester) async {
    await resize(tester, const Size(1400, 1000));
    await tester.pumpWidget(_play(backstory: '   \n  '));
    await tester.pumpAndSettle();
    await _openInfo(tester);

    expect(find.byKey(const ValueKey('play.npc.info.v1.history')), findsNothing);
  });
}
