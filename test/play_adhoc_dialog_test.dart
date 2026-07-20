// Widget coverage for the ad-hoc scene NAME dialog: the
// Ad-hoc button opens a name dialog; Confirm is disabled while blank and reports
// the entered name. Resume/persistence is covered by the integration test.

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
  'scene_type': 'standard',
  'description': 'A room.',
});

bool _enabled(WidgetTester tester, String key) =>
    (tester.widget(find.byKey(ValueKey(key))) as dynamic).onPressed != null;

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ad-hoc button opens the name dialog; name gates Confirm', (
    tester,
  ) async {
    String? reportedName;
    await _pump(
      tester,
      PlayScreen(
        scene: _scene(),
        mode: PlayMode.gameplay,
        keyEvents: const [],
        nextScenes: const [],
        npcs: const [],
        notes: const [],
        images: const [],
        onExit: () {},
        onAdHoc: (name, checked, deactivated) => reportedName = name,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('play.nextscene.adhoc')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.adhoc.dialog')), findsOneWidget);

    // Blank name -> Confirm disabled.
    expect(_enabled(tester, 'play.adhoc.confirm'), isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('play.adhoc.name')),
      '  Ambush  ',
    );
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'play.adhoc.confirm'), isTrue);

    await tester.tap(find.byKey(const ValueKey('play.adhoc.confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.adhoc.dialog')), findsNothing);
    expect(reportedName, 'Ambush'); // trimmed
  });

  testWidgets('Cancel closes the dialog without starting a scene', (
    tester,
  ) async {
    String? reportedName;
    await _pump(
      tester,
      PlayScreen(
        scene: _scene(),
        mode: PlayMode.gameplay,
        keyEvents: const [],
        nextScenes: const [],
        npcs: const [],
        notes: const [],
        images: const [],
        onExit: () {},
        onAdHoc: (name, checked, deactivated) => reportedName = name,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('play.nextscene.adhoc')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('play.adhoc.name')), 'X');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.adhoc.cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.adhoc.dialog')), findsNothing);
    expect(reportedName, isNull);
  });
}
