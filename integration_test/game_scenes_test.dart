// Integration test for the scene editor and its pickers.
//
// PATH: open adventure -> Scenes list -> Add scene -> author fields + select a
// path -> Save writes scenes[] (name, description=narration, path_names).
// Branches: existing scene + path-disc colour, delete, search, bg-image picker
// (single select), key events picker (multi-select), notes picker (multi-select),
// create-and-select a key event, and the unsaved-changes rail guard.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

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
    List<Object> audio = const [],
    List<Object> images = const [],
  }) async {
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
        'images': images,
        'audio': audio,
        'paths': paths,
        'key_events': keyEvents,
        'notes': notes,
        'gm_notes': [],
        'npcs': npcs,
        'scenes': scenes,
      }),
    );
  }

  // Launch -> create grid -> open Demo -> game shell (Scenes is the default
  // section).
  Future<void> openScenes(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
  }

  List<Map<String, dynamic>> readScenes(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['scenes']
              as List)
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> readImages(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['images']
              as List)
          .cast<Map<String, dynamic>>();

  // Materializes a background-image FILE at Demo/images/bg_images/<uuid>.png so
  // the Background image picker (which scans that directory) lists it.
  Future<void> seedBgImage(CreateHarness harness, String uuid) async {
    final dir = Directory('${demoDir(harness).path}/images/bg_images');
    await dir.create(recursive: true);
    await File(
      CreateHarness.asset('cover_sample.jpg'),
    ).copy('${dir.path}/$uuid.png');
  }

  Directory bgImagesDir(CreateHarness harness) =>
      Directory('${demoDir(harness).path}/images/bg_images');

  // Rail indices (game_screen.dart destination order).
  const scenesIndex = 2;
  const npcsIndex = 3;
  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;
  final unsavedDialog = find.byKey(const ValueKey('settings.unsaved.dialog'));

  testWidgets('game_scenes: add a scene with a path -> written to disk', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      paths: const [
        {'name': 'Main', 'color': 'yellow', 'description': ''},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.narration')),
      'A dark cave.',
    );
    await tester.pumpAndSettle();

    // The Notes / Key events / Soundtrack buttons all use the enlarged (70%)
    // icon (~30.6px over the ~18px button default).
    for (final k in const [
      'game.scenes.edit.notes.add',
      'game.scenes.edit.keyevents.add',
      'game.scenes.edit.audio.button',
    ]) {
      final ic = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey(k)),
          matching: find.byType(Icon),
        ),
      );
      expect(ic.size, moreOrLessEquals(18 * 1.7, epsilon: 0.01));
      // ...and are 20% taller than the 40px default (minimumSize height 48).
      final btn = tester.widget<ButtonStyleButton>(find.byKey(ValueKey(k)));
      expect(btn.style?.minimumSize?.resolve(<WidgetState>{})?.height, 48);
    }

    // Toggle the "Main" path (yellow) in the Paths multi-select.
    final pathRow = find.byKey(const ValueKey('game.scenes.edit.paths.yellow'));
    await tester.ensureVisible(pathRow);
    await tester.pumpAndSettle();

    // The Visibility-rules heading appears exactly once — the section divider
    // (in the same row, now on-screen); the shared editor's built-in heading is
    // suppressed so the text is not duplicated. Read the divider's own label so
    // the assertion is locale-independent.
    final visTitle = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(
              const ValueKey('game.scenes.edit.section.visibility'),
            ),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(find.text(visTitle), findsOneWidget);

    // The path-colour disc is on the LEFT of the row (before the checkbox), is
    // 36px (200% of the 18px checkbox), and is the path colour.
    final disc = find.byKey(
      const ValueKey('game.scenes.edit.paths.yellow.disc'),
    );
    expect(disc, findsOne);
    final discSize = tester.getSize(disc);
    expect(discSize.width, moreOrLessEquals(36, epsilon: 0.5));
    expect(discSize.height, moreOrLessEquals(36, epsilon: 0.5));
    final checkbox = find.descendant(
      of: pathRow,
      matching: find.byType(Checkbox),
    );
    expect(
      tester.getTopLeft(disc).dx,
      lessThan(tester.getTopLeft(checkbox).dx),
    );
    expect(
      (tester.widget<Container>(disc).decoration as BoxDecoration).color,
      const Color(0xFFF0C800),
    );

    await tester.tap(pathRow);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    final scenes = readScenes(harness);
    expect(scenes.length, 1);
    expect(scenes.single['name'], 'Cave');
    expect(scenes.single['description'], 'A dark cave.');
    expect((scenes.single['path_names'] as List).cast<String>(), ['Main']);
    // Typ sceny untouched -> the default scene_type is persisted.
    expect(scenes.single['scene_type'], 'standard');
  });

  testWidgets(
    'BRANCH existing_loaded: a seeded scene shows its tile + path disc',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        paths: const [
          {'name': 'Main', 'color': 'yellow', 'description': ''},
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'path_names': ['Main'],
          },
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);

      expect(find.byKey(const ValueKey('scene.tile.s1')), findsOne);
      expect(find.byKey(const ValueKey('scene.tile.s1.name')), findsOne);

      // The path disc is rendered in the path's literal colour (#F0C800 yellow).
      final discFinder = find.byKey(
        const ValueKey('scene.tile.s1.path.yellow'),
      );
      expect(discFinder, findsOne);
      final box = tester.widget<DecoratedBox>(discFinder);
      expect((box.decoration as BoxDecoration).color, const Color(0xFFF0C800));
    },
  );

  testWidgets(
    'BRANCH scenetype_icon: each tile leading glyph matches its scene_type',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        scenes: const [
          {'scene_uuid': 's1', 'name': 'A', 'scene_type': 'start'},
          {'scene_uuid': 's2', 'name': 'B', 'scene_type': 'standard'},
          {'scene_uuid': 's3', 'name': 'C', 'scene_type': 'recurring'},
          {'scene_uuid': 's4', 'name': 'D', 'scene_type': 'end'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);

      Finder iconInTile(String uuid, IconData icon) => find.descendant(
        of: find.byKey(ValueKey('scene.tile.$uuid')),
        matching: find.byIcon(icon),
      );

      // The leading glyph is the scene_type icon (sceneTypeIcon), matching the
      // new_scene form's type radios — NOT the former generic Icons.videocam.
      expect(iconInTile('s1', Icons.play_circle), findsOne); // start
      expect(iconInTile('s2', Icons.circle), findsOne); // standard
      expect(iconInTile('s3', Icons.change_circle), findsOne); // recurring
      expect(iconInTile('s4', Icons.stop_circle), findsOne); // end
      // No tile in the list still uses the former generic glyph. (The Scenes rail
      // destination keeps its own Icons.videocam, so scope the check to the list.)
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('scene.list')),
          matching: find.byIcon(Icons.videocam),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('BRANCH delete: confirming removes the scene from disk', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      scenes: const [
        {'scene_uuid': 's1', 'name': 'Cave'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.tile.s1.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene.delete.confirm')));
    await tester.pumpAndSettle();

    expect(readScenes(harness), isEmpty);
    expect(find.byKey(const ValueKey('scene.tile.s1')), findsNothing);
  });

  testWidgets('BRANCH search_filter: query filters the scene list', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      scenes: const [
        {'scene_uuid': 's1', 'name': 'Cave'},
        {'scene_uuid': 's2', 'name': 'Tower'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.enterText(find.byKey(const ValueKey('scene.search')), 'tow');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scene.tile.s2')), findsOne);
    expect(find.byKey(const ValueKey('scene.tile.s1')), findsNothing);
  });

  testWidgets('BRANCH bgimage_select: picking an existing image sets bg_image', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);
    // A background-image FILE already on disk (bg images are files only).
    await seedBgImage(harness, 'im1');

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    // The Background image section sits DIRECTLY BELOW Images and ABOVE Soundtracks.
    double sectionDy(String k) => tester.getTopLeft(find.byKey(ValueKey(k))).dy;
    expect(
      sectionDy('game.scenes.edit.section.images'),
      lessThan(sectionDy('game.scenes.edit.section.bgimage')),
    );
    expect(
      sectionDy('game.scenes.edit.section.bgimage'),
      lessThan(sectionDy('game.scenes.edit.section.audio')),
    );

    // Open the Background image picker (browses images/bg_images/ only).
    final bgBtn = find.byKey(const ValueKey('game.scenes.edit.bgimage.add'));
    await tester.ensureVisible(bgBtn);
    await tester.pumpAndSettle();
    await tester.tap(bgBtn);
    await tester.pumpAndSettle();

    // Tapping the existing bg-image tile returns it and sets bg_image.
    expect(find.byKey(const ValueKey('scene.bgimage.select.root')), findsOne);
    await tester.tap(
      find.byKey(const ValueKey('scene.bgimage.select.tile.im1')),
    );
    await tester.pumpAndSettle();

    // Back on the form: the chosen image's preview tile shows.
    expect(
      find.byKey(const ValueKey('game.scenes.edit.bgimage.tile.im1')),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    expect(readScenes(harness).single['bg_image'], 'im1');
  });

  testWidgets('BRANCH bgimage_add: the picker add cell picks a file -> writes '
      'images/bg_images/ + selects it', (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);
    // The native image picker returns this asset when the add cell is tapped.
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    final bgBtn = find.byKey(const ValueKey('game.scenes.edit.bgimage.add'));
    await tester.ensureVisible(bgBtn);
    await tester.pumpAndSettle();
    await tester.tap(bgBtn);
    await tester.pumpAndSettle();

    // The add cell opens the native picker (no visibility form) and auto-selects
    // the new image; the picker pops back to the form.
    expect(find.byKey(const ValueKey('scene.bgimage.select.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('scene.bgimage.select.add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsOne);

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    // A new PNG was written to images/bg_images/, and the scene's bg_image names it.
    final files = bgImagesDir(harness)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    expect(files.length, 1);
    final uuid = files.single.uri.pathSegments.last.replaceFirst('.png', '');
    expect(readScenes(harness).single['bg_image'], uuid);
  });

  testWidgets('BRANCH keyevents_multi: selecting events writes key_events[]', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      keyEvents: const [
        {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        {'key_event_uuid': 'k2', 'name': 'Found map', 'state': 'unchecked'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    final btn = find.byKey(const ValueKey('game.scenes.edit.keyevents.add'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Toggle one event, then Save the picker.
    await tester.tap(
      find.byKey(const ValueKey('scene.keyevents.select.tile.Met duke.toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene.keyevents.select.save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    expect((readScenes(harness).single['key_events'] as List).cast<String>(), [
      'Met duke',
    ]);
  });

  testWidgets('BRANCH notes_multi: selecting notes writes notes[] by uuid', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      notes: const [
        {'note_uuid': 'n1', 'note_name': 'Lore', 'note_content': 'x'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    final btn = find.byKey(const ValueKey('game.scenes.edit.notes.add'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('scene.notes.select.tile.n1.toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene.notes.select.save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    expect((readScenes(harness).single['notes'] as List).cast<String>(), [
      'n1',
    ]);
  });

  testWidgets(
    'BRANCH create_and_select_keyevent: add from picker auto-selects it',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);

      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const ValueKey('game.scenes.edit.keyevents.add'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Add a brand-new key event from inside the picker.
      await tester.tap(
        find.byKey(const ValueKey('scene.keyevents.select.new')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        'New ev',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
      await tester.pumpAndSettle();

      // Back in the picker, the new event is selected; Save it.
      await tester.tap(
        find.byKey(const ValueKey('scene.keyevents.select.save')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();

      expect(
        (readScenes(harness).single['key_events'] as List).cast<String>(),
        ['New ev'],
      );
      // The key event was also persisted to key_events[].
      final doc = jsonDecode(
        File('${demoDir(harness).path}/LivingScroll.json').readAsStringSync(),
      );
      expect((doc['key_events'] as List).length, 1);
    },
  );

  testWidgets('BRANCH unsaved_abandon: leaving mid-edit -> Discard drops it', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    // Navigate away to NPC -> unsaved prompt -> Discard.
    await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
    await tester.pumpAndSettle();

    expect(readScenes(harness), isEmpty);
  });

  testWidgets('BRANCH scene_type_select: selecting a type writes scene_type', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    // Default: Standard is the filled (selected) button.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FilledButton &&
            w.key == const ValueKey('game.scenes.edit.scenetype.standard'),
      ),
      findsOne,
    );

    // The button icon is enlarged 70% over the 24px default.
    final typeBtn = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('game.scenes.edit.scenetype.standard')),
    );
    final typeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('game.scenes.edit.scenetype.standard')),
        matching: find.byType(Icon),
      ),
    );
    expect(typeIcon.size, moreOrLessEquals(24 * 1.7, epsilon: 0.01));

    // The icon's left margin is half its top/bottom margin (5 vs 10).
    final typePad = typeBtn.style?.padding
        ?.resolve(<WidgetState>{})
        ?.resolve(TextDirection.ltr);
    expect(typePad, isNotNull);
    expect(typePad!.left, typePad.top / 2);
    expect(typePad.left, typePad.bottom / 2);
    expect(typePad.left, 5);

    // Select "Starting scene".
    final startBtn = find.byKey(
      const ValueKey('game.scenes.edit.scenetype.start'),
    );
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    // It is now the filled (selected) button; Standard fell back to outlined.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FilledButton &&
            w.key == const ValueKey('game.scenes.edit.scenetype.start'),
      ),
      findsOne,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is OutlinedButton &&
            w.key == const ValueKey('game.scenes.edit.scenetype.standard'),
      ),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();

    expect(readScenes(harness).single['scene_type'], 'start');
  });

  testWidgets(
    'BRANCH scene_type_wrap: a narrow screen wraps the type buttons to >1 row',
    (tester) async {
      // At the supported portrait-minimum width (480 dp, the app's minimum window) the
      // four scene-type buttons do not fit on one line, so the Wrap reflows them —
      // WITHOUT going below the minimum (a narrower width overflows an unrelated Row).
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);

      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();

      // The four scene-type buttons do not all share one row top -> they wrapped.
      final tops = <double>{};
      for (final id in const ['start', 'standard', 'recurring', 'end']) {
        tops.add(
          tester
              .getTopLeft(
                find.byKey(ValueKey('game.scenes.edit.scenetype.$id')),
              )
              .dy,
        );
      }
      expect(tops.length, greaterThan(1));
    },
  );

  testWidgets('BRANCH npc_carousel_delete: the carousel tile delete drops the NPC', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      npcs: const [
        {'npc_uuid': 'p1', 'name': 'Guard'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);

    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    // Open the NPC picker, select Guard, Save -> it lands in the carousel.
    final addBtn = find.byKey(const ValueKey('game.scenes.edit.npc.add'));
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // The picker tile is the SAME tile as the new_scene carousel: portrait 1:1.43.
    final pickerTile = find.byKey(const ValueKey('scene.npc.select.tile.p1'));
    expect(pickerTile, findsOne);
    final pSize = tester.getSize(pickerTile);
    expect(pSize.height / pSize.width, moreOrLessEquals(1.43, epsilon: 0.02));

    // The toggle sits on a round secondaryContainer backdrop (adventure-tile
    // treatment), cutting it off from the image underneath.
    final toggle = find.byKey(
      const ValueKey('scene.npc.select.tile.p1.toggle'),
    );
    final scheme = Theme.of(tester.element(toggle)).colorScheme;
    final backdrop = tester.widget<Container>(
      find.ancestor(
        of: toggle,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect(
      (backdrop.decoration as BoxDecoration).color,
      scheme.secondaryContainer,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene.npc.select.save')));
    await tester.pumpAndSettle();

    // The carousel shows the NPC tile with its delete button.
    final tile = find.byKey(
      const ValueKey('game.scenes.edit.npc.carousel.tile.p1'),
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile, findsOne);

    // The add button AND the carousel tile are the same size as a game.npc grid
    // tile: NpcTile.maxExtent (220) wide, portrait NpcTile.aspectRatio (1:1.43).
    const expectedWidth = 220.0;
    const expectedHeight = 220.0 / (1 / 1.43);
    final addSize = tester.getSize(
      find.byKey(const ValueKey('game.scenes.edit.npc.add')),
    );
    expect(addSize.width, moreOrLessEquals(expectedWidth, epsilon: 0.5));
    expect(addSize.height, moreOrLessEquals(expectedHeight, epsilon: 0.5));
    final tileSize = tester.getSize(tile);
    expect(tileSize.width, moreOrLessEquals(expectedWidth, epsilon: 0.5));
    expect(tileSize.height, moreOrLessEquals(expectedHeight, epsilon: 0.5));

    // Delete it from the carousel.
    await tester.tap(
      find.byKey(
        const ValueKey('game.scenes.edit.npc.carousel.tile.p1.delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tile, findsNothing);

    // Save the scene -> no NPC persisted.
    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();
    expect((readScenes(harness).single['npcs'] as List), isEmpty);
  });

  testWidgets(
    'BRANCH scene_create_npc: the picker "create new NPC" cell opens the NPC '
    'form and auto-selects the created NPC',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
      ); // no NPCs yet — we create one from the scene picker
      // The NPC editor's image picker returns this fixture (an NPC needs a full +
      // icon image to be saveable).
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openScenes(tester);

      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      // Open the NPC picker, then tap the "create new NPC" cell.
      final addBtn = find.byKey(const ValueKey('game.scenes.edit.npc.add'));
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('scene.npc.select.add')));
      await tester.pumpAndSettle();

      // REGRESSION: tapping the cell must open the (Basic RPG) NPC create form.
      final nameField = find.byKey(const ValueKey('npc_basicrpg.field.name'));
      expect(
        nameField,
        findsOne,
        reason: 'the create-new-NPC cell did not open the NPC form',
      );

      await tester.enterText(nameField, 'Goblin');
      await tester.pumpAndSettle();
      // Stage the full image + its icon crop (Save is disabled until both exist).
      await tester.tap(find.byKey(const ValueKey('npc_basicrpg.full_image')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('npc_basicrpg.full_image.crop.confirm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('npc_basicrpg.icon_image.crop.confirm')),
      );
      await tester.pumpAndSettle();

      final saveNpc = find.byKey(const ValueKey('npc_basicrpg.save'));
      await tester.ensureVisible(saveNpc);
      await tester.pumpAndSettle();
      await tester.tap(saveNpc);
      await tester.pumpAndSettle();

      // Back in the picker: the new NPC is created and auto-selected. Save the
      // picker, then the scene.
      await tester.tap(find.byKey(const ValueKey('scene.npc.select.save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();

      // The NPC exists in npcs[] and the scene references it (by name).
      final doc = jsonDecode(
        File('${demoDir(harness).path}/LivingScroll.json').readAsStringSync(),
      );
      final npcNames = (doc['npcs'] as List)
          .map((n) => (n as Map)['name'])
          .toList();
      expect(npcNames, contains('Goblin'));
      final sceneNpcs = (readScenes(harness).single['npcs'] as List);
      expect(sceneNpcs, contains('Goblin'));
    },
  );

  testWidgets('BRANCH notes_tile_delete: the note tile delete drops the note', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      notes: const [
        {'note_uuid': 'n1', 'note_name': 'Lore', 'note_content': 'x'},
      ],
    );

    await harness.pumpApp(tester);
    await openScenes(tester);
    await tester.tap(find.byKey(const ValueKey('scene.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.scenes.edit.field.name')),
      'Cave',
    );
    await tester.pumpAndSettle();

    // Select note n1.
    final btn = find.byKey(const ValueKey('game.scenes.edit.notes.add'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('scene.notes.select.tile.n1.toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene.notes.select.save')));
    await tester.pumpAndSettle();

    // The note tile shows with its delete button; tapping delete drops it.
    final tile = find.byKey(const ValueKey('game.scenes.edit.notes.tile.n1'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile, findsOne);
    await tester.tap(
      find.byKey(const ValueKey('game.scenes.edit.notes.tile.n1.delete')),
    );
    await tester.pumpAndSettle();
    expect(tile, findsNothing);

    await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
    await tester.pumpAndSettle();
    expect((readScenes(harness).single['notes'] as List), isEmpty);
  });

  testWidgets(
    'BRANCH keyevents_tile_delete: the event tile delete drops the event',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: const [
          {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const ValueKey('game.scenes.edit.keyevents.add'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('scene.keyevents.select.tile.Met duke.toggle'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.keyevents.select.save')),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(
        const ValueKey('game.scenes.edit.keyevents.tile.Met duke'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOne);
      await tester.tap(
        find.byKey(
          const ValueKey('game.scenes.edit.keyevents.tile.Met duke.delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tile, findsNothing);

      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();
      expect((readScenes(harness).single['key_events'] as List), isEmpty);
    },
  );

  testWidgets(
    'BRANCH soundtrack_tile_delete: the soundtrack tile delete clears it',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        audio: const [
          {'audio_uuid': 'a1', 'name': 'Theme'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      // Select track a1 (single-select picker: tap returns).
      final btn = find.byKey(const ValueKey('game.scenes.edit.audio.button'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.soundtracks.select.tile.a1')),
      );
      await tester.pumpAndSettle();

      // The soundtrack tile shows with its delete button; deleting clears it.
      final tile = find.byKey(const ValueKey('game.scenes.edit.audio.tile.a1'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOne);
      await tester.tap(
        find.byKey(const ValueKey('game.scenes.edit.audio.tile.a1.delete')),
      );
      await tester.pumpAndSettle();
      expect(tile, findsNothing);

      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();
      expect((readScenes(harness).single['audio'] as List), isEmpty);
    },
  );

  testWidgets(
    'BRANCH images_tile: square 144px preview tile with top-right delete',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        images: const [
          {'image_uuid': 'i1', 'name': 'Map'},
        ],
      );
      // A real PNG so the tile (and picker) preview an actual image.
      final imagesDir = Directory('${demoDir(harness).path}/images/other');
      await imagesDir.create(recursive: true);
      await File(
        '${imagesDir.path}/i1.png',
      ).writeAsBytes(img.encodePng(img.Image(width: 8, height: 8)));

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      // Select image i1 via the images picker.
      final addBtn = find.byKey(const ValueKey('game.scenes.edit.images.add'));
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.images.select.tile.i1.toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scene.images.select.save')));
      await tester.pumpAndSettle();

      // The carousel tile is square, 144px, and previews the image.
      final tile = find.byKey(
        const ValueKey('game.scenes.edit.images.carousel.tile.i1'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOne);
      final size = tester.getSize(tile);
      expect(size.width, size.height); // square
      expect(size.width, moreOrLessEquals(144, epsilon: 0.5));
      expect(
        find.descendant(of: tile, matching: find.byType(Image)),
        findsOneWidget,
      );

      // Top-right delete drops the image.
      await tester.tap(
        find.byKey(
          const ValueKey('game.scenes.edit.images.carousel.tile.i1.delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tile, findsNothing);

      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();
      expect((readScenes(harness).single['images'] as List), isEmpty);
    },
  );

  testWidgets(
    'BRANCH create_and_select_image: Add inside the images picker creates + auto-selects',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // No images yet: the picker starts with only the add cell.
      await seedDemo(harness);
      // The new-image form's file picker returns this fixture.
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      // Open the images picker.
      final addBtn = find.byKey(const ValueKey('game.scenes.edit.images.add'));
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scene.images.select.root')), findsOne);

      // Add a brand-new image: the picker's add cell -> the new-image form.
      await tester.tap(find.byKey(const ValueKey('scene.images.select.add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.images.edit.image')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.images.edit.add')));
      await tester.pumpAndSettle();

      // Back on the picker; the image was persisted to images[].
      expect(find.byKey(const ValueKey('scene.images.select.root')), findsOne);
      final images = readImages(harness);
      expect(images.length, 1);
      final uuid = images.single['image_uuid'] as String;

      // The new tile is present AND auto-selected (check_circle).
      expect(find.byKey(ValueKey('scene.images.select.tile.$uuid')), findsOne);
      final toggle = tester.widget<IconButton>(
        find.byKey(ValueKey('scene.images.select.tile.$uuid.toggle')),
      );
      expect((toggle.icon as Icon).icon, Icons.check_circle);

      // Save the selection, then the scene; scenes.images[] carries the uuid.
      await tester.tap(find.byKey(const ValueKey('scene.images.select.save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();
      expect(readScenes(harness).single['images'], [uuid]);
    },
  );

  testWidgets(
    'BRANCH next_scenes_select: pick next scenes (start hidden) -> next_scenes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        scenes: const [
          {'scene_uuid': 's1', 'name': 'Intro', 'scene_type': 'start'},
          {'scene_uuid': 's2', 'name': 'Cave', 'scene_type': 'standard'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Forest',
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const ValueKey('game.scenes.edit.nextscenes.add'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Embedded logic: the starting scene is hidden; the standard scene shows.
      expect(
        find.byKey(const ValueKey('scene.nextscenes.select.tile.s1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('scene.nextscenes.select.tile.s2')),
        findsOne,
      );

      await tester.tap(
        find.byKey(const ValueKey('scene.nextscenes.select.tile.s2.toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.nextscenes.select.save')),
      );
      await tester.pumpAndSettle();

      // A next-scene tile appears (like a note tile): keyed by the TARGET'S
      // scene_uuid (s2), label resolved to the target's name, plus delete.
      final tile = find.byKey(
        const ValueKey('game.scenes.edit.nextscenes.tile.s2'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOne);
      expect(
        find.descendant(of: tile, matching: find.text('Cave')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('game.scenes.edit.nextscenes.tile.s2.delete'),
        ),
        findsOne,
      );

      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();

      // Stored BY scene_uuid (NOT the name "Cave") — the link survives a rename.
      final forest = readScenes(
        harness,
      ).firstWhere((s) => s['name'] == 'Forest');
      expect((forest['next_scenes'] as List).cast<String>(), ['s2']);
    },
  );

  testWidgets(
    'BRANCH next_scenes_survive_rename: renaming a target keeps the next-scene link',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      // s1 "Intro" (start) -> s2 "Cave" by uuid; we rename Cave and confirm the
      // link (and its resolved label) still points at it.
      await seedDemo(
        harness,
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Intro',
            'scene_type': 'start',
            'next_scenes': ['s2'],
          },
          {'scene_uuid': 's2', 'name': 'Cave', 'scene_type': 'standard'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);

      // Open the TARGET scene s2 and rename it.
      await tester.tap(find.byKey(const ValueKey('scene.tile.s2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cavern',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.scenes.edit.save')));
      await tester.pumpAndSettle();

      // The source scene's link is UNCHANGED (still the uuid, no cascade rename).
      final intro = readScenes(harness).firstWhere((s) => s['name'] == 'Intro');
      expect((intro['next_scenes'] as List).cast<String>(), ['s2']);
      final cave = readScenes(
        harness,
      ).firstWhere((s) => s['scene_uuid'] == 's2');
      expect(cave['name'], 'Cavern');

      // Reopen the SOURCE scene s1: the link resolves through the uuid to the
      // renamed target, so its tile now shows the NEW label.
      await tester.tap(find.byKey(const ValueKey('scene.tile.s1')));
      await tester.pumpAndSettle();
      final tile = find.byKey(
        const ValueKey('game.scenes.edit.nextscenes.tile.s2'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOne);
      expect(
        find.descendant(of: tile, matching: find.text('Cavern')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'BRANCH next_scenes_disabled_when_end: ending scene disables the button',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      ButtonStyleButton nextBtn() => tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('game.scenes.edit.nextscenes.add')),
      );

      // Enabled for the default (standard) scene.
      expect(nextBtn().enabled, isTrue);

      // Select "Ending scene" -> the Next scenes button becomes disabled.
      final endBtn = find.byKey(
        const ValueKey('game.scenes.edit.scenetype.end'),
      );
      await tester.ensureVisible(endBtn);
      await tester.pumpAndSettle();
      await tester.tap(endBtn);
      await tester.pumpAndSettle();

      expect(nextBtn().enabled, isFalse);
    },
  );

  // ---- isDirty / unsaved-changes guard (scene form + subforms) ------------

  testWidgets(
    'BRANCH dirty_pristine_no_prompt: a pristine new scene never warns',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);

      // Open a brand-new scene, change NOTHING, then navigate away.
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();

      // Not dirty -> no prompt, navigation proceeds, nothing written.
      expect(unsavedDialog, findsNothing);
      expect(selectedIndex(tester), npcsIndex);
      expect(readScenes(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH dirty_save: leaving mid-edit -> Save persists the scene',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      expect(readScenes(harness).single['name'], 'Cave');
      expect(selectedIndex(tester), npcsIndex);
    },
  );

  testWidgets(
    'BRANCH dirty_cancel: leaving mid-edit -> Cancel stays on the form',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
      await tester.pumpAndSettle();

      // Still editing the scene; nothing written.
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsOne);
      expect(selectedIndex(tester), scenesIndex);
      expect(readScenes(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH dirty_via_bgimage_subform: a background-image pick marks the scene dirty',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      await seedBgImage(harness, 'im1');

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();

      // Change ONLY through the Background image subform — no name typed.
      final bgBtn = find.byKey(const ValueKey('game.scenes.edit.bgimage.add'));
      await tester.ensureVisible(bgBtn);
      await tester.pumpAndSettle();
      await tester.tap(bgBtn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.bgimage.select.tile.im1')),
      );
      await tester.pumpAndSettle();

      // Navigating away now warns -> the subform change made the scene dirty.
      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
      await tester.pumpAndSettle();
      expect(selectedIndex(tester), scenesIndex);
    },
  );

  testWidgets(
    'BRANCH dirty_via_notes_subform: a notes pick marks the scene dirty',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        notes: const [
          {'note_uuid': 'n1', 'note_name': 'Lore', 'note_content': 'x'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();

      // Change ONLY through the (multi-select) notes subform — no name typed.
      final addBtn = find.byKey(const ValueKey('game.scenes.edit.notes.add'));
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('scene.notes.select.tile.n1.toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scene.notes.select.save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
      await tester.pumpAndSettle();
      expect(selectedIndex(tester), npcsIndex);
      expect(readScenes(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH dirty_existing_pristine: opening a scene unchanged never warns',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        scenes: const [
          {'scene_uuid': 's1', 'name': 'Cave'},
        ],
      );

      await harness.pumpApp(tester);
      await openScenes(tester);

      // Open the existing scene, change nothing, navigate away.
      await tester.tap(find.byKey(const ValueKey('scene.tile.s1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsOne);
      await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
      await tester.pumpAndSettle();

      expect(unsavedDialog, findsNothing);
      expect(selectedIndex(tester), npcsIndex);
      expect(readScenes(harness).single['name'], 'Cave');
    },
  );

  // --- Re-tapping the CURRENT rail destination returns the nested form to the
  // section's base (list) view, through the same isDirty guard. -------------

  testWidgets(
    'BRANCH retap_pristine_returns_to_list: re-tapping Scenes on a pristine form returns to the list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);

      // Open a brand-new scene (pristine), then re-tap the CURRENT destination.
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsOne);
      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();

      // Not dirty -> no prompt; the form closes back to the list; still on Scenes.
      expect(unsavedDialog, findsNothing);
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsNothing);
      expect(find.byKey(const ValueKey('scene.list')), findsOne);
      expect(selectedIndex(tester), scenesIndex);
      expect(readScenes(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH retap_dirty_save: re-tapping Scenes mid-edit -> Save persists, returns to the list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      expect(readScenes(harness).single['name'], 'Cave');
      expect(find.byKey(const ValueKey('scene.list')), findsOne);
      expect(selectedIndex(tester), scenesIndex);
    },
  );

  testWidgets(
    'BRANCH retap_dirty_abandon: re-tapping Scenes mid-edit -> Abandon drops edits, returns to the list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
      await tester.pumpAndSettle();

      // Edits dropped; the form closed back to the list; still on Scenes.
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsNothing);
      expect(find.byKey(const ValueKey('scene.list')), findsOne);
      expect(selectedIndex(tester), scenesIndex);
      expect(readScenes(harness), isEmpty);
    },
  );

  testWidgets(
    'BRANCH retap_dirty_cancel: re-tapping Scenes mid-edit -> Cancel stays on the form',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openScenes(tester);
      await tester.tap(find.byKey(const ValueKey('scene.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('game.scenes.edit.field.name')),
        'Cave',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(unsavedDialog, findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
      await tester.pumpAndSettle();

      // Stayed in the form; nothing written; still on Scenes.
      expect(find.byKey(const ValueKey('game.scenes.edit.root')), findsOne);
      expect(selectedIndex(tester), scenesIndex);
      expect(readScenes(harness), isEmpty);
    },
  );
}
