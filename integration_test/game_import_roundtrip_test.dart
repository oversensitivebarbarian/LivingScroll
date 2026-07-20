// Integration test for a full export→import
// round trip per element type. For each content kind (notes, soundtrack,
// images, key events, notes, scenes) it:
//   1. seeds a SOURCE adventure (only name + system in metadata) carrying exactly
//      ONE element of that kind (+ its media file, for images/audio),
//   2. exports it as a `.lse` (the in-game "Export elements" action),
//   3. opens a fresh EMPTY target adventure and imports that `.lse`,
//   4. asserts the element appears EXACTLY ONCE — both in the target's
//      LivingScroll.json and in the app's list for that section.
//
// Importing into an empty adventure must NOT duplicate (no uuid collision), so
// every count is 1. This is the baseline that guards the import against the
// "everything doubled" regression.
//
// The last test ("re-import: the same .lse offers nothing …") imports once, then
// re-opens the import for the same archive and asserts the empty-state: the
// element's uuid is now in the target, so analyze pre-filters it out and there is
// nothing left to import. Re-importing an overlapping pack therefore can't
// duplicate (the importer also dedups by uuid as a second line of defence).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/widgets/event_tile.dart';
import 'package:living_scroll/widgets/image_tile.dart';
import 'package:living_scroll/widgets/note_tile.dart';
import 'package:living_scroll/widgets/scene_tile.dart';
import 'package:living_scroll/widgets/soundtrack_tile.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A media file to seed alongside the source adventure: a repo asset copied to
  // [rel] (a path relative to the adventure dir).
  // ({String rel, String asset}) records keep the call sites terse.

  // Seeds {Projects}/<name>/LivingScroll.json with only name + system in metadata
  // (the user's "tylko nazwa i system") and [content] merged over empty sibling
  // collections. Also writes any [media] files under the adventure dir.
  Future<void> seedAdventure(
    CreateHarness harness,
    String name, {
    Map<String, dynamic> content = const {},
    List<({String rel, String asset})> media = const [],
  }) async {
    final dir = Directory('${harness.projectsDir.path}/$name');
    await dir.create(recursive: true);
    final doc = <String, dynamic>{
      'metadata': {'name': name, 'system': 'basic'},
      'images': <dynamic>[],
      'audio': <dynamic>[],
      'paths': <dynamic>[],
      'key_events': <dynamic>[],
      'notes': <dynamic>[],
      'gm_notes': <dynamic>[],
      'npcs': <dynamic>[],
      'scenes': <dynamic>[],
    };
    content.forEach((k, v) => doc[k] = v);
    await File('${dir.path}/LivingScroll.json').writeAsString(jsonEncode(doc));
    for (final m in media) {
      final f = File('${dir.path}/${m.rel}');
      await f.parent.create(recursive: true);
      await File(CreateHarness.asset(m.asset)).copy(f.path);
    }
  }

  Map<String, dynamic> readDoc(CreateHarness h, String name) =>
      jsonDecode(
            File(
              '${h.projectsDir.path}/$name/LivingScroll.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  // Runs the whole scenario for one element kind. The exported `.lse` is imported
  // into the (initially empty) target; the element must then be present exactly
  // once, both in LivingScroll.json and in the section list. [tileFinder] counts
  // the displayed tiles. When [reimportShowsEmpty] is set, the import dialog is
  // reopened afterwards and asserted to show the empty-state (the element now
  // already exists, so there is nothing left to import).
  Future<void> runScenario(
    WidgetTester tester, {
    required String collection, // LivingScroll.json key (e.g. 'notes')
    required Map<String, dynamic> element,
    required String navKey, // e.g. 'nav.game.notes'
    required String listKey, // e.g. 'note.list'
    required Finder tileFinder, // e.g. find.byType(NoteTile)
    List<({String rel, String asset})> media = const [],
    bool reimportShowsEmpty = false,
  }) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await seedAdventure(
      harness,
      'Source',
      content: {
        collection: [element],
      },
      media: media,
    );
    await seedAdventure(harness, 'Target'); // empty

    await harness.pumpApp(tester);

    // 1) Open Source and export its elements as a `.lse` to a known path.
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Source')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav.game.export_part')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);

    final lsePath = '${harness.adventuresDir.parent.path}/$collection.lse';
    harness.saveFilePath = lsePath;
    await tester.tap(find.byKey(const ValueKey('publish.dialog.download')));
    await tester.pumpAndSettle();
    expect(File(lsePath).existsSync(), isTrue, reason: 'exported .lse written');

    // Leave the game view (Home), then open the empty Target adventure.
    await tester.tap(find.byKey(const ValueKey('nav.game.home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Target')));
    await tester.pumpAndSettle();

    // 2) Import the exported `.lse` into the empty Target.
    await tester.tap(find.byKey(const ValueKey('nav.game.settings')));
    await tester.pumpAndSettle();
    harness.archivePath = lsePath;
    await tester.tap(find.byKey(const ValueKey('game.settings.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.settings.import.done')), findsOne);
    // Let the confirmation SnackBar time out so it never overlaps a later tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Optionally: re-opening the import now offers NOTHING (already imported).
    if (reimportShowsEmpty) {
      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import.dialog')), findsOne);
      expect(find.byKey(const ValueKey('import.dialog.empty')), findsOne);
      expect(find.byKey(const ValueKey('import.dialog.import')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('import.dialog.cancel')));
      await tester.pumpAndSettle();
    }

    // 3a) The Target's LivingScroll.json carries the element EXACTLY ONCE.
    expect(
      (readDoc(harness, 'Target')[collection] as List).length,
      1,
      reason: '$collection count in Target/LivingScroll.json after import',
    );

    // 3b) The app displays the element EXACTLY ONCE in that section.
    await tester.tap(find.byKey(ValueKey(navKey)));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(listKey)), findsOne);
    expect(
      tileFinder,
      findsNWidgets(1),
      reason: '$collection displayed count after import',
    );
  }

  testWidgets('round-trip soundtrack: imported once, shown once', (
    tester,
  ) async {
    await runScenario(
      tester,
      collection: 'audio',
      element: const {'audio_uuid': 'a1', 'name': 'Intro Theme'},
      media: const [
        (
          rel: 'audio/a1.mp3',
          asset: 'audiopapkin-dark-atmosphere-background-007-312379.mp3',
        ),
      ],
      navKey: 'nav.game.soundtracks',
      listKey: 'sound.list',
      tileFinder: find.byType(SoundtrackTile),
    );
  });

  testWidgets('round-trip images: imported once, shown once', (tester) async {
    await runScenario(
      tester,
      collection: 'images',
      element: const {'image_uuid': 'i1', 'name': 'Map'},
      media: const [(rel: 'images/other/i1.png', asset: 'cover_sample.jpg')],
      navKey: 'nav.game.images',
      listKey: 'image.grid',
      tileFinder: find.byType(ImageTile),
    );
  });

  testWidgets('round-trip key events: imported once, shown once', (
    tester,
  ) async {
    await runScenario(
      tester,
      collection: 'key_events',
      element: const {
        'key_event_uuid': 'k1',
        'name': 'Met the duke',
        'state': 'unchecked',
      },
      navKey: 'nav.game.keyevents',
      listKey: 'event.list',
      tileFinder: find.byType(EventTile),
    );
  });

  testWidgets('round-trip notes: imported once, shown once', (tester) async {
    await runScenario(
      tester,
      collection: 'notes',
      element: const {
        'note_uuid': 'n1',
        'note_name': 'Intro',
        'note_content': 'c',
      },
      navKey: 'nav.game.notes',
      listKey: 'note.list',
      tileFinder: find.byType(NoteTile),
    );
  });

  testWidgets('round-trip scenes: imported once, shown once', (tester) async {
    await runScenario(
      tester,
      collection: 'scenes',
      element: const {
        'scene_uuid': 's1',
        'name': 'Start',
        'scene_type': 'start',
      },
      navKey: 'nav.game.scenes',
      listKey: 'scene.list',
      tileFinder: find.byType(SceneTile),
    );
  });

  // Regression guard. After importing once, re-opening the import for the SAME
  // `.lse` offers NOTHING: the element's uuid is now in the target, so it is
  // pre-filtered out and the dialog shows the empty-state. The element therefore
  // stays a single entry — re-import cannot duplicate it.
  testWidgets('re-import: the same .lse offers nothing the second time', (
    tester,
  ) async {
    await runScenario(
      tester,
      collection: 'notes',
      element: const {
        'note_uuid': 'N1',
        'note_name': 'Cave',
        'note_content': 'x',
      },
      navKey: 'nav.game.notes',
      listKey: 'note.list',
      tileFinder: find.byType(NoteTile),
      reimportShowsEmpty: true,
    );
  });
}
