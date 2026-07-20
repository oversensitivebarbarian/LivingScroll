// Widget coverage for the Split-party button + dialog.
// The full split -> PiP scenario is the integration test; here we
// assert the button gating and the dialog's >=1/>=1 confirm rule in isolation.

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

Scene _scene({String type = 'start'}) => Scene.fromJson({
  'name': 'Scene',
  'scene_uuid': 's1',
  'scene_type': type,
  'description': 'A room.',
});

PlayScreen _play({
  void Function(Set<String>)? onSplit,
  bool canSplit = true,
  List<String> focusedPcNames = const ['Alice', 'Bob'],
  String sceneType = 'start',
}) => PlayScreen(
  scene: _scene(type: sceneType),
  mode: PlayMode.gameplay,
  keyEvents: const [],
  nextScenes: const [],
  npcs: const [],
  notes: const [],
  images: const [],
  onExit: () {},
  onSplit: onSplit,
  canSplit: canSplit,
  focusedPcNames: focusedPcNames,
);

bool _enabled(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(ValueKey(key)));
  return (w as dynamic).onPressed != null;
}

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('button is absent when onSplit is not wired', (tester) async {
    await _pump(tester, _play(onSplit: null));
    expect(find.byKey(const ValueKey('play.split')), findsNothing);
  });

  testWidgets('button is absent on an end scene', (tester) async {
    await _pump(tester, _play(onSplit: (_) {}, sceneType: 'end'));
    expect(find.byKey(const ValueKey('play.split')), findsNothing);
  });

  testWidgets('button is shown-but-disabled when !canSplit', (tester) async {
    await _pump(tester, _play(onSplit: (_) {}, canSplit: false));
    expect(find.byKey(const ValueKey('play.split')), findsOneWidget);
    expect(_enabled(tester, 'play.split'), isFalse);
  });

  testWidgets(
    'dialog enforces the >=1 / >=1 confirm rule and reports the pick',
    (tester) async {
      Set<String>? picked;
      await _pump(tester, _play(onSplit: (s) => picked = s));

      expect(_enabled(tester, 'play.split'), isTrue);
      await tester.tap(find.byKey(const ValueKey('play.split')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.split.dialog')), findsOneWidget);

      // Nothing selected -> Confirm disabled.
      expect(_enabled(tester, 'play.split.confirm'), isFalse);

      // All selected -> still disabled (at least one must stay).
      await tester.tap(find.byKey(const ValueKey('play.split.pc.Alice')));
      await tester.tap(find.byKey(const ValueKey('play.split.pc.Bob')));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'play.split.confirm'), isFalse);

      // Exactly one moves, one stays -> enabled.
      await tester.tap(find.byKey(const ValueKey('play.split.pc.Bob')));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'play.split.confirm'), isTrue);

      await tester.tap(find.byKey(const ValueKey('play.split.confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.split.dialog')), findsNothing);
      expect(picked, {'Alice'});
    },
  );

  testWidgets('Cancel closes the dialog without splitting', (tester) async {
    Set<String>? picked;
    await _pump(tester, _play(onSplit: (s) => picked = s));
    await tester.tap(find.byKey(const ValueKey('play.split')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.pc.Alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.split.dialog')), findsNothing);
    expect(picked, isNull);
  });
}
