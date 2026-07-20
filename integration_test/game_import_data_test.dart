// Integration test for importing data from an externally-prepared
// LivingScroll.json into an existing adventure via the Adventure settings
// "Import data" action.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/services/adventure_packager.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory demoDir(CreateHarness h) => Directory('${h.projectsDir.path}/Demo');

  // The target adventure (system "basic") already carrying a "Home" note (the
  // representative plain collection used by these tests).
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
        'notes': [
          {'note_uuid': 'N0', 'note_name': 'Home', 'note_content': ''},
        ],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
  }

  // A self-contained import-source adventure document. Carries one of every
  // linked category, an image with a real file, and a scene linking them all
  // plus a next_scenes entry.
  Map<String, dynamic> importDoc({String system = 'basic'}) => {
    'metadata': {
      'name': 'Pack',
      'system': system,
      'version': '1.0.0',
      'author': 'B',
      'description': 'd',
      'language': 'en',
      'content_warnings': 'none',
      'license': 'x',
    },
    'images': [
      {'image_uuid': 'i1', 'name': 'Map'},
    ],
    'audio': [],
    'paths': [
      {'name': 'Main', 'color': 'yellow', 'description': ''},
    ],
    'key_events': [
      {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
    ],
    'notes': [
      {'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': 'x'},
    ],
    'gm_notes': [],
    'npcs': [
      {'npc_uuid': 'P1', 'name': 'Guard'},
    ],
    'scenes': [
      {
        'scene_uuid': 's1',
        'name': 'Cave scene',
        'scene_type': 'standard',
        'bg_image': 'bg1',
        'npcs': ['Guard'],
        'key_events': ['Met duke'],
        'path_names': ['Main'],
        'next_scenes': ['ghost-uuid'],
      },
    ],
  };

  // Packs [doc] (+ a real image file under images/other/i1.png) into a portable
  // archive under [root], with the given extension (`ls` full / `lse` elements),
  // and returns the archive path — exactly what the Import picker now returns.
  Future<String> writeImportArchive(
    Directory root, {
    Map<String, dynamic>? doc,
    String ext = 'ls',
    bool withImage = true,
  }) async {
    final adv = Directory('${root.path}/adv');
    if (withImage) {
      final otherDir = Directory('${adv.path}/images/other');
      await otherDir.create(recursive: true);
      await File(
        CreateHarness.asset('cover_sample.jpg'),
      ).copy('${otherDir.path}/i1.png');
      // The scene's background image file (images/bg_images/bg1.png).
      final bgDir = Directory('${adv.path}/images/bg_images');
      await bgDir.create(recursive: true);
      await File(
        CreateHarness.asset('cover_sample.jpg'),
      ).copy('${bgDir.path}/bg1.png');
    } else {
      await adv.create(recursive: true);
    }
    final body = doc ?? importDoc();
    await File('${adv.path}/LivingScroll.json').writeAsString(jsonEncode(body));
    final bytes = const AdventurePackager().pack(
      sourceDir: adv,
      header: AdventurePackager.headerFromMetadata(body['metadata']),
    );
    final archive = File('${root.path}/Pack.$ext');
    await archive.writeAsBytes(bytes);
    return archive.path;
  }

  Map<String, dynamic> readDemo(CreateHarness h) =>
      jsonDecode(
            File('${demoDir(h).path}/LivingScroll.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map> coll(Map<String, dynamic> doc, String key) =>
      (doc[key] as List).cast<Map>();

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav.game.settings')));
    await tester.pumpAndSettle();
  }

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('game_import_data: select all -> merges, preserves uuids, '
      'strips next_scenes, keeps valid links', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
    addTearDown(() => srcRoot.delete(recursive: true));
    harness.archivePath = await writeImportArchive(srcRoot);

    await harness.pumpApp(tester);
    await openSettings(tester);

    // Open the import-selection dialog (valid file).
    await tester.tap(find.byKey(const ValueKey('game.settings.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import.dialog')), findsOne);
    // Each present category is a group header...
    for (final c in [
      'notes',
      'npcs',
      'key_events',
      'paths',
      'scenes',
      'images',
    ]) {
      expect(
        find.byKey(ValueKey('import.dialog.group.$c')),
        findsOne,
        reason: 'category $c should be a group',
      );
    }
    // ...and every individual element has its own checkbox.
    for (final k in [
      'notes.N1',
      'npcs.P1',
      'key_events.k1',
      'paths.yellow',
      'scenes.s1',
      'images.i1',
    ]) {
      expect(
        find.byKey(ValueKey('import.dialog.item.$k')),
        findsOne,
        reason: 'element $k should have a checkbox',
      );
    }
    // Nothing written until Import.
    expect(coll(readDemo(harness), 'scenes'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import.dialog')), findsNothing);
    expect(find.byKey(const ValueKey('game.settings.import.done')), findsOne);

    final doc = readDemo(harness);
    // Plain collections merged, uuids preserved.
    expect(coll(doc, 'notes').map((e) => e['note_uuid']), ['N0', 'N1']);
    expect(coll(doc, 'npcs').single['npc_uuid'], 'P1');
    expect(coll(doc, 'key_events').single['key_event_uuid'], 'k1');
    expect(coll(doc, 'paths').single['name'], 'Main');
    // Related media copied for the imported image.
    expect(
      File('${demoDir(harness).path}/images/other/i1.png').existsSync(),
      isTrue,
    );
    // Scene: uuid kept, next_scenes dropped, all links survived (their targets
    // were imported in the same operation).
    final scene = coll(doc, 'scenes').single;
    expect(scene['scene_uuid'], 's1');
    expect(scene.containsKey('next_scenes'), isFalse);
    // bg_image is a file reference, kept verbatim; its file is copied alongside
    // the scene into images/bg_images/.
    expect(scene['bg_image'], 'bg1');
    expect(
      File('${demoDir(harness).path}/images/bg_images/bg1.png').existsSync(),
      isTrue,
    );
    expect(scene['npcs'], ['Guard']);
    expect(scene['key_events'], ['Met duke']);
    expect(scene['path_names'], ['Main']);
  });

  testWidgets(
    'BRANCH invalid_schema: an invalid archive is rejected, no dialog',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      // A well-formed archive whose LivingScroll.json fails PUBLISHED validation
      // (incomplete metadata — only name + system, missing the rest).
      harness.archivePath = await writeImportArchive(
        srcRoot,
        doc: {
          'metadata': {'name': 'Bad', 'system': 'basic'},
          'notes': [],
        },
        withImage: false,
      );

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import.dialog')), findsNothing);
      expect(
        find.byKey(const ValueKey('game.settings.import.error')),
        findsOne,
      );
      expect(coll(readDemo(harness), 'notes').length, 1); // unchanged
    },
  );

  testWidgets(
    'BRANCH different_system_excludes_npcs: NPCs from a different system are not listed',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.archivePath = await writeImportArchive(
        srcRoot,
        doc: importDoc(system: '7thsea2e'),
      );

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // The npcs group/element is skipped entirely (not shown).
      expect(
        find.byKey(const ValueKey('import.dialog.group.npcs')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('import.dialog.item.npcs.P1')),
        findsNothing,
      );
      // Other categories are still offered.
      expect(
        find.byKey(const ValueKey('import.dialog.item.notes.N1')),
        findsOne,
      );

      await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
      await tester.pumpAndSettle();

      final doc = readDemo(harness);
      expect(coll(doc, 'npcs'), isEmpty); // excluded across systems
      expect(coll(doc, 'notes').length, 2); // other categories still imported
    },
  );

  testWidgets(
    'BRANCH scene_links_pruned: importing only scenes drops links to absent elements',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.archivePath = await writeImportArchive(srcRoot);

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // Uncheck every non-scene element, leaving only the scene selected.
      for (final k in [
        'notes.N1',
        'npcs.P1',
        'key_events.k1',
        'paths.yellow',
        'images.i1',
      ]) {
        final f = find.byKey(ValueKey('import.dialog.item.$k'));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
      await tester.pumpAndSettle();

      final doc = readDemo(harness);
      expect(coll(doc, 'notes').length, 1); // only pre-existing "Home"
      expect(coll(doc, 'npcs'), isEmpty);
      final scene = coll(doc, 'scenes').single;
      expect(scene.containsKey('next_scenes'), isFalse);
      // bg_image is a file reference (not a collection link), so it is kept even
      // when nothing else is imported; its file travels with the scene.
      expect(scene['bg_image'], 'bg1');
      expect(
        File('${demoDir(harness).path}/images/bg_images/bg1.png').existsSync(),
        isTrue,
      );
      expect(scene['npcs'], isEmpty);
      expect(scene['key_events'], isEmpty);
      expect(scene['path_names'], isEmpty);
    },
  );

  testWidgets('BRANCH cancel: Cancel imports nothing', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
    addTearDown(() => srcRoot.delete(recursive: true));
    harness.archivePath = await writeImportArchive(srcRoot);

    await harness.pumpApp(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const ValueKey('game.settings.import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import.dialog.cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import.dialog')), findsNothing);

    final doc = readDemo(harness);
    expect(coll(doc, 'scenes'), isEmpty);
    expect(coll(doc, 'notes').length, 1);
  });

  testWidgets(
    'BRANCH lse_archive: an elements (.lse) archive is also imported',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      // The Import picker accepts `.lse` (elements export) as well as `.ls`.
      harness.archivePath = await writeImportArchive(srcRoot, ext: 'lse');

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import.dialog')), findsOne);

      await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.settings.import.done')), findsOne);

      final doc = readDemo(harness);
      expect(coll(doc, 'notes').map((e) => e['note_uuid']), ['N0', 'N1']);
      // Related media from inside the archive was unpacked and copied.
      expect(
        File('${demoDir(harness).path}/images/other/i1.png').existsSync(),
        isTrue,
      );
    },
  );

  testWidgets(
    'BRANCH lse_project_level: a .lse with only name + system passes (PROJECT level)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      // The SAME incomplete metadata that a `.ls` rejects is accepted as a `.lse`:
      // the elements pack validates at PROJECT level (name + system only).
      harness.archivePath = await writeImportArchive(
        srcRoot,
        ext: 'lse',
        withImage: false,
        doc: {
          'metadata': {'name': 'Mini', 'system': 'basic'},
          'notes': [
            {'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': 'x'},
          ],
        },
      );

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // Accepted -> the selection dialog opens, no validation error.
      expect(find.byKey(const ValueKey('import.dialog')), findsOne);
      expect(
        find.byKey(const ValueKey('game.settings.import.error')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'BRANCH lse_missing_system: a .lse missing system still fails PROJECT validation',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.archivePath = await writeImportArchive(
        srcRoot,
        ext: 'lse',
        withImage: false,
        doc: {
          'metadata': {'name': 'Mini'}, // no system
          'notes': [],
        },
      );

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import.dialog')), findsNothing);
      expect(
        find.byKey(const ValueKey('game.settings.import.error')),
        findsOne,
      );
      expect(coll(readDemo(harness), 'notes').length, 1); // unchanged
    },
  );

  testWidgets(
    'BRANCH select_one_element: importing ONE element from a multi-element .lse '
    'imports only that element',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      // The archive carries one of every category (notes, npcs, key_events,
      // paths, images, scenes — see importDoc()).
      harness.archivePath = await writeImportArchive(srcRoot);

      await harness.pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // Deselect EVERYTHING except a single note element (notes.N1).
      for (final k in [
        'npcs.P1',
        'key_events.k1',
        'paths.yellow',
        'images.i1',
        'scenes.s1',
      ]) {
        final f = find.byKey(ValueKey('import.dialog.item.$k'));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.settings.import.done')), findsOne);

      // Only the one selected note was imported; every other category is empty.
      final doc = readDemo(harness);
      expect(coll(doc, 'notes').map((e) => e['note_uuid']), ['N0', 'N1']);
      expect(coll(doc, 'npcs'), isEmpty);
      expect(coll(doc, 'key_events'), isEmpty);
      expect(coll(doc, 'paths'), isEmpty);
      expect(coll(doc, 'images'), isEmpty);
      expect(coll(doc, 'scenes'), isEmpty);
      // The unselected image's media file was NOT copied.
      expect(
        File('${demoDir(harness).path}/images/other/i1.png').existsSync(),
        isFalse,
      );
    },
  );

  // Seeds {Projects}/Demo with the given collections already present.
  Future<void> seedDemoWith(
    CreateHarness harness,
    Map<String, dynamic> collections,
  ) async {
    await demoDir(harness).create(recursive: true);
    final doc = <String, dynamic>{
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
      'images': <dynamic>[],
      'audio': <dynamic>[],
      'paths': <dynamic>[],
      'key_events': <dynamic>[],
      'notes': <dynamic>[],
      'gm_notes': <dynamic>[],
      'npcs': <dynamic>[],
      'scenes': <dynamic>[],
    };
    collections.forEach((k, v) => doc[k] = v);
    await File(
      '${demoDir(harness).path}/LivingScroll.json',
    ).writeAsString(jsonEncode(doc));
  }

  testWidgets(
    'BRANCH existing_uuid_skipped: an element already in the target is not listed',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Demo ALREADY contains the import's note N1.
      await seedDemoWith(harness, {
        'notes': [
          {'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': 'x'},
        ],
      });

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.archivePath = await writeImportArchive(srcRoot);

      await harness.pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // N1 already exists -> the notes group/element is absent.
      expect(
        find.byKey(const ValueKey('import.dialog.group.notes')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('import.dialog.item.notes.N1')),
        findsNothing,
      );
      // A not-yet-present element is still listed.
      expect(
        find.byKey(const ValueKey('import.dialog.item.npcs.P1')),
        findsOne,
      );
    },
  );

  testWidgets(
    'BRANCH nothing_to_import: empty-state message when everything already exists',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Demo already carries EVERY element the import file holds (same uuids).
      final imp = importDoc();
      await seedDemoWith(harness, {
        for (final c in const [
          'images',
          'audio',
          'paths',
          'key_events',
          'notes',
          'npcs',
          'scenes',
        ])
          c: imp[c],
      });

      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.archivePath = await writeImportArchive(srcRoot);

      await harness.pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('game.settings.import')));
      await tester.pumpAndSettle();
      // Nothing importable -> the empty-state note; no list, no Import button.
      expect(find.byKey(const ValueKey('import.dialog')), findsOne);
      expect(find.byKey(const ValueKey('import.dialog.empty')), findsOne);
      expect(find.byKey(const ValueKey('import.dialog.list')), findsNothing);
      expect(find.byKey(const ValueKey('import.dialog.import')), findsNothing);

      // Closing it changes nothing.
      await tester.tap(find.byKey(const ValueKey('import.dialog.cancel')));
      await tester.pumpAndSettle();
      expect(coll(readDemo(harness), 'notes').length, 1);
    },
  );
}
