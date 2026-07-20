// PATH: open adventure -> game -> Adventure settings -> edit metadata -> Save
// EFFECT: the existing {Projects}/Demo/LivingScroll.json is rewritten in place
// (metadata replaced, other collections preserved); branches cover saving a new
// cover and the three unsaved-changes choices when leaving the section.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Scenes is the default in-game content section (index 2; Adventure settings
  // is index 1, Home is 0).
  const scenesIndex = 2;
  const settingsIndex = 1;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

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
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        // One existing scene — asserted preserved across an in-place Save.
        'scenes': [
          {'id': 's1'},
        ],
      }),
    );
  }

  // STEP 1-2: open the seeded adventure and switch to Adventure settings.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.settings')));
    await tester.pumpAndSettle();
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  Map<String, dynamic> readDemo(CreateHarness harness) =>
      jsonDecode(
            File(
              '${demoDir(harness).path}/LivingScroll.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  testWidgets('game_adventure_settings: edit metadata -> rewrite in place', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openSettings(tester);

    // STEP 2: the form is shown, pre-filled from the document.
    expect(find.byKey(const ValueKey('game.settings.root')), findsOne);
    expect(selectedIndex(tester), settingsIndex);
    final title = tester.widget<TextField>(
      find.byKey(const ValueKey('game.settings.field.title')),
    );
    expect(title.controller!.text, 'Demo');

    // The Import data button carries the Material upload_file glyph (the
    // import-a-file-from-device convention), not the plain file_upload arrow.
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('game.settings.import')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.upload_file_outlined,
    );

    // STEP 3: edit the title.
    await tester.enterText(
      find.byKey(const ValueKey('game.settings.field.title')),
      'Demo Edited',
    );
    await tester.pumpAndSettle();

    // STEP 4: Save -> file rewritten in place, scenes preserved, back to Scenes.
    await tester.ensureVisible(
      find.byKey(const ValueKey('game.settings.save')),
    );
    await tester.tap(find.byKey(const ValueKey('game.settings.save')));
    await tester.pumpAndSettle();

    final doc = readDemo(harness);
    expect(doc['metadata']['name'], 'Demo Edited');
    expect((doc['scenes'] as List).length, 1);
    expect(File('${demoDir(harness).path}/cover.jpg').existsSync(), isFalse);
    expect(selectedIndex(tester), scenesIndex);

    // Exactly one project dir — nothing was created.
    expect(harness.projects().length, 1);
  });

  testWidgets(
    'BRANCH system_immutable: System is pre-filled, disabled and preserved',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openSettings(tester);

      // Pre-filled with the adventure's system, shown by its display name.
      expect(find.text('Basic RPG'), findsOne);

      // Disabled: metadata.system is immutable after creation, so the dropdown
      // is non-interactive (onChanged == null).
      final dropdown = tester.widget<DropdownButtonFormField<String?>>(
        find.byKey(const ValueKey('game.settings.field.system')),
      );
      expect(dropdown.onChanged, isNull);

      // Tapping a disabled dropdown opens nothing — no alternative option appears.
      await tester.tap(
        find.byKey(const ValueKey('game.settings.field.system')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('game.settings.field.system.item.7thsea2e'),
        ),
        findsNothing,
      );

      // An unrelated edit + Save preserves the original system unchanged.
      await tester.enterText(
        find.byKey(const ValueKey('game.settings.field.title')),
        'Demo Edited',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('game.settings.save')),
      );
      await tester.tap(find.byKey(const ValueKey('game.settings.save')));
      await tester.pumpAndSettle();

      final doc = readDemo(harness);
      expect(doc['metadata']['name'], 'Demo Edited');
      expect(doc['metadata']['system'], 'basic'); // never editable
    },
  );

  testWidgets('BRANCH new_cover: saving a cropped cover writes cover.jpg', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openSettings(tester);

    // Pick a cover -> crop dialog (shared cover-crop component) -> confirm.
    await tester.tap(find.byKey(const ValueKey('game.settings.cover')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create_new.cover.crop')), findsOne);
    await tester.tap(
      find.byKey(const ValueKey('create_new.cover.crop.confirm')),
    );
    await tester.pumpAndSettle();

    // Not written until Save.
    expect(File('${demoDir(harness).path}/cover.jpg').existsSync(), isFalse);

    await tester.ensureVisible(
      find.byKey(const ValueKey('game.settings.save')),
    );
    await tester.tap(find.byKey(const ValueKey('game.settings.save')));
    await tester.pumpAndSettle();

    final cover = File('${demoDir(harness).path}/cover.jpg');
    expect(cover.existsSync(), isTrue);
    final bytes = cover.readAsBytesSync();
    expect([bytes[0], bytes[1], bytes[2]], [0xFF, 0xD8, 0xFF]); // JPEG magic
    final decoded = img.decodeImage(bytes)!;
    expect(decoded.width, 1000);
    expect(decoded.height, 1430);
  });

  testWidgets('BRANCH unsaved_save: leaving with edits -> Save persists', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openSettings(tester);

    await tester.enterText(
      find.byKey(const ValueKey('game.settings.field.title')),
      'Demo Edited',
    );
    await tester.pumpAndSettle();

    // Try to leave the section -> unsaved prompt -> Save.
    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(readDemo(harness)['metadata']['name'], 'Demo Edited');
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets(
    'BRANCH unsaved_abandon: leaving with edits -> Discard drops them',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.enterText(
        find.byKey(const ValueKey('game.settings.field.title')),
        'Demo Edited',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
      await tester.pumpAndSettle();

      // Edit dropped: the file is unchanged, and we proceed to Scenes.
      expect(readDemo(harness)['metadata']['name'], 'Demo');
      expect(selectedIndex(tester), scenesIndex);
    },
  );

  testWidgets('BRANCH unsaved_cancel: leaving with edits -> Cancel stays', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openSettings(tester);

    await tester.enterText(
      find.byKey(const ValueKey('game.settings.field.title')),
      'Demo Edited',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
    await tester.pumpAndSettle();

    // Stayed on the settings section; nothing written.
    expect(find.byKey(const ValueKey('game.settings.root')), findsOne);
    expect(selectedIndex(tester), settingsIndex);
    expect(readDemo(harness)['metadata']['name'], 'Demo');
  });
}
