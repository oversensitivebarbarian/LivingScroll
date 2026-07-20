// Integration test: the in-game Publish action (rail trailing) validates
// the adventure and shows the result dialog.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/services/adventure_packager.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> completeMetadata() => {
    'name': 'Demo',
    'system': 'basic',
    'version': '1.0.0',
    'author': 'A',
    'description': 'd',
    'language': 'en',
    'content_warnings': 'none',
    'license': 'x',
  };

  Future<void> seed(
    CreateHarness harness, {
    required List<Object> scenes,
    Map<String, dynamic>? metadata,
    List<Object> keyEvents = const [],
    List<Object> paths = const [],
  }) async {
    final dir = Directory('${harness.projectsDir.path}/Demo');
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': metadata ?? completeMetadata(),
        'images': [],
        'audio': [],
        'paths': paths,
        'key_events': keyEvents,
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': scenes,
      }),
    );
  }

  Future<void> openGame(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPublish(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.game.publish')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'game_publish: a complete adventure is exported (unpacked) and offers a .ls download',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seed(
        harness,
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'next_scenes': ['s2'],
          },
          {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      // Success dialog with the export message + a .ls download action.
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.dialog.valid.message')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('publish.dialog.download')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.dialog.invalid')),
        findsNothing,
      );

      // The adventure was saved UNPACKED into the Adventures library (a directory
      // with its LivingScroll.json), not as a .ls file.
      final entries = harness.adventuresDir.listSync();
      expect(entries.whereType<Directory>(), hasLength(1));
      expect(
        entries.whereType<File>().where((f) => f.path.endsWith('.ls')),
        isEmpty,
      );
      final unpacked = entries.whereType<Directory>().single;
      expect(unpacked.path, endsWith('Demo'));
      expect(File('${unpacked.path}/LivingScroll.json').existsSync(), isTrue);

      // Download writes the portable .ls to the chosen path; its header round-trips.
      final downloadTo = '${harness.adventuresDir.parent.path}/downloaded.ls';
      harness.saveFilePath = downloadTo;
      await tester.tap(find.byKey(const ValueKey('publish.dialog.download')));
      await tester.pumpAndSettle();

      final lsFile = File(downloadTo);
      expect(lsFile.existsSync(), isTrue);
      final header = const AdventurePackager().readHeader(
        lsFile.readAsBytesSync(),
      );
      expect(header, isNotNull);
      expect(header!['title'], 'Demo');
      expect(header['version'], '1.0.0');
      expect(header['system'], 'basic');
      expect(header['author'], 'A');
      expect(header['language'], 'en');

      await tester.tap(find.byKey(const ValueKey('publish.dialog.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH missing_scenes: an adventure with no start/end scene lists both problems',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seed(harness, scenes: const []);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.issue.noStartScene')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('publish.issue.noEndScene')), findsOne);

      // An invalid adventure is NOT packaged.
      final published = harness.adventuresDir.existsSync()
          ? harness.adventuresDir.listSync()
          : const <FileSystemEntity>[];
      expect(published, isEmpty);

      // Close returns to the game screen.
      await tester.tap(find.byKey(const ValueKey('publish.dialog.close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('publish.dialog.invalid')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('game.root')), findsOne);
    },
  );

  testWidgets(
    'BRANCH scene_graph: end-with-next, only-conditional-next and no-path are each listed',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Start can only reach a conditional scene; End wrongly has a next scene.
      await seed(
        harness,
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Cond',
            'scene_type': 'standard',
            'next_scenes': ['s2'],
            'visibility_rules': {
              'op': 'or',
              'key_events': ['k1'],
            },
          },
          {
            'scene_uuid': 's2',
            'name': 'End',
            'scene_type': 'end',
            'next_scenes': ['s1'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.issue.endSceneHasNext.End')),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey('publish.issue.nonEndSceneOnlyConditionalNext.Start'),
        ),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('publish.issue.noUnconditionalPathToEnd')),
        findsOne,
      );
    },
  );

  testWidgets(
    'BRANCH blind_loop: a next_scenes cycle through a standard scene blocks export',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Start -> A -> B -> A: B loops back to the already-visited standard A.
      await seed(
        harness,
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'A',
            'scene_type': 'standard',
            'next_scenes': ['s4'],
          },
          {
            'scene_uuid': 's4',
            'name': 'B',
            'scene_type': 'standard',
            'next_scenes': ['s3'],
          },
          {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(find.byKey(const ValueKey('publish.issue.blindLoop.A')), findsOne);
      expect(find.byKey(const ValueKey('publish.issue.blindLoop.B')), findsOne);

      // An invalid adventure is NOT exported.
      final published = harness.adventuresDir.existsSync()
          ? harness.adventuresDir.listSync()
          : const <FileSystemEntity>[];
      expect(published, isEmpty);
    },
  );

  testWidgets(
    'BRANCH story_paths: a named path with no route through its OWN scenes '
    'blocks export, even though the adventure-wide graph connects',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // The adventure-wide Start->End route is fine (via the untagged Connector),
      // but "Red Path" tags its own Start/End with a Connector NOT on the path —
      // so the path-scoped route must fail.
      await seed(
        harness,
        paths: const [
          {'name': 'Red Path', 'color': '#D22828', 'description': 'd'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'path_names': ['Red Path'],
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Connector',
            'scene_type': 'standard',
            'next_scenes': ['s2'],
          },
          {
            'scene_uuid': 's2',
            'name': 'End',
            'scene_type': 'end',
            'path_names': ['Red Path'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(
          const ValueKey('publish.issue.pathNoUnconditionalRouteToEnd.#D22828'),
        ),
        findsOne,
      );
      // The path DOES have its own start + end scenes.
      expect(
        find.byKey(const ValueKey('publish.issue.pathNoStartScene.#D22828')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('publish.issue.pathNoEndScene.#D22828')),
        findsNothing,
      );

      final published = harness.adventuresDir.existsSync()
          ? harness.adventuresDir.listSync()
          : const <FileSystemEntity>[];
      expect(published, isEmpty);
    },
  );

  testWidgets(
    'BRANCH story_paths: a named path with no scene tagged onto it reports '
    'both missing start and missing end',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seed(
        harness,
        paths: const [
          {'name': 'Red Path', 'color': '#D22828', 'description': 'd'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'next_scenes': ['s2'],
          },
          {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.issue.pathNoStartScene.#D22828')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('publish.issue.pathNoEndScene.#D22828')),
        findsOne,
      );
    },
  );

  testWidgets(
    'BRANCH story_paths: a named path with a route through its own scenes exports successfully',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seed(
        harness,
        paths: const [
          {'name': 'Red Path', 'color': '#D22828', 'description': 'd'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'path_names': ['Red Path'],
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Mid',
            'scene_type': 'standard',
            'path_names': ['Red Path'],
            'next_scenes': ['s2'],
          },
          {
            'scene_uuid': 's2',
            'name': 'End',
            'scene_type': 'end',
            'path_names': ['Red Path'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.dialog.invalid')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'BRANCH forced_conditional_export: a forced conditional exports successfully',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Start holds the key event "Met duke" and its ONLY next is the gated Cond,
      // so Cond is forced (treated as unconditional) -> the adventure is valid.
      await seed(
        harness,
        keyEvents: const [
          {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'key_events': ['Met duke'],
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Cond',
            'scene_type': 'standard',
            'next_scenes': ['s2'],
            'visibility_rules': {
              'op': 'or',
              'key_events': ['k1'],
            },
          },
          {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      // Valid -> the success dialog (the forced conditional satisfied the graph).
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      expect(
        find.byKey(const ValueKey('publish.dialog.invalid')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'BRANCH metadata: an incomplete adventure setting is listed by field',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final meta = completeMetadata()..remove('license');
      await seed(
        harness,
        metadata: meta,
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Start',
            'scene_type': 'start',
            'next_scenes': ['s2'],
          },
          {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapPublish(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(
          const ValueKey('publish.issue.adventureFieldMissing.license'),
        ),
        findsOne,
      );
    },
  );

  Future<void> tapExportPart(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.game.export_part')));
    await tester.pumpAndSettle();
  }

  List<File> lseTemps(CreateHarness h) => h.exportTmpDir.existsSync()
      ? h.exportTmpDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.lse'))
            .toList()
      : const <File>[];

  testWidgets(
    'BRANCH export_elements: a partial export passes on name+system, offers a .lse download, and deletes the temp on close',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Incomplete for a FULL publish (no scenes) but name + system are present, so
      // the partial export is allowed.
      await seed(harness, scenes: const []);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapExportPart(tester);

      // Success dialog with the elements-specific message + a .lse download action.
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      expect(find.byKey(const ValueKey('publish.dialog.download')), findsOne);
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const ValueKey('publish.dialog.valid'))),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('publish.dialog.valid.message')),
            )
            .data,
        l10n.publishElementsReady,
      );

      // A temp .lse was created (download-only), and nothing was written to the
      // Adventures library.
      expect(lseTemps(harness), hasLength(1));
      final adventures = harness.adventuresDir.existsSync()
          ? harness.adventuresDir.listSync()
          : const <FileSystemEntity>[];
      expect(adventures, isEmpty);

      // Download copies the .lse to the chosen location; choosing a destination
      // DISMISSES the dialog automatically (no Close tap needed).
      final downloadTo = '${harness.adventuresDir.parent.path}/part.lse';
      harness.saveFilePath = downloadTo;
      await tester.tap(find.byKey(const ValueKey('publish.dialog.download')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsNothing);
      final downloaded = File(downloadTo);
      expect(downloaded.existsSync(), isTrue);
      final header = const AdventurePackager().readHeader(
        downloaded.readAsBytesSync(),
      );
      expect(header, isNotNull);
      expect(header!['title'], 'Demo');
      expect(header['system'], 'basic');

      // The auto-close deletes the temp .lse (the downloaded copy persists).
      expect(lseTemps(harness), isEmpty);
      expect(downloaded.existsSync(), isTrue);
    },
  );

  testWidgets(
    'BRANCH export_elements_cancel_keeps_dialog: cancelling the save leaves the dialog open',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seed(harness, scenes: const []);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapExportPart(tester);

      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);

      // Cancel the native save dialog (no destination chosen) -> nothing is saved
      // and the dialog STAYS open.
      harness.saveFilePath = null;
      await tester.tap(find.byKey(const ValueKey('publish.dialog.download')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      expect(
        lseTemps(harness),
        hasLength(1),
      ); // temp still present, not yet closed

      // Closing manually still deletes the temp .lse.
      await tester.tap(find.byKey(const ValueKey('publish.dialog.close')));
      await tester.pumpAndSettle();
      expect(lseTemps(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH export_elements_invalid: a missing system blocks the partial export',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Open a valid adventure (an invalid one renders a non-openable tile)...
      await seed(harness, scenes: const []);
      await harness.pumpApp(tester);
      await openGame(tester);

      // ...then drop `system` from the SAVED file so the partial gate fails when
      // Export elements re-reads it.
      final file = File('${harness.projectsDir.path}/Demo/LivingScroll.json');
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      (doc['metadata'] as Map).remove('system');
      file.writeAsStringSync(jsonEncode(doc));

      await tapExportPart(tester);

      expect(find.byKey(const ValueKey('publish.dialog.invalid')), findsOne);
      expect(
        find.byKey(
          const ValueKey('publish.issue.adventureFieldMissing.system'),
        ),
        findsOne,
      );
      // Nothing was packaged.
      expect(lseTemps(harness), isEmpty);
    },
  );

  // The Adventures-library index lives next to the settings overrides.
  File indexFile(CreateHarness h) =>
      File('${h.settingsDir.path}/adventures.json');

  List<Map> indexEntries(CreateHarness h) =>
      (jsonDecode(indexFile(h).readAsStringSync()) as List).cast<Map>();

  List<Directory> libraryDirs(CreateHarness h) => h.adventuresDir.existsSync()
      ? h.adventuresDir.listSync().whereType<Directory>().toList()
      : const [];

  Future<void> seedComplete(CreateHarness harness) => seed(
    harness,
    scenes: const [
      {
        'scene_uuid': 's1',
        'name': 'Start',
        'scene_type': 'start',
        'next_scenes': ['s2'],
      },
      {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
    ],
  );

  // Exports once, then closes the success dialog. Leaves one library entry.
  Future<void> firstExport(WidgetTester tester) async {
    await tapPublish(tester);
    expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
    await tester.tap(find.byKey(const ValueKey('publish.dialog.close')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'BRANCH library_index: a first export records the adventure in adventures.json',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedComplete(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await firstExport(tester);

      // The index (next to overrides.json) holds one identity entry.
      expect(indexFile(harness).existsSync(), isTrue);
      final entries = indexEntries(harness);
      expect(entries, hasLength(1));
      expect(entries.single['title'], 'Demo');
      expect(entries.single['version'], '1.0.0');
      expect(entries.single['system'], 'basic');
      expect(entries.single['author'], 'A');
      expect(entries.single['language'], 'en');
      // The entry also stores the directory it occupies under {Adventures}.
      expect(entries.single['dir'], isNotNull);
      expect((entries.single['dir'] as String).isNotEmpty, isTrue);
      expect(libraryDirs(harness).single.path, endsWith(entries.single['dir']));
    },
  );

  testWidgets(
    'BRANCH library_duplicate_overwrite: re-exporting prompts Overwrite -> replaces in place',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedComplete(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await firstExport(tester);
      final firstDir = indexEntries(harness).single['dir'];

      // Second export of the SAME adventure -> duplicate dialog.
      await tapPublish(tester);
      expect(find.byKey(const ValueKey('library.duplicate.dialog')), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('library.duplicate.overwrite')),
      );
      await tester.pumpAndSettle();
      // Proceeds to the export success dialog.
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsOne);
      await tester.tap(find.byKey(const ValueKey('publish.dialog.close')));
      await tester.pumpAndSettle();

      // Still exactly ONE library directory + ONE index entry (replaced in place).
      expect(libraryDirs(harness), hasLength(1));
      final entries = indexEntries(harness);
      expect(entries, hasLength(1));
      expect(entries.single['dir'], firstDir);
    },
  );

  testWidgets(
    'BRANCH library_duplicate_cancel: Cancel aborts the re-export (nothing changes)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedComplete(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await firstExport(tester);

      await tapPublish(tester);
      expect(find.byKey(const ValueKey('library.duplicate.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('library.duplicate.cancel')));
      await tester.pumpAndSettle();

      // The dialog closed, NO export happened (no success dialog).
      expect(
        find.byKey(const ValueKey('library.duplicate.dialog')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('publish.dialog.valid')), findsNothing);
      // Library untouched: still one directory, one index entry.
      expect(libraryDirs(harness), hasLength(1));
      expect(indexEntries(harness), hasLength(1));
    },
  );
}
