// PATH: open adventure -> Paths grid -> edit a path -> Save rewrites paths[] in
// place. Branches: an existing path loads onto its tile, and the three
// unsaved-changes choices when leaving the section mid-edit.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenesIndex = 2;
  const pathsIndex = 8;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

  // Seeds a Demo adventure carrying one existing blue path.
  Future<void> seedDemo(CreateHarness harness) async {
    final dir = demoDir(harness);
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Demo',
          'system': 'basic',
          'version': '1.0.0',
          'author': 'A',
          'description': 'd',
          'language': 'en',
          'content_warnings': 'none',
          'license': 'x',
        },
        'images': [],
        'audio': [],
        'paths': [
          {'name': 'Old route', 'color': 'blue', 'description': 'the old way'},
        ],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
  }

  Future<void> openPaths(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.paths')));
    await tester.pumpAndSettle();
  }

  // Opens the green path editor and types a name (leaving it dirty).
  Future<void> editGreen(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('path.tile.green')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.paths.edit.field.name')),
      'Forest',
    );
    await tester.pumpAndSettle();
  }

  // Seeds a Demo adventure whose one scene references the blue path by name,
  // so blue counts as "in use" (BRANCH path_in_use_name_required).
  Future<void> seedDemoWithSceneUsingBluePath(CreateHarness harness) async {
    final dir = demoDir(harness);
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Demo',
          'system': 'basic',
          'version': '1.0.0',
          'author': 'A',
          'description': 'd',
          'language': 'en',
          'content_warnings': 'none',
          'license': 'x',
        },
        'images': [],
        'audio': [],
        'paths': [
          {'name': 'Old route', 'color': 'blue', 'description': 'the old way'},
        ],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Scene1',
            'scene_type': 'start',
            'description': '',
            'path_names': ['Old route'],
          },
        ],
      }),
    );
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  List<Map<String, dynamic>> readPaths(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['paths']
              as List)
          .cast<Map<String, dynamic>>();

  testWidgets('game_paths: edit a path -> Save rewrites paths in place', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openPaths(tester);
    expect(find.byKey(const ValueKey('game.paths.list')), findsOne);

    // STEP 2: open the green editor; Save disabled until a change is made.
    await tester.tap(find.byKey(const ValueKey('path.tile.green')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('game.paths.edit.save')),
          )
          .enabled,
      isFalse,
    );

    // STEP 3: fill the fields.
    await tester.enterText(
      find.byKey(const ValueKey('game.paths.edit.field.name')),
      'Forest',
    );
    await tester.enterText(
      find.byKey(const ValueKey('game.paths.edit.field.description')),
      'through the woods',
    );
    await tester.pumpAndSettle();

    // STEP 4: Save -> paths rewritten, blue preserved, tile shows the name.
    await tester.ensureVisible(
      find.byKey(const ValueKey('game.paths.edit.save')),
    );
    await tester.tap(find.byKey(const ValueKey('game.paths.edit.save')));
    await tester.pumpAndSettle();

    final paths = readPaths(harness);
    final green = paths.firstWhere((p) => p['color'] == 'green');
    expect(green['name'], 'Forest');
    expect(green['description'], 'through the woods');
    expect(
      paths.any((p) => p['color'] == 'blue' && p['name'] == 'Old route'),
      isTrue,
    );
    expect(find.byKey(const ValueKey('path.tile.green.name')), findsOne);
    expect(find.text('Forest'), findsOne);
  });

  testWidgets('BRANCH existing_loaded: a seeded path shows on its tile', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openPaths(tester);

    expect(find.byKey(const ValueKey('path.tile.blue.name')), findsOne);
    expect(find.text('Old route'), findsOne);
    expect(find.byKey(const ValueKey('path.tile.green.name')), findsNothing);
  });

  testWidgets('BRANCH unsaved_save: leaving mid-edit -> Save persists', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openPaths(tester);
    await editGreen(tester);

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(readPaths(harness).any((p) => p['color'] == 'green'), isTrue);
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_abandon: leaving mid-edit -> Discard drops it', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openPaths(tester);
    await editGreen(tester);

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
    await tester.pumpAndSettle();

    // No green path written; the seeded blue path is untouched.
    final paths = readPaths(harness);
    expect(paths.any((p) => p['color'] == 'green'), isFalse);
    expect(paths.single['color'], 'blue');
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_cancel: leaving mid-edit -> Cancel stays', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openPaths(tester);
    await editGreen(tester);

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
    await tester.pumpAndSettle();

    // Stayed on the editor; nothing written.
    expect(find.byKey(const ValueKey('game.paths.edit.field.name')), findsOne);
    expect(selectedIndex(tester), pathsIndex);
    expect(readPaths(harness).any((p) => p['color'] == 'green'), isFalse);
  });

  testWidgets(
    'BRANCH path_in_use_name_required: blanking an in-use path\'s name is '
    'rejected on the editor\'s own Save',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemoWithSceneUsingBluePath(harness);

      await harness.pumpApp(tester);
      await openPaths(tester);

      await tester.tap(find.byKey(const ValueKey('path.tile.blue')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('game.paths.edit.field.name')),
            )
            .controller!
            .text,
        'Old route',
      );

      await tester.enterText(
        find.byKey(const ValueKey('game.paths.edit.field.name')),
        '',
      );
      await tester.pumpAndSettle();

      // Dirty (blank differs from "Old route"), so Save is enabled — the block
      // happens on tap, not by disabling the button.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('game.paths.edit.save')),
            )
            .enabled,
        isTrue,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('game.paths.edit.save')),
      );
      await tester.tap(find.byKey(const ValueKey('game.paths.edit.save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('paths.name.required.dialog')),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('paths.name.required.ok')));
      await tester.pumpAndSettle();

      // Rejected: nothing written, still on the edit form with the blank field.
      expect(
        readPaths(harness).firstWhere((p) => p['color'] == 'blue')['name'],
        'Old route',
      );
      expect(
        find.byKey(const ValueKey('game.paths.edit.field.name')),
        findsOne,
      );
    },
  );

  testWidgets(
    'BRANCH path_in_use_name_required: the rail guard\'s Save is rejected '
    'the same way',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemoWithSceneUsingBluePath(harness);

      await harness.pumpApp(tester);
      await openPaths(tester);

      await tester.tap(find.byKey(const ValueKey('path.tile.blue')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.paths.edit.field.name')),
        '',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('paths.name.required.dialog')),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('paths.name.required.ok')));
      await tester.pumpAndSettle();

      // Rejected: navigation aborted, still on Paths with nothing written.
      expect(selectedIndex(tester), pathsIndex);
      expect(
        readPaths(harness).firstWhere((p) => p['color'] == 'blue')['name'],
        'Old route',
      );
    },
  );
}
