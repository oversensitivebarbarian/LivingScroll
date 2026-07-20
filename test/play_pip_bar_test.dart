// Widget coverage for the PiP bar: un-focused tracks show
// as thumbnails and tapping one reports a focus switch. The full split -> PiP ->
// focus scenario end-to-end is the integration test.

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

PlayScreen _play({
  List<PipTrack> pipTracks = const [],
  void Function(String)? onFocusSwitch,
}) => PlayScreen(
  scene: _scene(),
  mode: PlayMode.gameplay,
  keyEvents: const [],
  nextScenes: const [],
  npcs: const [],
  notes: const [],
  images: const [],
  onExit: () {},
  pipTracks: pipTracks,
  onFocusSwitch: onFocusSwitch,
);

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no PiP thumbnails when the party is not split', (tester) async {
    await _pump(tester, _play());
    expect(find.byKey(const ValueKey('play.pip.t2')), findsNothing);
  });

  testWidgets('un-focused tracks render as thumbnails and tap switches focus', (
    tester,
  ) async {
    String? switchedTo;
    await _pump(
      tester,
      _play(
        pipTracks: const [
          (trackId: 't2', backgroundImage: null, pcLabel: 'Bob'),
          (trackId: 't3', backgroundImage: null, pcLabel: 'Cara'),
        ],
        onFocusSwitch: (id) => switchedTo = id,
      ),
    );

    expect(find.byKey(const ValueKey('play.pip.t2')), findsOneWidget);
    expect(find.byKey(const ValueKey('play.pip.t3')), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play.pip.t2')));
    await tester.pumpAndSettle();
    expect(switchedTo, 't2');
  });
}
