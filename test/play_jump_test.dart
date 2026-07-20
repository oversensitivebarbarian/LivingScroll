// Widget coverage for the Jump-to-scene button + dialog:
// visibility (split OR dead end), target list, merge marker, and reporting the
// chosen uuid. The jump -> merge end-to-end path is covered by the integration test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/visibility/visibility_rules.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: home),
);

Scene _scene({String type = 'standard'}) => Scene.fromJson({
  'name': 'Scene',
  'scene_uuid': 's1',
  'scene_type': type,
  'description': 'A room.',
});

PlayNextScene _next(String name) => (
  uuid: name,
  name: name,
  discs: const [],
  op: VisibilityOp.or,
  requiredEvents: const <String>[],
  visited: false,
  occupiedByOtherTrack: false,
);

PlayScreen _play({
  String sceneType = 'standard',
  List<PlayNextScene> nextScenes = const [],
  bool isSplit = false,
  List<PlayJumpTarget> jumpTargets = const [],
  void Function(String, Set<String>, Set<String>)? onJump = _noop,
}) => PlayScreen(
  scene: _scene(type: sceneType),
  mode: PlayMode.gameplay,
  keyEvents: const [],
  nextScenes: nextScenes,
  npcs: const [],
  notes: const [],
  images: const [],
  onExit: () {},
  onFollowScene: (_, _, _) {},
  isSplit: isSplit,
  jumpTargets: jumpTargets,
  onJump: onJump,
);

void _noop(String a, Set<String> b, Set<String> c) {}

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

final _jump = find.byKey(const ValueKey('play.jump'));

void main() {
  testWidgets('hidden when onJump not wired', (tester) async {
    await _pump(tester, _play(onJump: null, nextScenes: [_next('A')]));
    expect(_jump, findsNothing);
  });

  testWidgets('hidden on an end scene', (tester) async {
    await _pump(tester, _play(sceneType: 'end', isSplit: true));
    expect(_jump, findsNothing);
  });

  testWidgets('hidden when not split and there IS a visible next scene', (
    tester,
  ) async {
    await _pump(tester, _play(nextScenes: [_next('A')]));
    expect(_jump, findsNothing);
  });

  testWidgets('shown when split even with next scenes', (tester) async {
    await _pump(tester, _play(isSplit: true, nextScenes: [_next('A')]));
    expect(_jump, findsOneWidget);
  });

  testWidgets('shown on a dead end (no visible next scenes)', (tester) async {
    await _pump(tester, _play(nextScenes: const []));
    expect(_jump, findsOneWidget);
  });

  testWidgets('dialog lists targets, marks track positions, reports the pick', (
    tester,
  ) async {
    String? jumped;
    await _pump(
      tester,
      _play(
        isSplit: true,
        nextScenes: [_next('A')],
        jumpTargets: const [
          (uuid: 's9', name: 'Bob here', otherTrackHere: true),
          (uuid: 's5', name: 'Old Mill', otherTrackHere: false),
        ],
        onJump: (uuid, _, _) => jumped = uuid,
      ),
    );

    await tester.tap(_jump);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.jump.dialog')), findsOneWidget);
    // Track position carries the merge marker; the generic target does not.
    expect(
      find.byKey(const ValueKey('play.jump.target.s9.merge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('play.jump.target.s5.merge')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('play.jump.target.s5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.jump.dialog')), findsNothing);
    expect(jumped, 's5');
  });
}
