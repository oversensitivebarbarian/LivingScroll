// The Library Saves tile's corner button opens an Edit / Delete dialog (Edit opens
// the save in the game editor; Delete runs the existing delete flow). The tile body
// still resumes, and the resume screen carries an Edit button (the Home entry point).
//
// Runs under a real binding: `flutter test -d linux integration_test/
// library_save_edit_test.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const saveName = 'Demo-1.0-Wed';

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder byId(String k) => find.byKey(ValueKey(k));

  // Seed a started game with immutable-stamped base content + group.json.
  Future<void> seedSave(CreateHarness harness) async {
    final dir = Directory('${harness.savesDir.path}/$saveName');
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Demo',
          'system': 'basic',
          'version': '1.0',
          'author': '',
          'description': '',
        },
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'immutable': true,
          },
        ],
      }),
    );
    await File(
      '${dir.path}/group.json',
    ).writeAsString(jsonEncode({'group': 'Wed', 'players': <String>[]}));
  }

  Future<void> openSaves(WidgetTester tester) async {
    await tester.tap(byId('nav.library'));
    await tester.pumpAndSettle();
    await tester.tap(byId('library.tab.saves'));
    await tester.pumpAndSettle();
  }

  testWidgets('library_save_edit: Edit opens the save in the game editor', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSave(harness);
    await harness.pumpApp(tester);

    await openSaves(tester);

    // The Saves tile shows an actions button, not a direct delete.
    expect(byId('adventure.tile.$saveName'), findsOneWidget);
    expect(byId('adventure.tile.$saveName.actions'), findsOneWidget);
    expect(byId('adventure.tile.$saveName.delete'), findsNothing);

    // Actions -> Edit/Delete dialog -> Edit -> the game editor on the save.
    await tester.tap(byId('adventure.tile.$saveName.actions'));
    await tester.pumpAndSettle();
    expect(byId('library.save.actions.dialog'), findsOneWidget);
    await tester.tap(byId('library.save.actions.edit'));
    await tester.pumpAndSettle();

    expect(byId('game.root'), findsOneWidget);
    // The frozen base scene is shown, locked (no delete).
    expect(byId('scene.tile.s1.locked'), findsOneWidget);
    expect(byId('scene.tile.s1.delete'), findsNothing);
  });

  testWidgets('BRANCH delete: the dialog Delete removes the save', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSave(harness);
    await harness.pumpApp(tester);
    await openSaves(tester);

    await tester.tap(byId('adventure.tile.$saveName.actions'));
    await tester.pumpAndSettle();
    await tester.tap(byId('library.save.actions.delete'));
    await tester.pumpAndSettle();
    // The existing confirm dialog.
    expect(byId('library.save.delete.dialog'), findsOneWidget);
    await tester.tap(byId('library.save.delete.confirm'));
    await tester.pumpAndSettle();

    // The whole save directory is gone, and the tile with it.
    expect(
      Directory('${harness.savesDir.path}/$saveName').existsSync(),
      isFalse,
    );
    expect(byId('adventure.tile.$saveName'), findsNothing);
  });

  testWidgets('BRANCH tap_resumes_and_launch_edit: body resumes, resume screen '
      'has an Edit button that opens the editor', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSave(harness);
    await harness.pumpApp(tester);
    await openSaves(tester);

    // Tapping the tile BODY resumes -> the launch screen (resume mode).
    await tester.tap(byId('adventure.tile.$saveName'));
    await tester.pumpAndSettle();
    expect(byId('launch.edit'), findsOneWidget);

    // The resume screen's Edit button opens the game editor.
    await tester.tap(byId('launch.edit'));
    await tester.pumpAndSettle();
    expect(byId('game.root'), findsOneWidget);
  });
}
