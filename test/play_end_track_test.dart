// Widget coverage for the end-scene Finish adventure button: a single
// (un-split) track finishes straight away; while the party is
// split the button is DISABLED until every track has reached an end scene
// (allTracksAtEnd), at which point it finishes the whole adventure. The
// all-tracks-at-end integration flow is in play_merge_jump_test.dart.

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

Scene _end() => Scene.fromJson({
  'name': 'The End',
  'scene_uuid': 'e1',
  'scene_type': 'end',
  'description': 'Curtains.',
});

PlayScreen _play({
  bool isSplit = false,
  bool allTracksAtEnd = false,
  VoidCallback? onFinishAdventure,
}) => PlayScreen(
  scene: _end(),
  mode: PlayMode.gameplay,
  keyEvents: const [],
  nextScenes: const [],
  npcs: const [],
  notes: const [],
  images: const [],
  onExit: () {},
  isSplit: isSplit,
  allTracksAtEnd: allTracksAtEnd,
  onFinishAdventure: onFinishAdventure,
);

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

final _finish = find.byKey(const ValueKey('play.finish'));
bool _enabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(_finish).enabled;

void main() {
  testWidgets('single (un-split) track: Finish adventure is enabled', (
    tester,
  ) async {
    var finished = false;
    await _pump(tester, _play(onFinishAdventure: () => finished = true));
    expect(_finish, findsOneWidget);
    expect(_enabled(tester), isTrue);
    await tester.tap(_finish);
    expect(finished, isTrue);
  });

  testWidgets('split, not every track at an end scene: Finish is DISABLED', (
    tester,
  ) async {
    await _pump(
      tester,
      _play(isSplit: true, allTracksAtEnd: false, onFinishAdventure: () {}),
    );
    // The button is still SHOWN (greyed), just not pressable.
    expect(_finish, findsOneWidget);
    expect(_enabled(tester), isFalse);
    // The per-track "End track" button no longer exists.
    expect(find.byKey(const ValueKey('play.finish.track')), findsNothing);
  });

  testWidgets('split, every track at an end scene: Finish is ENABLED', (
    tester,
  ) async {
    var finished = false;
    await _pump(
      tester,
      _play(
        isSplit: true,
        allTracksAtEnd: true,
        onFinishAdventure: () => finished = true,
      ),
    );
    expect(_finish, findsOneWidget);
    expect(_enabled(tester), isTrue);
    await tester.tap(_finish);
    expect(finished, isTrue);
  });
}
