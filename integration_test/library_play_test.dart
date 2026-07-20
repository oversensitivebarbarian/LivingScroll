// Integration test: from the Library Adventures
// info dialog's Play button: the adventure launch screen (group name + start-scene
// radio grid + Dry run / Play), the {Saves} copy under <title>-<version>-<group>,
// the Replace/Cancel dialog, and launching the playthrough (gameplay records
// history.json; dry run does not).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const saveName = 'Pack-1.0.0-Team A';

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // A library adventure "Pack" with two start scenes and one standard scene.
  Future<void> seedPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
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
          },
          {
            'scene_uuid': 's2',
            'name': 'Alt start',
            'description': 'Another way in.',
            'scene_type': 'start',
          },
          {
            'scene_uuid': 's3',
            'name': 'Middle',
            'description': '...',
            'scene_type': 'standard',
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  // A library adventure whose start scene carries a key event and a next scene,
  // so a gameplay navigation can commit progress.
  Future<void> seedProgressPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': '',
          'description': '',
        },
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [
          {'name': 'Met duke', 'key_event_uuid': 'ke1', 'state': 'unchecked'},
        ],
        'notes': [],
        'gm_notes': [],
        'npcs': [
          {'name': 'Guard', 'npc_uuid': 'p1', 'state': 'active'},
        ],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'key_events': ['Met duke'],
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Middle',
            'description': '...',
            'scene_type': 'standard',
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  // A library adventure whose graph runs start -> RECURRING -> standard, so a
  // gameplay navigation leaves a recurring scene behind (which must NOT be marked
  // visited).
  Future<void> seedRecurringPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
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
            'next_scenes': ['s4'],
          },
          {
            'scene_uuid': 's4',
            'name': 'Loop',
            'description': 'A recurring hub.',
            'scene_type': 'recurring',
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Middle',
            'description': '...',
            'scene_type': 'standard',
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  // A library adventure whose graph LOOPS BACK, so a next-scene link can point at
  // an already-VISITED scene AND at a RECURRING scene that was already left:
  //   Opening(start) -> Shrine(recurring) -> Crossroads(standard) -> Cave(standard)
  //   Crossroads also links back to Shrine; Cave links back to Crossroads.
  // After the loop, Crossroads is visited (hidden as a next scene) while Shrine
  // (recurring) is never visited (always offered).
  Future<void> seedVisitedPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
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
            'next_scenes': ['s4'],
          },
          {
            'scene_uuid': 's4',
            'name': 'Shrine',
            'description': 'A recurring shrine.',
            'scene_type': 'recurring',
            'next_scenes': ['s2'],
          },
          {
            'scene_uuid': 's2',
            'name': 'Crossroads',
            'description': 'A fork.',
            'scene_type': 'standard',
            'next_scenes': ['s4', 's3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Cave',
            'description': 'A dead end loop.',
            'scene_type': 'standard',
            'next_scenes': ['s2'],
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  // A library adventure with a start scene linking a pre-existing GM note, a
  // second scene, so GM-note display + single/global adds can be exercised.
  Future<void> seedGmPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': '',
          'description': '',
        },
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [
          {'gmnote_uuid': 'g1', 'gmnote_content': 'Existing body'},
        ],
        'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'next_scenes': ['s2'],
            'gmnotes': ['g1'],
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
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  // Library -> Adventures info dialog -> Play -> the launch screen.
  Future<void> openLaunch(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Pack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library.adventure.info.play')));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  Directory saveDir(CreateHarness h) =>
      Directory('${h.savesDir.path}/$saveName');

  // A gameplay session persists progress with fire-and-forget file writes
  // (history.json / LivingScroll.json). runAsync yields to the REAL event loop so
  // those writes flush before the test reads them or ends (a pump-based wait uses
  // simulated time and never drains real file I/O) — avoids "pending async work".
  Future<void> settleIO(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'library_play: the poster keeps 1:1.43 proportions on a tall window',
    (tester) async {
      // A tall / portrait window used to squeeze the poster into a narrow strip
      // (the cap-width-while-stretched regression); it must stay 1:1.43.
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);

      final cover = tester.getSize(find.byKey(const ValueKey('launch.cover')));
      // Portrait 1:1.43 (height / width), NOT a tall thin strip; width capped 300.
      expect(cover.width, lessThanOrEqualTo(300.5));
      expect(cover.height / cover.width, closeTo(1.43, 0.02));
    },
  );

  testWidgets(
    'library_play: the form is two columns — group+players LEFT, scenes RIGHT',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);

      // A new game shows ONE empty player field to start (seeded); the + adds more.
      expect(find.byKey(const ValueKey('launch.player.0')), findsOne);
      expect(find.byKey(const ValueKey('launch.player.1')), findsNothing);
      expect(find.byKey(const ValueKey('launch.players.add')), findsOne);

      // Two-column FORM: the group name + the first player field sit in the LEFT
      // column, the start-scene grid in the RIGHT column — the left column ends
      // before the scene grid begins (a gap between the two columns).
      final groupRect = tester.getRect(
        find.byKey(const ValueKey('launch.field.group')),
      );
      final playerRect = tester.getRect(
        find.byKey(const ValueKey('launch.player.0')),
      );
      final scenesRect = tester.getRect(
        find.byKey(const ValueKey('launch.scenes')),
      );
      expect(groupRect.right, lessThanOrEqualTo(scenesRect.left));
      expect(playerRect.right, lessThanOrEqualTo(scenesRect.left));
      // The + button sits BELOW the player field (added after it in the column).
      final addRect = tester.getRect(
        find.byKey(const ValueKey('launch.players.add')),
      );
      expect(addRect.top, greaterThanOrEqualTo(playerRect.top));
    },
  );

  testWidgets('library_play: Play copies into {Saves} and records progress', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedPack(harness);

    await harness.pumpApp(tester);
    await openLaunch(tester);

    // STEP 1-2: the launch screen; both start scenes listed; buttons disabled.
    expect(find.byKey(const ValueKey('launch.root')), findsOne);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('launch.title'))).data,
      'Pack',
    );
    // Version sits under the title, prefixed with the localized label.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('launch.version'))).data,
      contains('1.0.0'),
    );
    expect(find.byKey(const ValueKey('launch.scene.s1')), findsOne);
    expect(find.byKey(const ValueKey('launch.scene.s2')), findsOne);
    expect(enabled(tester, 'launch.play'), isFalse);
    expect(enabled(tester, 'launch.dryrun'), isFalse);
    expect(saveDir(harness).existsSync(), isFalse);

    // STEP 3: enter a group name + pick the second start scene -> buttons enable.
    await tester.enterText(
      find.byKey(const ValueKey('launch.field.group')),
      'Team A',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch.scene.s2')));
    await tester.pumpAndSettle();
    expect(enabled(tester, 'launch.play'), isTrue);
    expect(enabled(tester, 'launch.dryrun'), isTrue);

    // STEP 4: Play -> copy to {Saves}, open the playthrough at the chosen scene,
    // and record progress in history.json.
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    expect(saveDir(harness).existsSync(), isTrue);
    expect(
      File('${saveDir(harness).path}/LivingScroll.json').existsSync(),
      isTrue,
    );
    // A group.json records which group this playthrough is for.
    final groupFile = File('${saveDir(harness).path}/group.json');
    expect(groupFile.existsSync(), isTrue);
    expect(
      (jsonDecode(groupFile.readAsStringSync()) as Map)['group'],
      'Team A',
    );
    final history = File('${saveDir(harness).path}/history.json');
    expect(history.existsSync(), isTrue);
    // history.json records scene UUIDs; 'Alt start' is s2.
    expect((jsonDecode(history.readAsStringSync()) as List).first, 's2');

    // The play view opened at the selected start scene.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Alt start',
    );
  });

  testWidgets(
    'library_play: players are added on the launch screen and saved to group.json',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);

      // Group name + a start scene so the play buttons can enable.
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();

      // Add three player fields; fill two, leave the third blank.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('launch.players.add')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('launch.player.0')), findsOne);
      expect(find.byKey(const ValueKey('launch.player.2')), findsOne);
      await tester.enterText(
        find.byKey(const ValueKey('launch.player.0')),
        'Alice',
      );
      await tester.enterText(
        find.byKey(const ValueKey('launch.player.1')),
        'Bob',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // group.json records the group AND the normalized roster (blank dropped).
      final group =
          jsonDecode(
                File('${saveDir(harness).path}/group.json').readAsStringSync(),
              )
              as Map;
      expect(group['group'], 'Team A');
      expect(group['players'], ['Alice', 'Bob']);
    },
  );

  testWidgets(
    'library_play: resume pre-fills but keeps the roster EDITABLE and persists it',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final save = Directory('${harness.savesDir.path}/$saveName');
      await save.create(recursive: true);
      await File('${save.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {
            'name': 'Pack',
            'system': 'basic',
            'version': '1.0.0',
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
            },
          ],
        }),
      );
      await File('${save.path}/history.json').writeAsString(jsonEncode(['s1']));
      await File('${save.path}/group.json').writeAsString(
        jsonEncode({
          'group': 'Team A',
          'players': ['Alice', 'Bob'],
        }),
      );

      await harness.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav.library')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('adventure.tile.$saveName')));
      await tester.pumpAndSettle();

      // The player fields are filled from group.json but stay EDITABLE (add/remove
      // shown, fields enabled) — only the group NAME is locked on a resume.
      expect(find.byKey(const ValueKey('launch.players.add')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('launch.player.0')))
            .controller!
            .text,
        'Alice',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('launch.player.1')))
            .controller!
            .text,
        'Bob',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('launch.player.0')))
            .enabled,
        isNot(false),
      ); // roster editable
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('launch.field.group')))
            .enabled,
        isFalse,
      ); // the group name stays fixed

      // Add a third player, then continue — the edited roster is persisted to
      // group.json (group preserved), while the group name is untouched.
      await tester.tap(find.byKey(const ValueKey('launch.players.add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('launch.player.2')),
        'Cara',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();

      final groupJson =
          jsonDecode(await File('${save.path}/group.json').readAsString())
              as Map;
      expect(groupJson['group'], 'Team A');
      expect(groupJson['players'], ['Alice', 'Bob', 'Cara']);
    },
  );

  testWidgets(
    'library_play: new game imports a finished game\'s progress (key events, '
    'NPC states, GM notes)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // The library adventure carries key event ke1 (unchecked) and NPC p1
      // (active). A finished game has ke1 CHECKED plus an extra ke2 CHECKED that
      // the adventure lacks; NPC p1 INACTIVE plus an extra NPC p2 (inactive) the
      // adventure lacks; and a GM note the adventure lacks.
      await seedProgressPack(harness);
      final fin = Directory('${harness.finishedDir.path}/Old-Session');
      await fin.create(recursive: true);
      await File('${fin.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {
            'name': 'Old Pack',
            'system': 'basic',
            'version': '1.0.0',
          },
          'key_events': [
            {'name': 'Met duke', 'key_event_uuid': 'ke1', 'state': 'checked'},
            {'name': 'Found map', 'key_event_uuid': 'ke2', 'state': 'checked'},
          ],
          'npcs': [
            {'name': 'Guard', 'npc_uuid': 'p1', 'state': 'inactive'},
            {'name': 'Duke', 'npc_uuid': 'p2', 'state': 'inactive'},
          ],
          'gm_notes': [
            {
              'gmnote_uuid': 'g1',
              'gmnote_content': 'Duke is secretly the villain.',
            },
          ],
          'scenes': [],
        }),
      );
      await File(
        '${fin.path}/group.json',
      ).writeAsString(jsonEncode({'group': 'Old Team', 'players': <String>[]}));
      // A finished session of the SAME game (Pack 1.0.0) — must be filtered OUT of
      // the picker (you import from ANOTHER game).
      final self = Directory('${harness.finishedDir.path}/Pack-1.0.0-Self');
      await self.create(recursive: true);
      await File('${self.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {'name': 'Pack', 'system': 'basic', 'version': '1.0.0'},
          'key_events': [],
          'scenes': [],
        }),
      );
      await File(
        '${self.path}/group.json',
      ).writeAsString(jsonEncode({'group': 'Self', 'players': <String>[]}));

      await harness.pumpApp(tester);
      await openLaunch(tester);

      // The picker is the SAME grid as the Library Saves/Finished tab: tiles are
      // browse-only (no delete button) and a tap picks the finished session.
      await tester.tap(find.byKey(const ValueKey('launch.import.progress')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('launch.import.dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('launch.import.grid')), findsOneWidget);
      // The same-game finished session is filtered out; the other one shows,
      // without a delete button.
      expect(
        find.byKey(const ValueKey('adventure.tile.Pack-1.0.0-Self')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.Old-Session')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.Old-Session.delete')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.Old-Session')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.import.dialog')), findsNothing);

      // Launch a new game.
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // The new save's key events adopted the finished game's states: ke1 flipped
      // to checked, ke2 created (with its checked state).
      final doc =
          jsonDecode(
                File(
                  '${saveDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )
              as Map;
      final keByUuid = {
        for (final e in doc['key_events'] as List) e['key_event_uuid']: e,
      };
      expect(keByUuid['ke1']['state'], 'checked');
      expect(keByUuid['ke2'], isNotNull);
      expect(keByUuid['ke2']['state'], 'checked');

      // NPC states adopted/created the SAME way: p1 flipped to inactive, p2
      // created (with its inactive state).
      final npcByUuid = {for (final n in doc['npcs'] as List) n['npc_uuid']: n};
      expect(npcByUuid['p1']['state'], 'inactive');
      expect(npcByUuid['p2'], isNotNull);
      expect(npcByUuid['p2']['state'], 'inactive');

      // The GM note was copied in and linked to EVERY scene of the new save.
      final gmNotes = doc['gm_notes'] as List;
      expect(gmNotes.single['gmnote_uuid'], 'g1');
      expect(gmNotes.single['gmnote_content'], 'Duke is secretly the villain.');
      for (final s in doc['scenes'] as List) {
        expect((s as Map)['gmnotes'], contains('g1'));
      }
    },
  );

  testWidgets(
    'library_play: a start-scene tile Loupe opens the full-description dialog',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);

      // Each start-scene tile carries a bottom-right Loupe.
      expect(find.byKey(const ValueKey('launch.scene.s1.loupe')), findsOne);
      expect(find.byKey(const ValueKey('launch.scene.s2.loupe')), findsOne);

      final scenesEl = tester.element(
        find.byKey(const ValueKey('launch.scenes')),
      );
      final scheme = Theme.of(scenesEl).colorScheme;
      Color tileColor(String key) => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;

      // The first start scene (s1) is selected by default.
      expect(tileColor('launch.scene.s1'), scheme.secondaryContainer);
      expect(tileColor('launch.scene.s2'), scheme.surfaceContainerHighest);

      // Tapping s2's Loupe opens the detail dialog with s2's full content.
      await tester.tap(find.byKey(const ValueKey('launch.scene.s2.loupe')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.scene.detail')), findsOne);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('launch.scene.detail.name')),
            )
            .data,
        'Alt start',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('launch.scene.detail.description')),
            )
            .data,
        'Another way in.',
      );

      // Sized to 80% of the window height; the shorter side (width) keeps ISO
      // format-A proportions (width == height / sqrt(2)).
      final size = tester.getSize(
        find.byKey(const ValueKey('launch.scene.detail')),
      );
      final windowH = MediaQuery.sizeOf(scenesEl).height;
      expect(size.height, moreOrLessEquals(windowH * 0.8, epsilon: 0.5));
      expect(
        size.width,
        moreOrLessEquals(size.height / 1.4142135623730951, epsilon: 0.5),
      );

      // OK closes the dialog and returns to the launch screen.
      await tester.tap(find.byKey(const ValueKey('launch.scene.detail.ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.scene.detail')), findsNothing);
      expect(find.byKey(const ValueKey('launch.scenes')), findsOne);

      // The Loupe did NOT change the radio selection: s1 stays selected.
      expect(tileColor('launch.scene.s1'), scheme.secondaryContainer);
      expect(tileColor('launch.scene.s2'), scheme.surfaceContainerHighest);
    },
  );

  testWidgets('library_play: gameplay serializes session state on navigation', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedProgressPack(harness);

    await harness.pumpApp(tester);
    await openLaunch(tester);
    await tester.enterText(
      find.byKey(const ValueKey('launch.field.group')),
      'Team A',
    );
    await tester.pumpAndSettle();
    // Default-selected start scene s1 -> Play.
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Opening',
    );

    // Tick the start scene's key event, then follow the next scene.
    await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Middle',
    );
    // Previous scene is a PREP-mode-only affordance — never shown in gameplay.
    expect(find.byKey(const ValueKey('play.nextscene.previous')), findsNothing);
    await settleIO(tester);

    // The save's own LivingScroll.json now carries the committed session state.
    final doc =
        jsonDecode(
              File(
                '${saveDir(harness).path}/LivingScroll.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final ke = (doc['key_events'] as List).single as Map;
    expect(ke['state'], 'checked'); // the ticked event was committed
    final s1 = (doc['scenes'] as List).cast<Map>().firstWhere(
      (s) => s['scene_uuid'] == 's1',
    );
    expect(s1['visited'], isTrue); // the scene left behind is marked visited

    // history.json records the sequence of scene UUIDs entered:
    // Opening (s1) then Middle (s3).
    final history =
        jsonDecode(
              File('${saveDir(harness).path}/history.json').readAsStringSync(),
            )
            as List;
    expect(history, ['s1', 's3']);
  });

  testWidgets(
    'library_play: a recurring scene left behind is NEVER marked visited',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRecurringPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );

      // Opening (start) -> Loop (recurring) -> Middle (standard). Leaving Opening
      // marks it visited; leaving the RECURRING Loop must NOT mark it visited.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Loop')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Loop',
      );
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Middle',
      );
      await settleIO(tester);

      final scenes =
          (jsonDecode(
                    File(
                      '${saveDir(harness).path}/LivingScroll.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['scenes']
              as List;
      final opening = scenes.cast<Map>().firstWhere(
        (s) => s['scene_uuid'] == 's1',
      );
      final loop = scenes.cast<Map>().firstWhere(
        (s) => s['scene_uuid'] == 's4',
      );
      expect(opening['visited'], isTrue); // start scene left -> visited
      expect(
        loop.containsKey('visited'),
        isFalse,
      ); // recurring left -> NOT visited
    },
  );

  testWidgets(
    'library_play: a visited scene is not offered in the Next scenes row '
    '(a recurring target always stays)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedVisitedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );

      // Opening -> Shrine (recurring). Opening becomes visited.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Shrine')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Shrine',
      );

      // Shrine[recurring] -> Crossroads. Shrine is NOT marked visited, so at
      // Crossroads its button (a link back to Shrine) is STILL offered.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Crossroads')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Crossroads',
      );
      expect(find.byKey(const ValueKey('play.nextscene.Shrine')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscene.Cave')), findsOne);

      // Crossroads -> Cave. Crossroads becomes visited. Cave's only next is
      // Crossroads, now VISITED -> its button is absent.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Cave')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Cave',
      );
      expect(
        find.byKey(const ValueKey('play.nextscene.Crossroads')),
        findsNothing,
      );
      // The Ad-hoc button still shows (Cave is a standard, non-end scene).
      expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsOne);
      await settleIO(tester);

      // On disk: Crossroads (standard) is visited; Shrine (recurring) never is.
      final scenes =
          (jsonDecode(
                    File(
                      '${saveDir(harness).path}/LivingScroll.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['scenes']
              as List;
      final crossroads = scenes.cast<Map>().firstWhere(
        (s) => s['scene_uuid'] == 's2',
      );
      final shrine = scenes.cast<Map>().firstWhere(
        (s) => s['scene_uuid'] == 's4',
      );
      expect(crossroads['visited'], isTrue);
      expect(shrine.containsKey('visited'), isFalse);
    },
  );

  testWidgets('library_play: Finish adventure archives the save and returns Home', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    // Start scene -> an END scene (no next scenes).
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
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
            'next_scenes': ['s2'],
          },
          {
            'scene_uuid': 's2',
            'name': 'Finale',
            'description': 'The end.',
            'scene_type': 'end',
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );

    await harness.pumpApp(tester);
    await openLaunch(tester);
    await tester.enterText(
      find.byKey(const ValueKey('launch.field.group')),
      'Team A',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();

    // Reach the end scene; it offers Finish adventure (no next scenes).
    await tester.tap(find.byKey(const ValueKey('play.nextscene.Finale')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Finale',
    );
    expect(find.byKey(const ValueKey('play.finish')), findsOne);

    await tester.tap(find.byKey(const ValueKey('play.finish')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    // The save is gone from {Saves}; a timestamped copy is under {Finished}.
    expect(saveDir(harness).existsSync(), isFalse);
    final finished = harness.finishedDir
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toList();
    expect(finished.length, 1);
    expect(finished.single.startsWith('Pack-1.0.0-Team A-'), isTrue);
    // The archived game kept the committed state (the end scene visited).
    final doc =
        jsonDecode(
              File(
                '${harness.finishedDir.path}/${finished.single}/LivingScroll.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final s2 = (doc['scenes'] as List).cast<Map>().firstWhere(
      (s) => s['scene_uuid'] == 's2',
    );
    expect(s2['visited'], isTrue);

    // The user is back on Home (the play/launch routes are popped).
    expect(find.byKey(const ValueKey('play.scene.title')), findsNothing);
    expect(find.byKey(const ValueKey('launch.root')), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );
    // Home's Active sessions list refreshed: the finished save is gone from it.
    expect(find.byKey(ValueKey('adventure.tile.$saveName')), findsNothing);
  });

  testWidgets(
    'library_play: Pause returns Home and lists the save in Active sessions',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.scene.s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.scene.title')), findsOne);

      // Interrupt the session: Pause -> OK.
      await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.pause.ok')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // Back on Home (NOT the launch screen), with the in-progress save both on
      // disk and listed under Active sessions.
      expect(find.byKey(const ValueKey('play.scene.title')), findsNothing);
      expect(find.byKey(const ValueKey('launch.root')), findsNothing);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );
      expect(saveDir(harness).existsSync(), isTrue);
      expect(find.byKey(ValueKey('adventure.tile.$saveName')), findsOne);
    },
  );

  testWidgets(
    'BRANCH dry_run_no_progress: Prep mode copies but records nothing',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('launch.dryrun')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // The copy still happens, but NO history is recorded.
      expect(saveDir(harness).existsSync(), isTrue);
      expect(
        File('${saveDir(harness).path}/history.json').existsSync(),
        isFalse,
      );
      // Play view opened at the default first start scene.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );
    },
  );

  testWidgets(
    'library_play: a Saves tile resumes the launch screen at the last visited scene',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // An in-progress save (already copied into {Saves}) with a history whose
      // last entry is the scene to resume at.
      final save = Directory('${harness.savesDir.path}/$saveName');
      await save.create(recursive: true);
      await File('${save.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {
            'name': 'Pack',
            'system': 'basic',
            'version': '1.0.0',
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
              'next_scenes': ['s3'],
            },
            {
              'scene_uuid': 's3',
              'name': 'Middle',
              'description': '...',
              'scene_type': 'standard',
            },
          ],
        }),
      );
      // history.json holds scene UUIDs: Opening (s1), Middle (s3).
      await File(
        '${save.path}/history.json',
      ).writeAsString(jsonEncode(['s1', 's3']));
      await File(
        '${save.path}/group.json',
      ).writeAsString(jsonEncode({'group': 'Team A'}));

      await harness.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav.library')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
      await tester.pumpAndSettle();
      // The Saves tile opens the SAME launch screen (resume mode).
      await tester.tap(find.byKey(ValueKey('adventure.tile.$saveName')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.root')), findsOne);
      expect(
        enabled(tester, 'launch.play'),
        isTrue,
      ); // resume needs no group name
      expect(enabled(tester, 'launch.dryrun'), isTrue);
      // The group is filled from group.json; the start-scene grid is gone and the
      // last scene ("Middle") is shown instead.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('launch.field.group')))
            .controller!
            .text,
        'Team A',
      );
      expect(find.byKey(const ValueKey('launch.scenes')), findsNothing);
      expect(find.byKey(const ValueKey('launch.last.scene')), findsOne);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('launch.last.scene.name')))
            .data,
        'Middle',
      );

      // Play -> the playthrough opens at the LAST visited scene ("Middle"), not a
      // start scene.
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Middle',
      );
      await settleIO(tester);
    },
  );

  testWidgets(
    'library_play: the resume launch screen has a side navigation rail (Home/Settings)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final save = Directory('${harness.savesDir.path}/$saveName');
      await save.create(recursive: true);
      await File('${save.path}/LivingScroll.json').writeAsString(
        jsonEncode({
          'metadata': {
            'name': 'Pack',
            'system': 'basic',
            'version': '1.0.0',
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
            },
          ],
        }),
      );
      // history.json holds scene UUIDs: Opening is s1.
      await File('${save.path}/history.json').writeAsString(jsonEncode(['s1']));
      await File(
        '${save.path}/group.json',
      ).writeAsString(jsonEncode({'group': 'Team A'}));

      await harness.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav.library')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('adventure.tile.$saveName')));
      await tester.pumpAndSettle();

      // The launch screen carries its own navigation rail (so it never dead-ends):
      expect(find.byKey(const ValueKey('launch.root')), findsOne);
      expect(find.byKey(const ValueKey('launch.nav.home')), findsOne);
      expect(find.byKey(const ValueKey('launch.nav.settings')), findsOne);
      expect(find.byKey(const ValueKey('launch.nav.library')), findsOne);

      // Tapping Home in the rail exits back to the shell's Home destination.
      await tester.tap(find.byKey(const ValueKey('launch.nav.home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.root')), findsNothing);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      ); // back on Home
    },
  );

  // Reads the live save's scenes/gm_notes for the GM-notes assertions.
  Map<String, dynamic> readSaveDoc(CreateHarness h) =>
      jsonDecode(
            File('${saveDir(h).path}/LivingScroll.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  // A "Pack" whose start scene s1 links a (visible) note n1 + image i1, so
  // leaving s1 marks both `seen` and the seen gallery surfaces them on s2.
  Future<void> seedSeenPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    // A real 1x1 PNG so the image file exists AND decodes (the seen cell paints).
    final imgFile = File('${adv.path}/images/other/i1.png');
    await imgFile.parent.create(recursive: true);
    await imgFile.writeAsBytes(img.encodePng(img.Image(width: 1, height: 1)));
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': '',
          'description': '',
        },
        'images': [
          {'image_uuid': 'i1', 'name': 'Map', 'seen': false},
        ],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [
          {
            'note_uuid': 'n1',
            'note_name': 'Clue',
            'note_content': 'A clue.',
            'seen': false,
          },
        ],
        'gm_notes': [],
        'npcs': [],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'next_scenes': ['s2'],
            'notes': ['n1'],
            'images': ['i1'],
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
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  testWidgets(
    'library_play: leaving a scene marks its visible notes/images seen; the '
    'seen gallery shows them below a divider',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedSeenPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // On s1: the Notes section shows the scene note; no seen gallery yet.
      await tester.tap(find.byKey(const ValueKey('nav.play.notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.note.tile.n1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('play.notes.seen.divider')),
        findsNothing,
      );

      // Leave s1 -> s2. Its visible note + image are committed as seen.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      final doc = readSaveDoc(harness);
      bool seenOf(String coll, String idKey, String id) =>
          (doc[coll] as List).cast<Map>().firstWhere(
            (e) => e[idKey] == id,
          )['seen'] ==
          true;
      expect(seenOf('notes', 'note_uuid', 'n1'), isTrue);
      expect(seenOf('images', 'image_uuid', 'i1'), isTrue);

      // On s2 (no own notes/images): the seen gallery shows n1 below the divider.
      await tester.tap(find.byKey(const ValueKey('nav.play.notes')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play.notes.seen.divider')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('play.note.seen.n1')), findsOneWidget);

      // And the Images section shows the seen image below its divider.
      await tester.tap(find.byKey(const ValueKey('nav.play.images')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play.images.seen.divider')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('play.image.seen.i1')), findsOneWidget);
    },
  );

  // A deactivated/inactive NPC tile wraps its image in a ColorFiltered (the grey
  // filter); an active tile has none.
  bool npcTileGreyed(WidgetTester tester, String uuid) => tester
      .widgetList(
        find.descendant(
          of: find.byKey(ValueKey('play.npc.tile.$uuid')),
          matching: find.byType(ColorFiltered),
        ),
      )
      .isNotEmpty;

  // A library adventure whose start scene and a following scene BOTH list the
  // same NPC, so a gameplay navigation can commit its deactivation and the next
  // scene can show it inactive.
  Future<void> seedNpcPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': '',
          'description': '',
        },
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [
          {
            'npc_uuid': 'n1',
            'name': 'Guard',
            'description': 'A guard.',
            'state': 'active',
          },
        ],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'description': 'It begins.',
            'scene_type': 'start',
            'npcs': ['Guard'],
            'next_scenes': ['s3'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Middle',
            'description': '...',
            'scene_type': 'standard',
            'npcs': ['Guard'],
          },
        ],
      }),
    );
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': '',
          'language': '',
          'dir': 'Pack',
        },
      ]),
    );
  }

  testWidgets(
    'library_play: deactivating an NPC and following a next scene commits '
    'npcs[].state == inactive; the NPC is then greyed, buttonless and inert',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedNpcPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );

      // Open the NPC grid; Guard is active -> not greyed, has a deactivate button.
      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      expect(npcTileGreyed(tester, 'n1'), isFalse);
      expect(
        find.byKey(const ValueKey('play.npc.tile.n1.deactivate')),
        findsOne,
      );

      // Grey the NPC, then follow the next scene -> the deactivation is committed.
      await tester.tap(
        find.byKey(const ValueKey('play.npc.tile.n1.deactivate')),
      );
      await tester.pumpAndSettle();
      expect(npcTileGreyed(tester, 'n1'), isTrue);
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
      await tester.pumpAndSettle();
      await settleIO(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Middle',
      );

      // Committed to the save's LivingScroll.json.
      final doc = readSaveDoc(harness);
      final guard = (doc['npcs'] as List).cast<Map>().firstWhere(
        (n) => n['npc_uuid'] == 'n1',
      );
      expect(guard['state'], 'inactive');

      // Middle lists only Guard, now inactive -> no active NPC on the scene, so the
      // NPC section is hidden entirely (only active NPCs are ever shown).
      expect(find.byKey(const ValueKey('nav.play.npc')), findsNothing);
    },
  );

  testWidgets(
    'library_play: GM Notes displays the scene notes and adds one (always global) to EVERY scene',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedGmPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // Open GM Notes (the LAST rail item): the add tile + the scene's existing note.
      await tester.tap(find.byKey(const ValueKey('nav.play.gmnotes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnotes.center')), findsOne);
      expect(find.byKey(const ValueKey('play.gmnote.new')), findsOne);
      // A GM note has no title -> the tile shows ONLY its content.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('play.gmnote.tile.g1.label')),
            )
            .data,
        'Existing body',
      );

      // There is NO Loupe button; tapping the tile body opens the full-content
      // detail dialog (the SAME format-A dialog as the start-scene info).
      expect(
        find.byKey(const ValueKey('play.gmnote.tile.g1.loupe')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('play.gmnote.tile.g1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnote.detail')), findsOne);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('play.gmnote.detail.content')),
            )
            .data,
        'Existing body',
      );
      final detailSize = tester.getSize(
        find.byKey(const ValueKey('play.gmnote.detail')),
      );
      final windowH = MediaQuery.sizeOf(
        tester.element(find.byKey(const ValueKey('play.gmnotes.center'))),
      ).height;
      expect(detailSize.height, moreOrLessEquals(windowH * 0.8, epsilon: 0.5));
      expect(
        detailSize.width,
        moreOrLessEquals(detailSize.height / 1.4142135623730951, epsilon: 0.5),
      );
      await tester.tap(find.byKey(const ValueKey('play.gmnote.detail.ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnote.detail')), findsNothing);

      // Add a GM note. The form has a content input only (no title, no scope
      // checkbox — a GM note is ALWAYS global).
      await tester.tap(find.byKey(const ValueKey('play.gmnote.new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnote.add')), findsOne);
      expect(find.byKey(const ValueKey('play.gmnote.add.name')), findsNothing);
      expect(
        find.byKey(const ValueKey('play.gmnote.add.global')),
        findsNothing,
      );
      // The content box keeps its width (480) but takes adventure-tile proportions
      // (1:1.43), so height = width * 1.43.
      final addBody = tester.getSize(
        find.byKey(const ValueKey('play.gmnote.add.body')),
      );
      expect(addBody.width, moreOrLessEquals(480, epsilon: 0.5));
      expect(addBody.height, moreOrLessEquals(480 * 1.43, epsilon: 0.5));
      await tester.enterText(
        find.byKey(const ValueKey('play.gmnote.add.content')),
        'solo body',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.gmnote.add.save')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // Persisted to gm_notes[] (content only, no title) and linked to EVERY scene
      // (always global — both s1 and s2).
      final doc = readSaveDoc(harness);
      final gm = (doc['gm_notes'] as List).cast<Map>();
      final solo = gm.firstWhere((g) => g['gmnote_content'] == 'solo body');
      expect(solo.containsKey('gmnote_name'), isFalse);
      final soloUuid = solo['gmnote_uuid'] as String;
      final scenes = (doc['scenes'] as List).cast<Map>();
      final s1 = scenes.firstWhere((s) => s['scene_uuid'] == 's1');
      final s2 = scenes.firstWhere((s) => s['scene_uuid'] == 's2');
      expect((s1['gmnotes'] as List).contains(soloUuid), isTrue);
      expect((s2['gmnotes'] as List).contains(soloUuid), isTrue);

      // The new note now shows in the grid too (by its content).
      expect(find.text('solo body'), findsOneWidget);
    },
  );

  testWidgets(
    'library_play: the added GM note lands on EVERY scene (always global)',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedGmPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      await tester.tap(find.byKey(const ValueKey('nav.play.gmnotes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.gmnote.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('play.gmnote.add.content')),
        'everywhere',
      );
      await tester.pumpAndSettle();
      // No scope checkbox — a GM note is always global.
      expect(
        find.byKey(const ValueKey('play.gmnote.add.global')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('play.gmnote.add.save')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // Linked to EVERY scene.
      final doc = readSaveDoc(harness);
      final gm = (doc['gm_notes'] as List).cast<Map>();
      final uuid =
          gm.firstWhere(
                (g) => g['gmnote_content'] == 'everywhere',
              )['gmnote_uuid']
              as String;
      for (final s in (doc['scenes'] as List).cast<Map>()) {
        expect(
          ((s['gmnotes'] as List?) ?? const []).contains(uuid),
          isTrue,
          reason: 'scene ${s['scene_uuid']} should link the global note',
        );
      }
    },
  );

  testWidgets(
    'library_play: a GM-note tile delete button removes the note from the save',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedGmPack(harness); // gm_notes [g1 "Existing body"] linked to s1

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      await tester.tap(find.byKey(const ValueKey('nav.play.gmnotes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.gmnote.tile.g1')), findsOne);

      // The tile carries the SAME top-right round delete button as a library tile.
      expect(
        find.byKey(const ValueKey('play.gmnote.tile.g1.delete')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('play.gmnote.tile.g1.delete')),
      );
      await tester.pumpAndSettle();

      // A confirmation dialog (Cancel/Delete) like the Saves/Finished delete.
      expect(find.byKey(const ValueKey('play.gmnote.delete.dialog')), findsOne);

      // Cancel keeps the note (nothing written).
      await tester.tap(find.byKey(const ValueKey('play.gmnote.delete.cancel')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play.gmnote.delete.dialog')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('play.gmnote.tile.g1')), findsOne);
      expect((readSaveDoc(harness)['gm_notes'] as List).length, 1);

      // Re-open the dialog and confirm Delete this time.
      await tester.tap(
        find.byKey(const ValueKey('play.gmnote.tile.g1.delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('play.gmnote.delete.confirm')),
      );
      await tester.pumpAndSettle();
      await settleIO(tester);

      // Removed from gm_notes[] and unlinked from every scene; the tile is gone.
      final doc = readSaveDoc(harness);
      final gm = (doc['gm_notes'] as List).cast<Map>();
      expect(gm.any((g) => g['gmnote_uuid'] == 'g1'), isFalse);
      for (final s in (doc['scenes'] as List).cast<Map>()) {
        expect(((s['gmnotes'] as List?) ?? const []).contains('g1'), isFalse);
      }
      expect(find.byKey(const ValueKey('play.gmnote.tile.g1')), findsNothing);
    },
  );

  testWidgets(
    'library_play: Prep mode Previous scene returns to the scene arrived from',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedGmPack(harness); // s1 "Opening" -> "Middle" (s2)

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();
      // Prep mode (preview).
      await tester.tap(find.byKey(const ValueKey('launch.dryrun')));
      await tester.pumpAndSettle();
      await settleIO(tester);

      // At the start scene there is nothing to go back to -> no Previous button.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );
      expect(
        find.byKey(const ValueKey('play.nextscene.previous')),
        findsNothing,
      );

      // Follow the next scene -> "Middle"; Previous scene now appears (first).
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Middle',
      );
      expect(find.byKey(const ValueKey('play.nextscene.previous')), findsOne);

      // Previous scene -> back to "Opening"; the button is gone again (top of stack).
      await tester.tap(find.byKey(const ValueKey('play.nextscene.previous')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Opening',
      );
      expect(
        find.byKey(const ValueKey('play.nextscene.previous')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'library_play: Cancel on the launch screen returns to the Library',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);

      await harness.pumpApp(tester);
      await openLaunch(tester);
      expect(find.byKey(const ValueKey('launch.root')), findsOne);

      await tester.tap(find.byKey(const ValueKey('launch.cancel')));
      await tester.pumpAndSettle();

      // Back on the Library; nothing was copied.
      expect(find.byKey(const ValueKey('launch.root')), findsNothing);
      expect(find.byKey(const ValueKey('adventure.tile.Pack')), findsOne);
      expect(saveDir(harness).existsSync(), isFalse);
    },
  );

  testWidgets(
    'BRANCH save_exists_replace: Replace overwrites the existing save',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedPack(harness);
      // A stale save with a marker that a clean copy must remove.
      final marker = File('${saveDir(harness).path}/marker.txt');
      await marker.parent.create(recursive: true);
      await marker.writeAsString('stale');

      await harness.pumpApp(tester);
      await openLaunch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('launch.field.group')),
        'Team A',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('launch.play')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.save.exists.dialog')), findsOne);

      await tester.tap(
        find.byKey(const ValueKey('launch.save.exists.replace')),
      );
      await tester.pumpAndSettle();

      // Clean copy: the stale marker is gone, a fresh save exists, play opened.
      expect(marker.existsSync(), isFalse);
      expect(
        File('${saveDir(harness).path}/LivingScroll.json').existsSync(),
        isTrue,
      );
      expect(find.byKey(const ValueKey('play.scene.title')), findsOne);
      await settleIO(tester);
    },
  );

  testWidgets('BRANCH save_exists_cancel: Cancel keeps the save and stays', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedPack(harness);
    final marker = File('${saveDir(harness).path}/marker.txt');
    await marker.parent.create(recursive: true);
    await marker.writeAsString('stale');

    await harness.pumpApp(tester);
    await openLaunch(tester);
    await tester.enterText(
      find.byKey(const ValueKey('launch.field.group')),
      'Team A',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('launch.save.exists.dialog')), findsOne);

    await tester.tap(find.byKey(const ValueKey('launch.save.exists.cancel')));
    await tester.pumpAndSettle();

    // Stayed on the launch form; the existing save is untouched.
    expect(find.byKey(const ValueKey('launch.root')), findsOne);
    expect(marker.existsSync(), isTrue);
    expect(marker.readAsStringSync(), 'stale');
  });
}
