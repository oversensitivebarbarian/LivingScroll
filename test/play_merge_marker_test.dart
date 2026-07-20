// Widget coverage for the next-scene MERGE marker: a
// next-scene button whose target is occupied by another active track carries a
// "-> merge" icon. The merge-on-navigation itself is unit-tested in
// party_controller_test and end-to-end in the integration test.

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

Scene _scene() => Scene.fromJson({
  'name': 'Scene',
  'scene_uuid': 's1',
  'scene_type': 'standard',
  'description': 'A room.',
});

PlayNextScene _next(String name, {required bool occupied}) => (
  uuid: name,
  name: name,
  discs: const [],
  op: VisibilityOp.or,
  requiredEvents: const <String>[],
  visited: false,
  occupiedByOtherTrack: occupied,
);

void main() {
  testWidgets('merge marker shows only on an occupied next-scene button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        PlayScreen(
          scene: _scene(),
          mode: PlayMode.gameplay,
          keyEvents: const [],
          nextScenes: [
            _next('Meet', occupied: true),
            _next('Alone', occupied: false),
          ],
          npcs: const [],
          notes: const [],
          images: const [],
          onExit: () {},
          onFollowScene: (_, _, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('play.nextscene.Meet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play.nextscene.Meet.merge')),
      findsOneWidget,
    );
    // The un-occupied option has no marker.
    expect(find.byKey(const ValueKey('play.nextscene.Alone')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play.nextscene.Alone.merge')),
      findsNothing,
    );
  });
}
