// Verifies the loading ROLLER is present on each screen of the play-launch flow
// while it loads its data: the adventure launch screen (the play form where the
// group name is entered) and the playthrough screen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_launch_screen.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/screens/playthrough_screen.dart';
import 'package:living_scroll/settings/settings_overrides.dart';
import 'package:living_scroll/settings/settings_scope.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> doc() => {
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': '',
          'description': '',
        },
        'images': [], 'audio': [], 'paths': [],
        'key_events': [], 'notes': [], 'gm_notes': [], 'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
          },
        ],
      };

  Widget app(Widget home) => SettingsScope(
        overrides: const SettingsOverrides(),
        onChanged: (_) async {},
        child: MaterialApp(
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      );

  testWidgets('launch screen shows a roller while loading, then the form',
      (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(jsonEncode(doc()));

    await tester.pumpWidget(app(const AdventureLaunchScreen(
      adventure:
          AdventureSummary(slug: 'Pack', name: 'Pack', version: '1.0.0'),
    )));

    // First frame: the data is still loading -> the roller is shown.
    expect(find.byKey(const ValueKey('launch.loading')), findsOne);

    await tester.pumpAndSettle();

    // Loaded: the form (group field) is shown, the roller is gone.
    expect(find.byKey(const ValueKey('launch.loading')), findsNothing);
    expect(find.byKey(const ValueKey('launch.field.group')), findsOne);
  });

  testWidgets('playthrough screen shows a roller while loading, then the scene',
      (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final save = Directory('${harness.savesDir.path}/SaveX');
    await save.create(recursive: true);
    await File('${save.path}/LivingScroll.json').writeAsString(jsonEncode(doc()));

    await tester.pumpWidget(app(const PlaythroughScreen(
      saveName: 'SaveX',
      startSceneUuid: 's1',
      mode: PlayMode.preview, // preview avoids progress writes during the test
    )));

    // First frame: the save is still loading -> the roller is shown.
    expect(find.byKey(const ValueKey('playthrough.loading')), findsOne);

    await tester.pumpAndSettle();

    // Loaded: the play view (scene title) is shown, the roller is gone.
    expect(find.byKey(const ValueKey('playthrough.loading')), findsNothing);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
        'Opening');
  });
}
