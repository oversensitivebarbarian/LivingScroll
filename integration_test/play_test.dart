// Integration test for the Play view in PREVIEW mode, opened
// from a scene tile's Preview glyph.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillEditor;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory demoDir(CreateHarness h) => Directory('${h.projectsDir.path}/Demo');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> scenes = const [],
    List<Object> npcs = const [],
    List<Object> paths = const [],
    List<Object> keyEvents = const [],
    List<Object> notes = const [],
    String system = 'basic',
  }) async {
    final dir = demoDir(harness);
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Demo',
          'system': system,
          'version': '1.0.0',
          'author': 'A',
          'description': 'd',
          'language': 'en',
          'content_warnings': 'none',
          'license': 'x',
        },
        'images': [],
        'audio': [],
        'paths': paths,
        'key_events': keyEvents,
        'notes': notes,
        'gm_notes': [],
        'npcs': npcs,
        'scenes': scenes,
      }),
    );
  }

  Future<void> openScenes(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
  }

  // A scene with a background image, narration, a key event and a next scene
  // that itself belongs to the yellow path.
  Future<void> seedRich(
    CreateHarness harness, {
    String type = 'standard',
    String noteContent = 'A hidden lever.',
    String npcBackstory = 'Born here.',
  }) async {
    // The scene references image "img1" as a scene image (images/other/) and
    // "bg1" as its background (images/bg_images/); materialize both files so the
    // image tile and the whole-window background render.
    final imgDir = Directory('${demoDir(harness).path}/images/other');
    await imgDir.create(recursive: true);
    await File(
      CreateHarness.asset('cover_sample.jpg'),
    ).copy('${imgDir.path}/img1.png');
    final bgDir = Directory('${demoDir(harness).path}/images/bg_images');
    await bgDir.create(recursive: true);
    await File(
      CreateHarness.asset('cover_sample.jpg'),
    ).copy('${bgDir.path}/bg1.png');
    return seedDemo(
      harness,
      paths: const [
        {'name': 'Main', 'color': 'yellow', 'description': ''},
      ],
      keyEvents: const [
        {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
      ],
      npcs: [
        {
          'npc_uuid': 'p1',
          'name': 'Guard',
          'description': 'A stern guard.',
          'backstory': npcBackstory,
        },
      ],
      notes: [
        {'note_uuid': 'n1', 'note_name': 'Clue', 'note_content': noteContent},
      ],
      scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'bg_image': 'bg1',
          'description': 'A dark cave.',
          'scene_type': type,
          'key_events': ['Met duke'],
          'next_scenes': ['s2'],
          'npcs': ['Guard'],
          'notes': ['n1'],
          'images': ['img1'],
        },
        const {
          'scene_uuid': 's2',
          'name': 'Tower',
          'scene_type': 'standard',
          'path_names': ['Main'],
        },
      ],
    );
  }

  Future<void> openPreview(WidgetTester tester, String uuid) async {
    await tester.tap(find.byKey(ValueKey('scene.tile.$uuid.preview')));
    await tester.pumpAndSettle();
  }

  // A deactivated/inactive NPC tile wraps its image in a ColorFiltered (the
  // desaturating grey filter); an active tile has none.
  bool npcTileGreyed(WidgetTester tester, String uuid) => tester
      .widgetList(
        find.descendant(
          of: find.byKey(ValueKey('play.npc.tile.$uuid')),
          matching: find.byType(ColorFiltered),
        ),
      )
      .isNotEmpty;

  // Same check for a Villains-grid tile (play.villain.tile.$uuid).
  bool villainTileGreyed(WidgetTester tester, String uuid) => tester
      .widgetList(
        find.descendant(
          of: find.byKey(ValueKey('play.villain.tile.$uuid')),
          matching: find.byType(ColorFiltered),
        ),
      )
      .isNotEmpty;

  // A scene with a soundtrack: materializes audio/a1.wav and attaches it to the
  // scene so the Play view's Soundtrack rail item appears.
  Future<void> seedWithAudio(CreateHarness harness) async {
    final audioDir = Directory('${demoDir(harness).path}/audio');
    await audioDir.create(recursive: true);
    await File(
      CreateHarness.asset(
        'audiopapkin-dark-atmosphere-background-007-312379.mp3',
      ),
    ).copy('${audioDir.path}/a1.wav');
    await seedDemo(
      harness,
      scenes: const [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'standard',
          'audio': ['a1'],
        },
      ],
    );
  }

  IconData soundtrackGlyph(WidgetTester tester) => tester
      .widget<Icon>(find.byKey(const ValueKey('nav.play.soundtrack')))
      .icon!;

  // The right-column panel header text (names the shown content: NPC / Notes /
  // Images / GM Notes — the same label as the rail item that selects it).
  String? panelTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('play.panel.title'))).data;

  // Localized labels resolved from the running app's locale, so the header
  // assertions stay stable across the 8 supported languages (the header reuses
  // the rail item's label).
  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byKey(const ValueKey('play.root'))),
  );

  // Two scenes where the first ("Cave") has music a1 and points to "Tower".
  // [towerAudio] optionally gives Tower its own track a2. Both audio files are
  // materialized so the soundtrack resolves.
  Future<void> seedSceneChange(
    CreateHarness harness, {
    bool towerAudio = false,
  }) async {
    final audioDir = Directory('${demoDir(harness).path}/audio');
    await audioDir.create(recursive: true);
    await File(
      CreateHarness.asset(
        'audiopapkin-dark-atmosphere-background-007-312379.mp3',
      ),
    ).copy('${audioDir.path}/a1.wav');
    if (towerAudio) {
      await File(
        CreateHarness.asset(
          'audiopapkin-dark-atmosphere-background-007-312379.mp3',
        ),
      ).copy('${audioDir.path}/a2.wav');
    }
    await seedDemo(
      harness,
      scenes: [
        const {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'standard',
          'audio': ['a1'],
          'next_scenes': ['s2'],
        },
        {
          'scene_uuid': 's2',
          'name': 'Tower',
          'scene_type': 'standard',
          if (towerAudio) 'audio': const ['a2'],
        },
      ],
    );
  }

  testWidgets('play: Preview opens the Play view and shows the scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedRich(harness);

    await harness.pumpApp(tester);
    await openScenes(tester);
    await openPreview(tester, 's1');

    expect(find.byKey(const ValueKey('play.root')), findsOne);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Cave',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('play.scene.narration')))
          .data,
      'A dark cave.',
    );
    // Key events row + next scenes row.
    expect(find.byKey(const ValueKey('play.keyevent.Met duke')), findsOne);
    expect(find.byKey(const ValueKey('play.nextscene.Tower')), findsOne);
    // The next-scene button carries the target scene's path disc (yellow).
    expect(
      find.byKey(const ValueKey('play.nextscene.Tower.path.yellow')),
      findsOne,
    );
    // Standard scene -> the Ad-hoc button is present.
    expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsOne);
    // Rail always has Pause; there is NO Narration item (narration is always in
    // the left column) and no Location item.
    expect(find.byKey(const ValueKey('nav.play.pause')), findsOne);
    expect(find.byKey(const ValueKey('nav.play.scene')), findsNothing);
    expect(find.byKey(const ValueKey('nav.play.location')), findsNothing);
    // Default right panel = NPC (the scene has an NPC), shown beside the always-
    // visible narration.
    expect(find.byKey(const ValueKey('play.npc.grid')), findsOne);
  });

  testWidgets(
    'BRANCH keyevent_toggle: tapping a key event toggles its checkbox',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      Checkbox box() => tester.widget<Checkbox>(
        find.byKey(const ValueKey('play.keyevent.Met duke.check')),
      );
      expect(box().value, isFalse);
      await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
      await tester.pumpAndSettle();
      expect(box().value, isTrue);
    },
  );

  // Two scenes that BOTH list the key event "Met duke": Cave -> Tower. Lets a
  // test check the event in Cave and observe it carried (and hidden) in Tower.
  Future<void> seedCarry(CreateHarness harness) => seedDemo(
    harness,
    keyEvents: const [
      {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
    ],
    scenes: const [
      {
        'scene_uuid': 's1',
        'name': 'Cave',
        'scene_type': 'standard',
        'key_events': ['Met duke'],
        'next_scenes': ['s2'],
      },
      {
        'scene_uuid': 's2',
        'name': 'Tower',
        'scene_type': 'standard',
        'key_events': ['Met duke'],
      },
    ],
  );

  testWidgets(
    'BRANCH keyevent_checked_carries_and_hidden: a checked key event carries to the '
    'next scene and is omitted from its row',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedCarry(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      final before = await File(
        '${demoDir(harness).path}/LivingScroll.json',
      ).readAsString();

      // Cave: check "Met duke", then follow Tower.
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('play.keyevent.Met duke.check')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('play.keyevent.Met duke.check')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();

      // Tower: the carried-checked event is omitted; its row + legend indicator gone.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Tower',
      );
      expect(
        find.byKey(const ValueKey('play.keyevent.Met duke')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('play.keyevents.row.box')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('play.keyevents.indicator')),
        findsNothing,
      );

      // The carry is session-only: nothing was written to disk.
      expect(
        await File('${demoDir(harness).path}/LivingScroll.json').readAsString(),
        before,
      );
    },
  );

  testWidgets(
    'BRANCH keyevent_unchecked_not_hidden: an unchecked key event still shows in the '
    'next scene',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedCarry(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Do NOT check the event; follow Tower.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();

      // Tower still shows "Met duke" (it was not checked upstream), unchecked.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Tower',
      );
      expect(find.byKey(const ValueKey('play.keyevent.Met duke')), findsOne);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('play.keyevent.Met duke.check')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'BRANCH keyevent_reset_on_fresh_preview: re-opening a preview resets the carried '
    'checked state',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedCarry(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Check + follow Tower: the event is hidden there.
      await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play.keyevent.Met duke')),
        findsNothing,
      );

      // Pause back to the editor, then re-open Cave's preview from its tile.
      await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
      await tester.pumpAndSettle();
      await openPreview(tester, 's1');

      // Fresh session: the event is unchecked and shown again.
      expect(find.byKey(const ValueKey('play.keyevent.Met duke')), findsOne);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('play.keyevent.Met duke.check')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'BRANCH adhoc_hidden_on_end: an ending scene hides the Ad-hoc button',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness, type: 'end');

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH rail_conditional: NPC/Notes/Images rail items appear only when present',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Scene has an NPC but no notes / images.
      await seedDemo(
        harness,
        npcs: const [
          {'npc_uuid': 'p1', 'name': 'Guard'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'npcs': ['Guard'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(find.byKey(const ValueKey('nav.play.npc')), findsOne);
      expect(find.byKey(const ValueKey('nav.play.notes')), findsNothing);
      expect(find.byKey(const ValueKey('nav.play.images')), findsNothing);
    },
  );

  testWidgets('BRANCH pause_preview_pops: Pause in preview returns to Scenes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedRich(harness);

    await harness.pumpApp(tester);
    await openScenes(tester);
    await openPreview(tester, 's1');
    expect(find.byKey(const ValueKey('play.root')), findsOne);

    await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
    await tester.pumpAndSettle();

    // Back on the Scenes list; no gameplay save prompt in preview.
    expect(find.byKey(const ValueKey('play.root')), findsNothing);
    expect(find.byKey(const ValueKey('play.pause.dialog')), findsNothing);
    expect(find.byKey(const ValueKey('scene.list')), findsOne);
  });

  testWidgets(
    'BRANCH panel_selectors: narration stays in the left column; rail items fill the right column',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Narration is ALWAYS visible in the left column. The scene has an NPC, so
      // the default right panel is the NPC grid. There is NO Narration rail item.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.narration')))
            .data,
        'A dark cave.',
      );
      expect(find.byKey(const ValueKey('play.npc.grid')), findsOne);
      expect(find.byKey(const ValueKey('nav.play.scene')), findsNothing);
      // The right column carries a header naming the shown panel (default NPC),
      // matching the rail item that selects it.
      expect(panelTitle(tester), l10nOf(tester).sceneSectionNpc);

      // Notes -> the right column becomes the notes list; the NPC grid is gone;
      // narration STAYS; the bottom rows remain; the header updates to "Notes".
      await tester.tap(find.byKey(const ValueKey('nav.play.notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.npc.grid')), findsNothing);
      expect(find.byKey(const ValueKey('play.notes.center')), findsOne);
      expect(panelTitle(tester), l10nOf(tester).sceneSectionNotes);
      expect(find.byKey(const ValueKey('play.note.tile.n1')), findsOne);
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
      expect(find.byKey(const ValueKey('play.keyevent.Met duke')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscene.Tower')), findsOne);

      // Images -> the right column becomes the image grid; notes cleared;
      // narration stays; the header updates to "Images".
      await tester.tap(find.byKey(const ValueKey('nav.play.images')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.notes.center')), findsNothing);
      expect(find.byKey(const ValueKey('play.images.center')), findsOne);
      expect(panelTitle(tester), l10nOf(tester).sceneSectionImages);
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);

      // NPC -> back to the NPC grid; narration still present throughout; header
      // back to "NPC".
      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.images.center')), findsNothing);
      expect(find.byKey(const ValueKey('play.npc.grid')), findsOne);
      expect(panelTitle(tester), l10nOf(tester).sceneSectionNpc);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.narration')))
            .data,
        'A dark cave.',
      );
    },
  );

  testWidgets(
    'BRANCH default_panel_order: with no NPC the right column opens on Notes (before Images)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // A scene with notes AND images but NO NPC -> default panel is Notes.
      final imgDir = Directory('${demoDir(harness).path}/images/other');
      await imgDir.create(recursive: true);
      await File(
        CreateHarness.asset('cover_sample.jpg'),
      ).copy('${imgDir.path}/img1.png');
      await seedDemo(
        harness,
        notes: const [
          {'note_uuid': 'n1', 'note_name': 'Clue', 'note_content': 'x'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'description': 'A dark cave.',
            'notes': ['n1'],
            'images': ['img1'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Notes wins the default; the images grid is not shown until selected. The
      // header names the default panel "Notes".
      expect(find.byKey(const ValueKey('play.notes.center')), findsOne);
      expect(panelTitle(tester), l10nOf(tester).sceneSectionNotes);
      expect(find.byKey(const ValueKey('play.images.center')), findsNothing);
      // Narration is present on the left; no NPC rail item.
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
      expect(find.byKey(const ValueKey('nav.play.npc')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH default_panel_gmnotes_fallback: with no NPC/Notes/Images the right column opens on GM Notes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        scenes: const [
          {'scene_uuid': 's1', 'name': 'Cave', 'scene_type': 'standard'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // GM Notes is the fallback right panel; narration is still on the left; the
      // header names it "GM Notes".
      expect(find.byKey(const ValueKey('play.gmnotes.center')), findsOne);
      expect(panelTitle(tester), l10nOf(tester).playGmNotes);
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
    },
  );

  testWidgets(
    'BRANCH npc_grid_and_info: NPC swaps narration for the grid; a tile opens the info window',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Narration always visible; NPC rail item present (scene has Guard); the NPC
      // grid is the default right panel.
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
      expect(find.byKey(const ValueKey('nav.play.npc')), findsOne);

      // The NPC grid fills the right column while the narration STAYS on the left.
      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
      expect(find.byKey(const ValueKey('play.npc.grid')), findsOne);
      expect(find.byKey(const ValueKey('play.npc.tile.p1')), findsOne);
      // The tile has NO context menu (game.npc tile menu key absent).
      expect(find.byKey(const ValueKey('game.npc.tile.menu.p1')), findsNothing);

      // Tapping the tile opens the read-only info window.
      await tester.tap(find.byKey(const ValueKey('play.npc.tile.p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.npc.info.p1')), findsOne);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.npc.info.p1.name')))
            .data,
        'Guard',
      );
      // Description now sits in the right column (the form's backstory slot).
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('play.npc.info.p1.description')),
            )
            .data,
        'A stern guard.',
      );
      // Backstory is NOT shown inline; no stats block for Basic RPG.
      expect(
        find.byKey(const ValueKey('play.npc.info.p1.backstory')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('play.npc.info.p1.stats')),
        findsNothing,
      );
      // No visibility-rules block and no icon_image block in the window.
      expect(find.byKey(const ValueKey('vis.root')), findsNothing);
      expect(
        find.byKey(const ValueKey('play.npc.info.p1.icon_image')),
        findsNothing,
      );
      // Guard has a backstory ("Born here.") -> Historia is shown, plus Close.
      expect(find.byKey(const ValueKey('play.npc.info.p1.history')), findsOne);
      expect(find.byKey(const ValueKey('play.npc.info.p1.close')), findsOne);
    },
  );

  testWidgets(
    'BRANCH npc_history_hidden_when_empty: Historia is hidden when the NPC has '
    'no backstory',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness, npcBackstory: '');

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.npc.tile.p1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('play.npc.info.p1')), findsOne);
      // Empty backstory -> no Historia button; Close stays.
      expect(
        find.byKey(const ValueKey('play.npc.info.p1.history')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('play.npc.info.p1.close')), findsOne);
    },
  );

  testWidgets(
    'BRANCH npc_deactivate_toggle: the deactivate button greys the tile '
    '(session-only) and a second tap restores it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);
      final doc = File('${demoDir(harness).path}/LivingScroll.json');
      final before = await doc.readAsString();

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      // Active NPC: not greyed, deactivate button present.
      expect(npcTileGreyed(tester, 'p1'), isFalse);
      expect(
        find.byKey(const ValueKey('play.npc.tile.p1.deactivate')),
        findsOne,
      );

      // Tap the deactivate button -> the tile greys; the button stays (toggleable).
      await tester.tap(
        find.byKey(const ValueKey('play.npc.tile.p1.deactivate')),
      );
      await tester.pumpAndSettle();
      expect(npcTileGreyed(tester, 'p1'), isTrue);
      expect(
        find.byKey(const ValueKey('play.npc.tile.p1.deactivate')),
        findsOne,
      );
      // Preview never persists.
      expect(await doc.readAsString(), before);

      // A second tap restores the colour.
      await tester.tap(
        find.byKey(const ValueKey('play.npc.tile.p1.deactivate')),
      );
      await tester.pumpAndSettle();
      expect(npcTileGreyed(tester, 'p1'), isFalse);
    },
  );

  testWidgets(
    'BRANCH npc_inactive_hidden: the NPC grid lists only active NPCs — an '
    'inactive NPC is not shown',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Two NPCs on the scene: Guard inactive, Sentry active.
      await seedDemo(
        harness,
        npcs: const [
          {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'inactive'},
          {'npc_uuid': 'p2', 'name': 'Sentry', 'state': 'active'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'npcs': ['Guard', 'Sentry'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // At least one active NPC -> the rail item shows.
      expect(find.byKey(const ValueKey('nav.play.npc')), findsOne);
      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      // Only the active NPC is listed; the inactive one has no tile.
      expect(find.byKey(const ValueKey('play.npc.tile.p2')), findsOne);
      expect(
        find.byKey(const ValueKey('play.npc.tile.p2.deactivate')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('play.npc.tile.p1')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH npc_inactive_hidden: when every attached NPC is inactive the NPC '
    'rail item is hidden',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Both NPCs inactive -> no visible NPC on the scene.
      await seedDemo(
        harness,
        npcs: const [
          {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'inactive'},
          {'npc_uuid': 'p2', 'name': 'Sentry', 'state': 'inactive'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'npcs': ['Guard', 'Sentry'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(find.byKey(const ValueKey('nav.play.npc')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH npc_history_window: Historia raises the backstory window over the info window',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Open the NPC grid, then the info window.
      await tester.tap(find.byKey(const ValueKey('nav.play.npc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.npc.tile.p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.npc.info.p1')), findsOne);

      // Historia raises the backstory window on top.
      await tester.tap(find.byKey(const ValueKey('play.npc.info.p1.history')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.npc.history.p1')), findsOne);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('play.npc.history.p1.backstory')),
            )
            .data,
        'Born here.',
      );

      // Close returns to the info window beneath.
      await tester.tap(find.byKey(const ValueKey('play.npc.history.p1.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.npc.history.p1')), findsNothing);
      expect(find.byKey(const ValueKey('play.npc.info.p1')), findsOne);
    },
  );

  testWidgets(
    'BRANCH background_full_window: bg_image fills the window; rail toggle keeps its size',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      final bg = find.byKey(const ValueKey('play.location.image'));
      expect(bg, findsOne);
      // Spans the full window width (behind the rail), not just the stage area.
      final before = tester.getSize(bg);
      expect(before.width, 1200);

      // Expanding the rail must NOT resize the background.
      await tester.tap(find.byKey(const ValueKey('nav.play.menu')));
      await tester.pumpAndSettle();
      expect(tester.getSize(bg), before);
    },
  );

  testWidgets(
    'BRANCH notes_tile_and_window: name-only tiles; tapping opens the content window',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Open the Notes list: a tile shows just the name, not the content.
      await tester.tap(find.byKey(const ValueKey('nav.play.notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.notes.center')), findsOne);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.note.tile.n1.label')))
            .data,
        'Clue',
      );
      expect(find.text('A hidden lever.'), findsNothing);

      // Tapping the tile opens the note content window, which renders the body
      // with flutter_quill (read-only), not a plain Text.
      await tester.tap(find.byKey(const ValueKey('play.note.tile.n1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.note.info.n1')), findsOne);
      expect(find.byKey(const ValueKey('play.note.info.n1.content')), findsOne);
      expect(find.byType(QuillEditor), findsOneWidget);

      // Close returns to the notes list.
      await tester.tap(find.byKey(const ValueKey('play.note.info.n1.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.note.info.n1')), findsNothing);
      expect(find.byKey(const ValueKey('play.notes.center')), findsOne);
    },
  );

  testWidgets(
    'BRANCH note_richtext_and_image: the content window renders flutter_quill '
    'formatting AND an embedded image',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // A rich body: a bold run + an embedded adventure image (other:img1, whose
      // file seedRich materializes at images/other/img1.png).
      final richNote = jsonEncode([
        {
          'insert': 'Important',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
        {
          'insert': {'image': 'other:img1'},
        },
        {'insert': '\n'},
      ]);
      await seedRich(harness, noteContent: richNote);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      await tester.tap(find.byKey(const ValueKey('nav.play.notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.note.tile.n1')));
      await tester.pumpAndSettle();

      // The window renders a read-only Quill editor with the embedded image
      // resolved to an on-disk file (keyed by its <scope>:<uuid> reference).
      expect(find.byKey(const ValueKey('play.note.info.n1')), findsOne);
      expect(find.byType(QuillEditor), findsOneWidget);
      final embed = find.byKey(
        const ValueKey('game.notes.edit.content.image.other:img1'),
      );
      expect(embed, findsOne);
      expect(
        tester.widget(embed),
        isA<Image>(),
      ); // resolved image, not the broken glyph
    },
  );

  testWidgets(
    'BRANCH image_viewer: Images grid shows photo cells; tapping one opens the viewer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Open the Images grid: a square photo cell, no delete button.
      await tester.tap(find.byKey(const ValueKey('nav.play.images')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.images.center')), findsOne);
      expect(find.byKey(const ValueKey('play.image.tile.img1')), findsOne);
      expect(
        find.byKey(const ValueKey('image.tile.img1.delete')),
        findsNothing,
      );

      // Tapping the cell opens the full-size viewer.
      await tester.tap(find.byKey(const ValueKey('play.image.tile.img1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.image.viewer.img1')), findsOne);
      expect(
        find.byKey(const ValueKey('play.image.viewer.img1.image')),
        findsOne,
      );

      // The close button pops the viewer off the top of the stack.
      await tester.tap(
        find.byKey(const ValueKey('play.image.viewer.img1.close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play.image.viewer.img1')),
        findsNothing,
      );
    },
  );

  testWidgets('BRANCH follow_next_scene: following a next scene previews it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedRich(harness);

    await harness.pumpApp(tester);
    await openScenes(tester);
    await openPreview(tester, 's1');

    // Follow "Tower" -> a fresh preview titled "Tower".
    await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Tower',
    );
  });

  testWidgets(
    'BRANCH follow_then_pause_exits_to_editor: Pause after a follow exits the whole preview',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Follow "Tower" (replaces the route, so the preview is still a single route).
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Tower',
      );

      // Pause exits the whole preview straight to the editor — not back to "Cave".
      await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.root')), findsNothing);
      expect(find.byKey(const ValueKey('scene.list')), findsOne);
    },
  );

  testWidgets(
    'BRANCH adhoc_inherits_next_scenes: ad-hoc scene inherits the current next scenes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Cave offers "Tower" and the Ad-hoc button.
      expect(find.byKey(const ValueKey('play.nextscene.Tower')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsOne);

      // Start an ad-hoc scene -> the name dialog opens; name it, then Confirm.
      final before = await File(
        '${demoDir(harness).path}/LivingScroll.json',
      ).readAsString();
      await tester.tap(find.byKey(const ValueKey('play.nextscene.adhoc')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.adhoc.dialog')), findsOne);
      // Confirm is disabled while the name is blank.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('play.adhoc.confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('play.adhoc.name')),
        'Detour',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play.adhoc.confirm')));
      await tester.pumpAndSettle();

      // The ad-hoc scene shows the entered name as its title.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Detour',
      );
      // No narration of its own: the narration block is present but empty.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.narration')))
            .data,
        '',
      );

      // ...but the SAME next scenes as Cave (Tower, with its yellow path disc) and
      // its own Ad-hoc button (it is a standard scene).
      expect(find.byKey(const ValueKey('play.nextscene.Tower')), findsOne);
      expect(
        find.byKey(const ValueKey('play.nextscene.Tower.path.yellow')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('play.nextscene.adhoc')), findsOne);

      // Preview never persists.
      expect(
        await File('${demoDir(harness).path}/LivingScroll.json').readAsString(),
        before,
      );

      // Single route: Pause exits the whole preview to the editor, not back to Cave.
      await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.root')), findsNothing);
      expect(find.byKey(const ValueKey('scene.list')), findsOne);
    },
  );

  testWidgets(
    'BRANCH bottom_buttons_equal_height: key-event and next-scene buttons share one height',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      final keyEvent = tester.getSize(
        find.byKey(const ValueKey('play.keyevent.Met duke')),
      );
      final nextScene = tester.getSize(
        find.byKey(const ValueKey('play.nextscene.Tower')),
      );
      expect(keyEvent.height, nextScene.height);
    },
  );

  testWidgets(
    'BRANCH bottom_indicators_aligned: rail legend indicators track their bottom rows as they wrap',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // Several key events / next scenes so both rows wrap when the window narrows.
      const nexts = ['North', 'South', 'East', 'West', 'Center'];
      await seedDemo(
        harness,
        keyEvents: const [
          {'key_event_uuid': 'k1', 'name': 'Alpha', 'state': 'unchecked'},
          {'key_event_uuid': 'k2', 'name': 'Bravo', 'state': 'unchecked'},
          {'key_event_uuid': 'k3', 'name': 'Charlie', 'state': 'unchecked'},
          {'key_event_uuid': 'k4', 'name': 'Delta', 'state': 'unchecked'},
          {'key_event_uuid': 'k5', 'name': 'Echo', 'state': 'unchecked'},
        ],
        scenes: [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'key_events': const ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'],
            'next_scenes': [for (final n in nexts) 's_$n'],
          },
          for (final n in nexts)
            {'scene_uuid': 's_$n', 'name': n, 'scene_type': 'standard'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      double h(String key) => tester.getSize(find.byKey(ValueKey(key))).height;

      // Both indicators are present and each equals its row band's height.
      expect(find.byKey(const ValueKey('play.keyevents.indicator')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscenes.indicator')), findsOne);
      expect(h('play.keyevents.indicator'), h('play.keyevents.row.box'));
      expect(h('play.nextscenes.indicator'), h('play.nextscenes.row.box'));
      final wideKeyH = h('play.keyevents.row.box');

      // Narrow the window: the rows wrap to more lines and the listener re-syncs
      // the indicators to the new, taller heights.
      tester.view.physicalSize = const Size(520, 900);
      await tester.pumpAndSettle();
      expect(h('play.keyevents.row.box'), greaterThan(wideKeyH));
      expect(h('play.keyevents.indicator'), h('play.keyevents.row.box'));
      expect(h('play.nextscenes.indicator'), h('play.nextscenes.row.box'));
    },
  );

  testWidgets(
    'BRANCH bottom_indicators_left_aligned: legend icons sit on the destinations\' axis when expanded',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Expand the rail so labels show and alignment is observable.
      await tester.tap(find.byKey(const ValueKey('nav.play.menu')));
      await tester.pumpAndSettle();

      double cx(String key) =>
          tester.getRect(find.byKey(ValueKey(key))).center.dx;

      // Each legend icon shares the destination icons' centre-x (leading box,
      // minWidth / 2) — i.e. it is left-aligned like the destinations, not centred
      // in the wide expanded rail. (Pause is an always-present destination.)
      final destCx = cx('nav.play.pause');
      expect(
        cx('play.keyevents.indicator.icon'),
        moreOrLessEquals(destCx, epsilon: 0.5),
      );
      expect(
        cx('play.nextscenes.indicator.icon'),
        moreOrLessEquals(destCx, epsilon: 0.5),
      );
    },
  );

  testWidgets(
    'BRANCH soundtrack_autoplay_and_toggle: music autoplays (Music Off glyph) and the rail item toggles it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedWithAudio(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // The Soundtrack rail item is present and, with Autoplay on (default), the
      // music started LOOPING — so the glyph is Music Off and play was requested.
      expect(find.byKey(const ValueKey('nav.play.soundtrack')), findsOne);
      expect(soundtrackGlyph(tester), Icons.music_off);
      expect(harness.lastPlayed, endsWith('a1.wav'));
      expect(harness.lastPlayLooped, isTrue);

      // Tapping Music Off PAUSES (does not stop): glyph becomes Music Note.
      expect(harness.audioPauseCount, 0);
      await tester.tap(find.byKey(const ValueKey('nav.play.soundtrack')));
      await tester.pumpAndSettle();
      expect(soundtrackGlyph(tester), Icons.music_note);
      expect(harness.audioPauseCount, 1);
      expect(harness.audioStopCount, 0); // paused, not stopped

      // Tapping again RESUMES from the paused position (resume, not a fresh play).
      await tester.tap(find.byKey(const ValueKey('nav.play.soundtrack')));
      await tester.pumpAndSettle();
      expect(soundtrackGlyph(tester), Icons.music_off);
      expect(harness.audioResumeCount, 1);
    },
  );

  testWidgets(
    'BRANCH soundtrack_absent: a scene without music has no Soundtrack rail item',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness); // no audio attached

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(find.byKey(const ValueKey('nav.play.soundtrack')), findsNothing);
      expect(harness.lastPlayed, isNull);
    },
  );

  testWidgets(
    'BRANCH soundtrack_autoplay_off: with Autoplay off the music does NOT start (Music Note glyph)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await harness.writeOverrides({'autoplay': false});
      await seedWithAudio(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Autoplay off: the item is present but music has not started.
      expect(find.byKey(const ValueKey('nav.play.soundtrack')), findsOne);
      expect(soundtrackGlyph(tester), Icons.music_note);
      expect(harness.lastPlayed, isNull);

      // The user can still start it from the rail item — it begins looping.
      await tester.tap(find.byKey(const ValueKey('nav.play.soundtrack')));
      await tester.pumpAndSettle();
      expect(soundtrackGlyph(tester), Icons.music_off);
      expect(harness.lastPlayed, endsWith('a1.wav'));
      expect(harness.lastPlayLooped, isTrue);
    },
  );

  testWidgets(
    'BRANCH soundtrack_stops_on_scene_change: following a music-less scene stops the music',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedSceneChange(harness); // Tower has no music

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Cave autoplays its music.
      expect(soundtrackGlyph(tester), Icons.music_off);
      expect(harness.lastPlayed, endsWith('a1.wav'));
      final stopsBefore = harness.audioStopCount;

      // Follow "Tower" (no music): the music stops and Tower has no Soundtrack item.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Tower',
      );
      expect(find.byKey(const ValueKey('nav.play.soundtrack')), findsNothing);
      expect(harness.audioStopCount, greaterThan(stopsBefore)); // music stopped
      expect(harness.lastPlayed, endsWith('a1.wav')); // no new track played
    },
  );

  testWidgets(
    'BRANCH soundtrack_changes_on_scene_change: a new scene with music plays its own',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedSceneChange(harness, towerAudio: true); // Tower has music a2

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(harness.lastPlayed, endsWith('a1.wav'));

      // Follow "Tower": its OWN music (a2) now plays, looping.
      await tester.tap(find.byKey(const ValueKey('play.nextscene.Tower')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('play.scene.title')))
            .data,
        'Tower',
      );
      expect(find.byKey(const ValueKey('nav.play.soundtrack')), findsOne);
      expect(soundtrackGlyph(tester), Icons.music_off);
      expect(harness.lastPlayed, endsWith('a2.wav'));
      expect(harness.lastPlayLooped, isTrue);
    },
  );

  testWidgets(
    'BRANCH nextscene_visibility: a next-scene button is gated by its target visibility_rules',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // "Cave" points to "Tower" (ungated) and "Secret" (gated on key event k1).
      await seedDemo(
        harness,
        keyEvents: const [
          {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'scene_type': 'standard',
            'key_events': ['Met duke'],
            'next_scenes': ['s2', 's3'],
          },
          {'scene_uuid': 's2', 'name': 'Tower', 'scene_type': 'standard'},
          {
            'scene_uuid': 's3',
            'name': 'Secret',
            'scene_type': 'standard',
            'visibility_rules': {
              'op': 'or',
              'key_events': ['k1'],
            },
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // Ungated "Tower" shows; gated "Secret" is hidden until k1 is checked.
      expect(find.byKey(const ValueKey('play.nextscene.Tower')), findsOne);
      expect(find.byKey(const ValueKey('play.nextscene.Secret')), findsNothing);

      // Checking the gating key event reveals the gated next scene.
      await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.nextscene.Secret')), findsOne);

      // Un-checking it hides the button again.
      await tester.tap(find.byKey(const ValueKey('play.keyevent.Met duke')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play.nextscene.Secret')), findsNothing);
    },
  );

  testWidgets(
    'BRANCH left_column_fixed_width: the narration column fills its 45%-of-field cap even with little content',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // seedRich has a SHORT narration ("A dark cave."): the column must still be
      // the full 45%, not shrunk to the text.
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      // The bottom next-scenes row spans the full field width -> the field ref.
      final fieldWidth = tester
          .getSize(find.byKey(const ValueKey('play.nextscenes.row.box')))
          .width;
      final columnWidth = tester
          .getSize(find.byKey(const ValueKey('play.narration.column')))
          .width;
      // Fixed at exactly 45% of the field, regardless of the short content.
      expect(columnWidth, moreOrLessEquals(fieldWidth * 0.45, epsilon: 0.5));
    },
  );

  testWidgets(
    'BRANCH field_narrows_for_expanded_rail: expanding the rail shrinks the field and the narration column',
    (tester) async {
      // A narrow (tablet-portrait-ish) window so the expanded rail visibly eats width.
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      double fieldWidth() => tester
          .getSize(find.byKey(const ValueKey('play.nextscenes.row.box')))
          .width;
      double columnWidth() => tester
          .getSize(find.byKey(const ValueKey('play.narration.column')))
          .width;

      final fieldBefore = fieldWidth();
      final columnBefore = columnWidth();

      // Expand the rail: it takes horizontal space, so the Expanded field shrinks,
      // and with it the 45% narration column.
      await tester.tap(find.byKey(const ValueKey('nav.play.menu')));
      await tester.pumpAndSettle();

      expect(fieldWidth(), lessThan(fieldBefore));
      expect(columnWidth(), lessThan(columnBefore));
      // The column stays at 45% of the now-smaller field.
      expect(
        columnWidth(),
        moreOrLessEquals(fieldWidth() * 0.45, epsilon: 0.5),
      );
    },
  );

  testWidgets('BRANCH villains_tab: lists every villain in the adventure, greys an '
      'inactive one instead of hiding it, has no deactivate button, opens the '
      'same info window as NPC, and is ALWAYS the LAST rail item with a label '
      'spelling out "(global)"', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      system: '7thsea2e',
      npcs: const [
        {
          'npc_uuid': 'v1',
          'name': 'Duke',
          'description': 'A cruel duke.',
          'stats': {'kind': 'villain', 'strength': 6, 'influence': 5},
        },
        {
          'npc_uuid': 'v2',
          'name': 'Countess',
          'description': 'Unseen elsewhere.',
          'stats': {'kind': 'villain', 'strength': 4, 'influence': 3},
        },
        {
          'npc_uuid': 'v3',
          'name': 'Baron',
          'state': 'inactive',
          'stats': {'kind': 'villain', 'strength': 2, 'influence': 2},
        },
        {
          'npc_uuid': 'm1',
          'name': 'Cutpurse',
          'stats': {'kind': 'monster'},
        },
      ],
      scenes: const [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'standard',
          'description': 'A dark cave.',
          'npcs': ['Duke'], // only Duke is scene-attached
        },
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);
    await openPreview(tester, 's1');

    // The rail item shows (the adventure has villains) and selects the grid.
    expect(find.byKey(const ValueKey('nav.play.villains')), findsOne);

    // ALWAYS the LAST rail item — below GM Notes and below the other
    // conditional item present here (NPC, since Duke is scene-attached).
    final villainsY = tester
        .getTopLeft(find.byKey(const ValueKey('nav.play.villains')))
        .dy;
    expect(
      villainsY,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('nav.play.gmnotes'))).dy,
      ),
    );
    expect(
      villainsY,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('nav.play.npc'))).dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav.play.villains')));
    await tester.pumpAndSettle();

    // Narration stays on the left; the right column becomes the Villains grid.
    expect(find.byKey(const ValueKey('play.scene.narration')), findsOne);
    expect(find.byKey(const ValueKey('play.villains.grid')), findsOne);
    // The label spells out "(global)" / "(wszyscy)" — the ONE rail item that
    // is not scene-scoped. Compared against the ARB source of truth rather
    // than a hardcoded string, so the assertion holds under any locale.
    expect(panelTitle(tester), l10nOf(tester).playVillains);

    // Every villain shows, scene-attached or not; the non-villain NPC is excluded.
    expect(find.byKey(const ValueKey('play.villain.tile.v1')), findsOne);
    expect(find.byKey(const ValueKey('play.villain.tile.v2')), findsOne);
    expect(find.byKey(const ValueKey('play.villain.tile.v3')), findsOne);
    expect(find.byKey(const ValueKey('play.villain.tile.m1')), findsNothing);

    // Inactive villain (v3) is greyed, NOT hidden; active ones are not greyed.
    expect(villainTileGreyed(tester, 'v1'), isFalse);
    expect(villainTileGreyed(tester, 'v3'), isTrue);

    // No deactivate button anywhere in this grid.
    expect(
      find.byKey(const ValueKey('play.villain.tile.v1.deactivate')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('play.villain.tile.v3.deactivate')),
      findsNothing,
    );

    // Villain badges show, same as the NPC tab.
    expect(
      find.byKey(const ValueKey('play.villain.tile.v1.villain.strength.value')),
      findsOne,
    );

    // Tapping a tile (including one NOT attached to the scene) opens the SAME
    // info window as the NPC tab, Schemes/Intrygi action included.
    await tester.tap(find.byKey(const ValueKey('play.villain.tile.v2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.npc.info.v2')), findsOne);
    expect(find.byKey(const ValueKey('play.npc.info.v2.name')), findsOne);
    expect(find.byKey(const ValueKey('play.npc.info.v2.schemes')), findsOne);
    await tester.tap(find.byKey(const ValueKey('play.npc.info.v2.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.npc.info.v2')), findsNothing);
  });

  testWidgets(
    'BRANCH villains_tab_absent_for_other_systems: no Villains rail item for a '
    'non-7th-Sea adventure',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedRich(harness); // system: "basic", no villain stats

      await harness.pumpApp(tester);
      await openScenes(tester);
      await openPreview(tester, 's1');

      expect(find.byKey(const ValueKey('nav.play.villains')), findsNothing);
    },
  );
}
