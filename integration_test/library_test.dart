// Integration test: the Library destination is a 4-tab
// browser (DefaultTabController length 4) over the user-files roots that hold
// adventures: Adventures / Saves / Projects / Finished. Each tab lists its
// directory and presents one AdventureTile per adventure. Browse-only.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/screens/adventure_tile.dart';
import 'package:living_scroll/services/adventure_packager.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Writes a valid adventure (name + supported system) at <dir>/<slug>/.
  Future<void> seedAdventure(Directory dir, String slug, String name) async {
    final adv = Directory('${dir.path}/$slug');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {'name': name, 'system': 'basic'},
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
  }

  // Opens a tile's context menu and taps one of its items (clone | delete).
  Future<void> openTileMenu(
    WidgetTester tester,
    String slug,
    String item,
  ) async {
    await tester.tap(find.byKey(ValueKey('adventure.tile.menu.$slug')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('adventure.tile.menu.$slug.item.$item')),
    );
    await tester.pumpAndSettle();
  }

  // A full-metadata adventure document (so a `.ls` passes PUBLISHED validation).
  Map<String, dynamic> fullDoc({String name = 'Pack'}) => {
    'metadata': {
      'name': name,
      'system': 'basic',
      'version': '1.0.0',
      'author': 'A',
      'description': 'd',
      'language': 'en',
      'content_warnings': 'none',
      'license': 'x',
    },
    'images': [
      {'image_uuid': 'i1', 'name': 'Map'},
    ],
    'audio': [],
    'paths': [],
    'key_events': [],
    'notes': [],
    'gm_notes': [],
    'npcs': [],
    'scenes': [],
  };

  // Packs [doc] (+ an image at images/other/i1.png) into a `.ls` under [root].
  Future<String> writeLs(
    Directory root, {
    Map<String, dynamic>? doc,
    bool withImage = true,
  }) async {
    final adv = Directory('${root.path}/adv');
    if (withImage) {
      final od = Directory('${adv.path}/images/other');
      await od.create(recursive: true);
      await File(
        CreateHarness.asset('cover_sample.jpg'),
      ).copy('${od.path}/i1.png');
    } else {
      await adv.create(recursive: true);
    }
    final body = doc ?? fullDoc();
    await File('${adv.path}/LivingScroll.json').writeAsString(jsonEncode(body));
    final bytes = const AdventurePackager().pack(
      sourceDir: adv,
      header: AdventurePackager.headerFromMetadata(body['metadata']),
    );
    final file = File('${root.path}/Pack.ls');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  List<Map> indexEntries(CreateHarness h) {
    final f = File('${h.settingsDir.path}/adventures.json');
    return f.existsSync()
        ? (jsonDecode(f.readAsStringSync()) as List).cast<Map>()
        : const [];
  }

  testWidgets(
    'library import: the Adventures grid leads with an import tile that imports a .ls',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final srcRoot = await Directory.systemTemp.createTemp('ls_lib_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.lsPath = await writeLs(srcRoot);

      await harness.pumpApp(tester);
      await openLibrary(tester);

      // The first Adventures cell is the import tile; no Pack tile yet.
      expect(find.byKey(const ValueKey('library.adventures.import')), findsOne);
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('library.adventures.import')));
      await tester.pumpAndSettle();

      // Confirmation, unpacked into {Adventures}, indexed, and the grid refreshed.
      expect(find.byKey(const ValueKey('library.import.done')), findsOne);
      expect(
        Directory('${harness.adventuresDir.path}/Pack').existsSync(),
        isTrue,
      );
      expect(
        File(
          '${harness.adventuresDir.path}/Pack/images/other/i1.png',
        ).existsSync(),
        isTrue,
      );
      final entries = indexEntries(harness);
      expect(entries, hasLength(1));
      expect(entries.single['title'], 'Pack');
      // The entry stores the directory the adventure was unpacked into.
      expect(entries.single['dir'], 'Pack');
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsOne);
    },
  );

  // Imports Pack.ls once (added), leaving the grid on the Adventures tab.
  Future<void> importOnce(WidgetTester tester, CreateHarness harness) async {
    await tester.tap(find.byKey(const ValueKey('library.adventures.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.import.done')), findsOne);
  }

  testWidgets(
    'library import: a duplicate prompts the SAME Overwrite/Cancel dialog as Export -> Overwrite replaces',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final srcRoot = await Directory.systemTemp.createTemp('ls_lib_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.lsPath = await writeLs(srcRoot);

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await importOnce(tester, harness);
      final firstDir = indexEntries(harness).single['dir'];

      // Importing the SAME archive again -> the shared duplicate dialog.
      await tester.tap(find.byKey(const ValueKey('library.adventures.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library.duplicate.dialog')), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('library.duplicate.overwrite')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library.import.done')), findsOne);

      // Replaced in place: still exactly one directory + one index entry.
      expect(
        harness.adventuresDir.listSync().whereType<Directory>(),
        hasLength(1),
      );
      final entries = indexEntries(harness);
      expect(entries, hasLength(1));
      expect(entries.single['dir'], firstDir);
    },
  );

  testWidgets(
    'library import: a duplicate dialog Cancel aborts (nothing changes)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final srcRoot = await Directory.systemTemp.createTemp('ls_lib_');
      addTearDown(() => srcRoot.delete(recursive: true));
      harness.lsPath = await writeLs(srcRoot);

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await importOnce(tester, harness);

      await tester.tap(find.byKey(const ValueKey('library.adventures.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library.duplicate.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('library.duplicate.cancel')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library.duplicate.dialog')),
        findsNothing,
      );

      // Library untouched.
      expect(
        harness.adventuresDir.listSync().whereType<Directory>(),
        hasLength(1),
      );
      expect(indexEntries(harness), hasLength(1));
    },
  );

  testWidgets('library import: an invalid .ls is rejected', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final srcRoot = await Directory.systemTemp.createTemp('ls_lib_');
    addTearDown(() => srcRoot.delete(recursive: true));
    // Incomplete metadata -> fails PUBLISHED validation.
    harness.lsPath = await writeLs(
      srcRoot,
      withImage: false,
      doc: {
        'metadata': {'name': 'Bad', 'system': 'basic'},
      },
    );

    await harness.pumpApp(tester);
    await openLibrary(tester);

    await tester.tap(find.byKey(const ValueKey('library.adventures.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.import.invalid')), findsOne);
    expect(indexEntries(harness), isEmpty);
    expect(
      Directory('${harness.adventuresDir.path}/Bad').existsSync(),
      isFalse,
    );
  });

  testWidgets('library: four tabs, each lists its own directory', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // One distinct adventure in each of the four roots.
    await seedAdventure(harness.adventuresDir, 'AdvOne', 'Adv One');
    await seedAdventure(harness.savesDir, 'SaveOne', 'Save One');
    await seedAdventure(harness.projectsDir, 'ProjOne', 'Proj One');
    await seedAdventure(harness.finishedDir, 'FinOne', 'Fin One');

    await harness.pumpApp(tester);
    await openLibrary(tester);

    // The 4 tabs are present.
    expect(find.byKey(const ValueKey('library.root')), findsOne);
    for (final t in ['adventures', 'saves', 'projects', 'finished']) {
      expect(find.byKey(ValueKey('library.tab.$t')), findsOne);
    }

    // Adventures tab is selected first: its grid lists {Adventures}.
    expect(find.byKey(const ValueKey('library.grid.adventures')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.AdvOne')), findsOne);

    // Saves tab.
    await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.grid.saves')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);

    // Projects tab.
    await tester.tap(find.byKey(const ValueKey('library.tab.projects')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.grid.projects')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.ProjOne')), findsOne);

    // Finished tab.
    await tester.tap(find.byKey(const ValueKey('library.tab.finished')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.grid.finished')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.FinOne')), findsOne);
  });

  testWidgets('BRANCH browse_only: Saves/Finished tiles have no context menu', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAdventure(harness.savesDir, 'SaveOne', 'Save One');

    await harness.pumpApp(tester);
    await openLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);
    // No popup context menu on the tile — a Saves tile carries a corner
    // Edit/Delete button, not a menu and not a direct delete.
    expect(
      find.byKey(const ValueKey('adventure.tile.menu.SaveOne')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('adventure.tile.SaveOne.actions')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('adventure.tile.SaveOne.delete')),
      findsNothing,
    );
  });

  testWidgets(
    'library Saves: the tile shows the playthrough group as a bottom overlay',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness.savesDir, 'SaveOne', 'Save One');
      // The save records the group its playthrough is run for.
      await File(
        '${harness.savesDir.path}/SaveOne/group.json',
      ).writeAsString(jsonEncode({'group': 'Team A'}));

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);
      // The bottom overlay shows the group name.
      final groupText = tester.widget<Text>(
        find.byKey(const ValueKey('adventure.tile.SaveOne.group')),
      );
      expect(groupText.data, 'Team A');
    },
  );

  testWidgets(
    "library Saves: the Edit/Delete dialog's Delete warns about lost progress, then removes the save",
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness.savesDir, 'SaveOne', 'Save One');
      // A nested child file proves the WHOLE save directory is removed.
      // (history.json holds scene UUIDs — content is irrelevant here.)
      final marker = File('${harness.savesDir.path}/SaveOne/history.json');
      await marker.writeAsString('["s1"]');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);
      // A corner Edit/Delete button, not a popup menu or a
      // direct delete button.
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.SaveOne')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.SaveOne.actions')),
        findsOne,
      );

      // Actions -> Delete -> the warning dialog. Cancel keeps the save.
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.SaveOne.actions')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('library.save.actions.delete')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library.save.delete.dialog')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('library.save.delete.cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);
      expect(
        Directory('${harness.savesDir.path}/SaveOne').existsSync(),
        isTrue,
      );

      // Actions -> Delete -> Confirm removes the whole save directory and the tile.
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.SaveOne.actions')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('library.save.actions.delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('library.save.delete.confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('adventure.tile.SaveOne')),
        findsNothing,
      );
      expect(
        Directory('${harness.savesDir.path}/SaveOne').existsSync(),
        isFalse,
      );
    },
  );

  // A finished session under {Finished}: scenes (a key event on s1), a recorded
  // chronology, and a checked key-event state.
  Future<void> seedFinished(CreateHarness harness, String dir) async {
    final fin = Directory('${harness.finishedDir.path}/$dir');
    await fin.create(recursive: true);
    await File('${fin.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {'name': 'Fin', 'system': 'basic'},
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [
          {'name': 'Met duke', 'key_event_uuid': 'ke1', 'state': 'checked'},
        ],
        'notes': [],
        'gm_notes': [
          {'gmnote_uuid': 'gm1', 'gmnote_content': 'Remember the duke.'},
        ],
        'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'key_events': ['Met duke'],
            'gmnotes': ['gm1'],
          },
          {
            'scene_uuid': 's2',
            'name': 'Middle',
            'description': '...',
            'scene_type': 'standard',
          },
        ],
      }),
    );
    // history.json holds scene UUIDs: Opening (s1), Middle (s2).
    await File(
      '${fin.path}/history.json',
    ).writeAsString(jsonEncode(['s1', 's2']));
  }

  bool railEnabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  testWidgets(
    'library Finished: a context menu (Copy as project / Delete) replaces the '
    'direct delete button; Delete warns the session is lost permanently, then '
    'removes it',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedFinished(harness, 'FinOne');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.finished')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.FinOne')), findsOne);
      // No direct delete button — a context menu instead.
      expect(
        find.byKey(const ValueKey('adventure.tile.FinOne.delete')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.FinOne')),
        findsOne,
      );

      // Delete -> warning dialog. Cancel keeps it.
      await openTileMenu(tester, 'FinOne', 'delete');
      expect(
        find.byKey(const ValueKey('library.finished.delete.dialog')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('library.finished.delete.cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        Directory('${harness.finishedDir.path}/FinOne').existsSync(),
        isTrue,
      );

      // Delete -> Confirm removes the whole finished directory and the tile.
      await openTileMenu(tester, 'FinOne', 'delete');
      await tester.tap(
        find.byKey(const ValueKey('library.finished.delete.confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.FinOne')), findsNothing);
      expect(
        Directory('${harness.finishedDir.path}/FinOne').existsSync(),
        isFalse,
      );
    },
  );

  testWidgets(
    'library Finished menu: Copy as project copies into {Projects}, resetting '
    'key_events state and dropping every GM note',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedFinished(
        harness,
        'FinOne',
      ); // key_event "Met duke" is "checked"

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.finished')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.FinOne')), findsOne);
      expect(harness.projects(), isEmpty);

      await openTileMenu(tester, 'FinOne', 'clone');
      expect(find.byKey(const ValueKey('library.copy.done')), findsOne);

      // A copy now exists under {Projects}, with its key event reset and its
      // GM note dropped (gm_notes[] emptied, the scene's gmnotes[] cleared).
      expect(harness.projects(), hasLength(1));
      final doc = harness.readDocument(harness.projects().single);
      expect(doc['metadata']['name'], 'Fin');
      expect(doc['key_events'][0]['state'], 'unchecked');
      expect(doc['gm_notes'], isEmpty);
      expect(doc['scenes'][0]['gmnotes'], isEmpty);

      // The Finished session is unchanged (still checked, GM note intact).
      final finDoc =
          jsonDecode(
                await File(
                  '${harness.finishedDir.path}/FinOne/LivingScroll.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(finDoc['key_events'][0]['state'], 'checked');
      expect(finDoc['gm_notes'], hasLength(1));
      expect(finDoc['scenes'][0]['gmnotes'], ['gm1']);
    },
  );

  testWidgets(
    'library Finished: the tile shows the group and completion date as a bottom overlay',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // A finished dir whose name carries the move timestamp (-> 2026-06-27), plus
      // the group.json that moved with the save.
      const dir = 'FinDone-20260627143500';
      await seedFinished(harness, dir);
      await File(
        '${harness.finishedDir.path}/$dir/group.json',
      ).writeAsString(jsonEncode({'group': 'Team A'}));

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.finished')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('adventure.tile.$dir')), findsOne);
      // Bottom overlay: the group line.
      final groupText = tester.widget<Text>(
        find.byKey(const ValueKey('adventure.tile.$dir.group')),
      );
      expect(groupText.data, 'Team A');
      // And the completion-date line, parsed from the stamp and locale-formatted
      // (assert it carries the parsed year + day, format-independent).
      final dateText = tester.widget<Text>(
        find.byKey(const ValueKey('adventure.tile.$dir.finished')),
      );
      expect(dateText.data, isNotNull);
      expect(dateText.data, contains('2026'));
      expect(dateText.data, contains('27'));
    },
  );

  testWidgets(
    'library Finished: tapping a tile opens the REPLAY view (read-only, history-stepped)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedFinished(harness, 'FinOne');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.finished')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('adventure.tile.FinOne')));
      await tester.pumpAndSettle();

      // Replay opens at the first recorded scene.
      expect(find.byKey(const ValueKey('play.root')), findsOne);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );

      // Key events: shown but DISABLED, reflecting the recorded (checked) state.
      expect(find.byKey(const ValueKey('play.keyevent.Met duke')), findsOne);
      expect(railEnabled(tester, 'play.keyevent.Met duke'), isFalse);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('play.keyevent.Met duke.check')),
            )
            .value,
        isTrue,
      );

      // Next scenes row: ONLY Previous / Next (no scene-name / ad-hoc buttons).
      expect(find.byKey(const ValueKey('play.replay.previous')), findsOne);
      expect(find.byKey(const ValueKey('play.replay.next')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscene.Middle')), findsNothing);
      expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsNothing);
      // At the start: Previous disabled, Next enabled.
      expect(railEnabled(tester, 'play.replay.previous'), isFalse);
      expect(railEnabled(tester, 'play.replay.next'), isTrue);

      // GM Notes: no add tile (cannot add in replay).
      await tester.tap(find.byKey(const ValueKey('nav.play.gmnotes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnote.new')), findsNothing);

      // Next -> the second recorded scene ("Middle"); now Next disabled, Previous enabled.
      await tester.tap(find.byKey(const ValueKey('play.replay.next')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Middle',
      );
      expect(railEnabled(tester, 'play.replay.next'), isFalse);
      expect(railEnabled(tester, 'play.replay.previous'), isTrue);

      // Previous -> back to "Opening".
      await tester.tap(find.byKey(const ValueKey('play.replay.previous')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );
    },
  );

  testWidgets(
    'library Projects: tapping a tile opens the project in create mode',
    (tester) async {
      useDesktopView(tester);
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness.projectsDir, 'ProjOne', 'Proj One');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.projects')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.ProjOne')), findsOne);
      // The tile carries the SAME context menu as the Create grid — not a button.
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.ProjOne.delete')),
        findsNothing,
      );

      // Tap the tile body -> the game editor opens for this project.
      await tester.tap(find.byKey(const ValueKey('adventure.tile.ProjOne')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.root')), findsOne);
    },
  );

  testWidgets(
    'library Projects: the new-project tile opens the Create new-adventure form',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // No projects seeded — the grid leads with just the new-project cell.

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.projects')));
      await tester.pumpAndSettle();

      // Cell 0 is the new-project tile (the same cell as the Create grid's new cell).
      expect(find.byKey(const ValueKey('library.projects.new')), findsOne);

      // Tapping it moves to the Create destination AND opens the new-adventure form.
      await tester.tap(find.byKey(const ValueKey('library.projects.new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create_new.create')), findsOne);
    },
  );

  testWidgets(
    'library Projects: the context-menu Delete confirms, then removes the whole directory',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness.projectsDir, 'ProjOne', 'Proj One');
      // A nested child file proves the WHOLE directory (with contents) is removed.
      final marker = File(
        '${harness.projectsDir.path}/ProjOne/images/marker.txt',
      );
      await marker.parent.create(recursive: true);
      await marker.writeAsString('x');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.projects')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.ProjOne')), findsOne);
      // The delete affordance is now the context menu, NOT a direct button.
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.ProjOne.delete')),
        findsNothing,
      );

      // Menu Delete -> confirmation dialog. Cancel keeps it.
      await openTileMenu(tester, 'ProjOne', 'delete');
      expect(
        find.byKey(const ValueKey('library.project.delete.dialog')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('library.project.delete.cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.ProjOne')), findsOne);
      expect(
        Directory('${harness.projectsDir.path}/ProjOne').existsSync(),
        isTrue,
      );

      // Menu Delete -> Confirm removes the whole directory and the tile.
      await openTileMenu(tester, 'ProjOne', 'delete');
      await tester.tap(
        find.byKey(const ValueKey('library.project.delete.confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('adventure.tile.ProjOne')),
        findsNothing,
      );
      expect(
        Directory('${harness.projectsDir.path}/ProjOne').existsSync(),
        isFalse,
      );
    },
  );

  testWidgets(
    'library Projects: the context-menu Clone copies the project (like Create)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness.projectsDir, 'ProjOne', 'Proj One');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('library.tab.projects')));
      await tester.pumpAndSettle();
      // Same context menu as the Create grid: Clone + Delete, no direct button.
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.ProjOne.delete')),
        findsNothing,
      );

      // Open the menu and pick Clone -> a renamed copy is created, original kept.
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne.item.clone')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne.item.delete')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.menu.ProjOne.item.clone')),
      );
      await tester.pumpAndSettle();

      // The original survives and a second project directory now exists.
      expect(
        Directory('${harness.projectsDir.path}/ProjOne').existsSync(),
        isTrue,
      );
      final dirs = harness.projectsDir
          .listSync()
          .whereType<Directory>()
          .toList();
      expect(dirs.length, 2, reason: 'clone added a second project directory');
    },
  );

  testWidgets(
    'BRANCH empty_dirs: a tab over an empty directory shows an empty grid',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // No adventures seeded anywhere.

      await harness.pumpApp(tester);
      await openLibrary(tester);

      expect(find.byKey(const ValueKey('library.grid.adventures')), findsOne);
      // Grid present, but no tiles.
      expect(find.byType(AdventureTile), findsNothing);
    },
  );

  // Seeds a library adventure (Adventures/<dir>) AND its index entry.
  Future<void> seedLibraryAdventure(
    CreateHarness harness,
    String dir,
    String name,
  ) async {
    await seedAdventure(harness.adventuresDir, dir, name);
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': name,
          'version': '',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': dir,
        },
      ]),
    );
  }

  testWidgets(
    'library Adventures: tapping a tile opens the read-only info window',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // A full-metadata adventure so the info window shows every field.
      final adv = Directory('${harness.adventuresDir.path}/Pack');
      await adv.create(recursive: true);
      await File('${adv.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {
            'name': 'Pack',
            'system': 'basic',
            'version': '1.0.0',
            'author': 'A',
            'description': 'd',
          },
          'images': [],
          'audio': [],
          'paths': [],
          'key_events': [],
          'notes': [],
          'gm_notes': [],
          'npcs': [],
          'scenes': [],
        }),
      );

      await harness.pumpApp(tester);
      await openLibrary(tester);
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsOne);

      // Tap the tile body -> the info window with the create-settings layout.
      await tester.tap(find.byKey(const ValueKey('adventure.tile.Pack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library.adventure.info')), findsOne);
      String value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      // Title is just the name; the version sits on its own line below it,
      // prefixed with the localized label (so assert it CONTAINS the version).
      expect(value('library.adventure.info.title'), 'Pack');
      expect(value('library.adventure.info.version'), contains('1.0.0'));
      expect(value('library.adventure.info.system'), 'basic');
      expect(value('library.adventure.info.author'), 'A');
      expect(value('library.adventure.info.description'), 'd');
      expect(
        find.byKey(const ValueKey('library.adventure.info.play')),
        findsOne,
      );

      // Close dismisses; the library is untouched.
      await tester.tap(
        find.byKey(const ValueKey('library.adventure.info.close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library.adventure.info')),
        findsNothing,
      );
      expect(
        Directory('${harness.adventuresDir.path}/Pack').existsSync(),
        isTrue,
      );
    },
  );

  testWidgets(
    'library Adventures menu: Copy as project copies into {Projects}',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedLibraryAdventure(harness, 'Pack', 'Pack');

      await harness.pumpApp(tester);
      await openLibrary(tester);
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsOne);
      expect(harness.projects(), isEmpty);

      // The clone slot is labelled "Copy as project".
      await openTileMenu(tester, 'Pack', 'clone');
      expect(find.byKey(const ValueKey('library.copy.done')), findsOne);

      // A copy now exists under {Projects}.
      expect(harness.projects(), hasLength(1));
      expect(
        harness.readDocument(harness.projects().single)['metadata']['name'],
        'Pack',
      );
      // The library is unchanged.
      expect(
        Directory('${harness.adventuresDir.path}/Pack').existsSync(),
        isTrue,
      );
    },
  );

  testWidgets(
    'library Adventures menu: Delete asks to confirm, then removes the adventure',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedLibraryAdventure(harness, 'Pack', 'Pack');

      await harness.pumpApp(tester);
      await openLibrary(tester);

      // Delete -> confirmation dialog. Cancel keeps it.
      await openTileMenu(tester, 'Pack', 'delete');
      expect(find.byKey(const ValueKey('library.delete.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('library.delete.cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library.delete.dialog')), findsNothing);
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsOne);
      expect(
        Directory('${harness.adventuresDir.path}/Pack').existsSync(),
        isTrue,
      );

      // Delete -> Confirm removes the directory, the index entry and the tile.
      await openTileMenu(tester, 'Pack', 'delete');
      await tester.tap(find.byKey(const ValueKey('library.delete.confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsNothing);
      expect(
        Directory('${harness.adventuresDir.path}/Pack').existsSync(),
        isFalse,
      );
      expect(indexEntries(harness), isEmpty);
    },
  );
}
