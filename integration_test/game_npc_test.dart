// PATH: open adventure -> NPC grid -> Add NPC (name + description + backstory +
// visibility + the two role images via two locked-1:1.43 crops) -> Save writes
// npcs[] and the role PNGs under images/npcs/ at their profiles (full 1000x1430,
// icon 400x572). Branches: load, clone, cascade delete (+ cancel), duplicate name
// (editor / rail guard), icon-crop cancel, cancel and the unsaved-changes choices.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/widgets/cover_picker.dart';
import 'package:living_scroll/widgets/npc_tile.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenesIndex = 2;
  const npcsIndex = 3;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');
  Directory npcsImagesDir(CreateHarness harness) =>
      Directory('${demoDir(harness).path}/images/npcs');

  void bigWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> npcs = const [],
    List<Object> scenes = const [],
    List<Object> keyEvents = const [],
    List<String> imageFiles = const [],
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
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': keyEvents,
        'notes': [],
        'gm_notes': [],
        'npcs': npcs,
        'scenes': scenes,
      }),
    );
    if (imageFiles.isNotEmpty) {
      await npcsImagesDir(harness).create(recursive: true);
      // A real (tiny) PNG so the NPC tile's Image.file can decode it.
      final png = img.encodePng(img.Image(width: 4, height: 4));
      for (final name in imageFiles) {
        await File('${npcsImagesDir(harness).path}/$name').writeAsBytes(png);
      }
    }
  }

  Future<void> openNpc(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
    await tester.pumpAndSettle();
  }

  // Pick a full image (the mocked cover_sample.jpg), then confirm the full crop
  // and the icon crop.
  Future<void> pickFullThenIcon(WidgetTester tester) async {
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
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  Map<String, dynamic> readDoc(CreateHarness harness) =>
      jsonDecode(
            File(
              '${demoDir(harness).path}/LivingScroll.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> readNpcs(CreateHarness harness) =>
      (readDoc(harness)['npcs'] as List).cast<Map<String, dynamic>>();

  testWidgets(
    'game_npc: add all fields + two crops -> npcs[] written + role PNGs saved',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(
        harness,
        keyEvents: const [
          {'key_event_uuid': 'ke1', 'name': 'Met', 'state': 'unchecked'},
        ],
      );
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openNpc(tester);
      expect(find.byKey(const ValueKey('game.npc.grid')), findsOne);

      // The add cell shows the Person Add glyph.
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('game.npc.add')),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.person_add_outlined,
      );

      // Open the editor: Save disabled until name + both images are present.
      await tester.tap(find.byKey(const ValueKey('game.npc.add')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('npc_basicrpg.save')),
            )
            .enabled,
        isFalse,
      );

      // The icon picker is fixed to the NPC grid tile size (NpcTile.maxExtent,
      // 1:1.43).
      final iconSize = tester.getSize(
        find.byKey(const ValueKey('npc_basicrpg.icon_image')),
      );
      expect(iconSize.width, NpcTile.maxExtent);
      expect(
        iconSize.height,
        closeTo(NpcTile.maxExtent / NpcTile.aspectRatio, 0.5),
      );

      // The icon field is a NON-interactive preview: no tap handler, and (while
      // empty) no add-photo affordance — so it is never mistaken for the full
      // image picker (which does show that affordance).
      expect(
        tester
            .widget<CoverPickerField>(
              find.byKey(const ValueKey('npc_basicrpg.icon_image')),
            )
            .onTap,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('npc_basicrpg.icon_image')),
          matching: find.byIcon(Icons.add_photo_alternate_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('npc_basicrpg.full_image')),
          matching: find.byIcon(Icons.add_photo_alternate_outlined),
        ),
        findsOneWidget,
      );

      await pickFullThenIcon(tester);
      expect(readNpcs(harness), isEmpty); // nothing written until Save

      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.name')),
        'Orc',
      );
      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.description')),
        'A big orc',
      );
      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.backstory')),
        'Born in the wastes',
      );
      await tester.pumpAndSettle();

      // Add the key_event "Met" to the visibility gate.
      await tester.ensureVisible(find.byKey(const ValueKey('vis.event.Met')));
      await tester.tap(find.byKey(const ValueKey('vis.event.Met')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('npc_basicrpg.save')),
      );
      await tester.tap(find.byKey(const ValueKey('npc_basicrpg.save')));
      await tester.pumpAndSettle();

      final npcs = readNpcs(harness);
      expect(npcs.length, 1);
      final npc = npcs.single;
      expect(npc['name'], 'Orc');
      expect(npc['description'], 'A big orc');
      expect(npc['backstory'], 'Born in the wastes');
      expect(npc['state'], 'active');
      expect((npc['npc_uuid'] as String).isNotEmpty, isTrue);
      expect(npc['visibility_rules'], {
        'op': 'and',
        'key_events': ['ke1'],
      });

      final fullUuid = npc['full_image'] as String;
      final iconUuid = npc['icon_image'] as String;
      expect(fullUuid.isNotEmpty, isTrue);
      expect(iconUuid.isNotEmpty, isTrue);
      expect(fullUuid == iconUuid, isFalse);

      final full = File('${npcsImagesDir(harness).path}/$fullUuid.png');
      final icon = File('${npcsImagesDir(harness).path}/$iconUuid.png');
      expect(full.existsSync(), isTrue);
      expect(icon.existsSync(), isTrue);
      final fullImg = img.decodeImage(full.readAsBytesSync())!;
      final iconImg = img.decodeImage(icon.readAsBytesSync())!;
      expect([fullImg.width, fullImg.height], [1000, 1430]); // full PROFILE
      expect([iconImg.width, iconImg.height], [400, 572]); // icon PROFILE

      // The grid tile uses the ICON image as its background (not the full image).
      final tileKey = ValueKey('game.npc.tile.${npc['npc_uuid']}');
      expect(find.byKey(tileKey), findsOne);
      final tileImage = tester.widget<Image>(
        find.descendant(of: find.byKey(tileKey), matching: find.byType(Image)),
      );
      expect(
        (tileImage.image as FileImage).file.path.endsWith('$iconUuid.png'),
        isTrue,
      );
    },
  );

  testWidgets('BRANCH existing_loaded: a seeded NPC shows on its tile', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(
      harness,
      npcs: const [
        {
          'npc_uuid': 'n1',
          'name': 'Goblin',
          'full_image': 'f1',
          'icon_image': 'i1',
          'description': '',
          'backstory': '',
          'state': 'active',
        },
      ],
      imageFiles: const ['f1.png', 'i1.png'],
    );

    await harness.pumpApp(tester);
    await openNpc(tester);

    expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsOne);
    final tileImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('game.npc.tile.n1')),
        matching: find.byType(Image),
      ),
    );
    // The tile background is the ICON image (i1), not the full image (f1).
    expect((tileImage.image as FileImage).file.path.endsWith('i1.png'), isTrue);
  });

  testWidgets(
    'BRANCH search_filter: search filters by name / backstory / description',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(
        harness,
        npcs: const [
          {
            'npc_uuid': 'n1',
            'name': 'Goblin',
            'full_image': 'f1',
            'icon_image': 'i1',
            'backstory': 'lives in a cave',
            'description': '',
            'state': 'active',
          },
          {
            'npc_uuid': 'n2',
            'name': 'Orc',
            'full_image': 'f2',
            'icon_image': 'i2',
            'backstory': '',
            'description': 'from the wastes',
            'state': 'active',
          },
        ],
        imageFiles: const ['f1.png', 'i1.png', 'f2.png', 'i2.png'],
      );

      await harness.pumpApp(tester);
      await openNpc(tester);
      expect(find.byKey(const ValueKey('game.npc.search')), findsOne);

      // Backstory match: "cave" -> only n1.
      await tester.enterText(
        find.byKey(const ValueKey('game.npc.search')),
        'cave',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.tile.n2')), findsNothing);
      expect(find.byKey(const ValueKey('game.npc.add')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.search.clear')), findsOne);

      // Clear -> both shown again.
      await tester.tap(find.byKey(const ValueKey('game.npc.search.clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.tile.n2')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.search.clear')), findsNothing);

      // Description match: "wastes" -> only n2.
      await tester.enterText(
        find.byKey(const ValueKey('game.npc.search')),
        'wastes',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.npc.tile.n2')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsNothing);

      // Name match: "orc" -> only n2.
      await tester.enterText(
        find.byKey(const ValueKey('game.npc.search')),
        'orc',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.npc.tile.n2')), findsOne);
      expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsNothing);
    },
  );

  testWidgets('BRANCH clone: appends a unique-named copy with copied images', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(
      harness,
      npcs: const [
        {
          'npc_uuid': 'n1',
          'name': 'Goblin',
          'full_image': 'f1',
          'icon_image': 'i1',
          'description': 'grumpy',
          'backstory': 'cave',
          'state': 'active',
        },
      ],
      imageFiles: const ['f1.png', 'i1.png'],
    );

    await harness.pumpApp(tester);
    await openNpc(tester);

    await tester.tap(find.byKey(const ValueKey('game.npc.tile.menu.n1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('game.npc.tile.menu.n1.item.clone')),
    );
    await tester.pumpAndSettle();

    final npcs = readNpcs(harness);
    expect(npcs.length, 2);
    final clone = npcs.firstWhere((n) => n['npc_uuid'] != 'n1');
    expect(clone['name'], 'Goblin cloned');
    expect(clone['description'], 'grumpy');
    final cloneFull = clone['full_image'] as String;
    final cloneIcon = clone['icon_image'] as String;
    expect(cloneFull == 'f1', isFalse);
    expect(cloneIcon == 'i1', isFalse);
    expect(
      File('${npcsImagesDir(harness).path}/$cloneFull.png').existsSync(),
      isTrue,
    );
    expect(
      File('${npcsImagesDir(harness).path}/$cloneIcon.png').existsSync(),
      isTrue,
    );
    expect(
      find.byKey(ValueKey('game.npc.tile.${clone['npc_uuid']}')),
      findsOne,
    );
  });

  testWidgets(
    'BRANCH delete: cascades by npc_uuid (entry + scene ref + image files)',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(
        harness,
        npcs: const [
          {
            'npc_uuid': 'n1',
            'name': 'Goblin',
            'full_image': 'f1',
            'icon_image': 'i1',
            'description': '',
            'backstory': '',
            'state': 'active',
          },
        ],
        scenes: const [
          {
            'scene_uuid': 's1',
            'name': 'Cave',
            'npcs': ['Goblin'],
          },
        ],
        imageFiles: const ['f1.png', 'i1.png'],
      );

      await harness.pumpApp(tester);
      await openNpc(tester);

      await tester.tap(find.byKey(const ValueKey('game.npc.tile.menu.n1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('game.npc.tile.menu.n1.item.delete')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game.npc.delete.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('game.npc.delete.confirm')));
      await tester.pumpAndSettle();

      expect(readNpcs(harness), isEmpty);
      expect((readDoc(harness)['scenes'] as List).first['npcs'], isEmpty);
      expect(
        File('${npcsImagesDir(harness).path}/f1.png').existsSync(),
        isFalse,
      );
      expect(
        File('${npcsImagesDir(harness).path}/i1.png').existsSync(),
        isFalse,
      );
      expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsNothing);
    },
  );

  testWidgets('BRANCH delete_cancel: cancelling keeps the NPC', (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(
      harness,
      npcs: const [
        {'npc_uuid': 'n1', 'name': 'Goblin', 'state': 'active'},
      ],
    );

    await harness.pumpApp(tester);
    await openNpc(tester);

    await tester.tap(find.byKey(const ValueKey('game.npc.tile.menu.n1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('game.npc.tile.menu.n1.item.delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.npc.delete.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game.npc.tile.n1')), findsOne);
    expect(readNpcs(harness).length, 1);
  });

  testWidgets(
    'BRANCH duplicate_name_edit_save: editor Save rejects a duplicate',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(
        harness,
        npcs: const [
          {
            'npc_uuid': 'n1',
            'name': 'a',
            'full_image': 'f1',
            'icon_image': 'i1',
            'state': 'active',
          },
        ],
        imageFiles: const ['f1.png', 'i1.png'],
      );
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openNpc(tester);
      await tester.tap(find.byKey(const ValueKey('game.npc.add')));
      await tester.pumpAndSettle();
      await pickFullThenIcon(tester);
      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.name')),
        'a',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('npc_basicrpg.save')),
      );
      await tester.tap(find.byKey(const ValueKey('npc_basicrpg.save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('npc.name.not.unique.dialog')),
        findsOne,
      );
      expect(readNpcs(harness).length, 1);

      await tester.tap(find.byKey(const ValueKey('npc.name.not.unique.ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('npc_basicrpg.field.name')), findsOne);
      expect(readNpcs(harness).length, 1);
    },
  );

  testWidgets(
    'BRANCH duplicate_name_guard_save: rail-guard Save rejects a duplicate',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(
        harness,
        npcs: const [
          {
            'npc_uuid': 'n1',
            'name': 'a',
            'full_image': 'f1',
            'icon_image': 'i1',
            'state': 'active',
          },
        ],
        imageFiles: const ['f1.png', 'i1.png'],
      );
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openNpc(tester);
      await tester.tap(find.byKey(const ValueKey('game.npc.add')));
      await tester.pumpAndSettle();
      await pickFullThenIcon(tester);
      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.name')),
        'a',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('npc.name.not.unique.dialog')),
        findsOne,
      );
      expect(readNpcs(harness).length, 1);

      await tester.tap(find.byKey(const ValueKey('npc.name.not.unique.ok')));
      await tester.pumpAndSettle();
      expect(selectedIndex(tester), npcsIndex); // navigation aborted
    },
  );

  testWidgets(
    'BRANCH icon_crop_cancel: cancelling the icon crop leaves Save disabled',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      bigWindow(tester);
      await seedDemo(harness);
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openNpc(tester);
      await tester.tap(find.byKey(const ValueKey('game.npc.add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('npc_basicrpg.field.name')),
        'Orc',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('npc_basicrpg.full_image')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('npc_basicrpg.full_image.crop.confirm')),
      );
      await tester.pumpAndSettle();
      // Cancel the icon crop -> icon stays unset.
      await tester.tap(
        find.byKey(const ValueKey('npc_basicrpg.icon_image.crop.cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('npc_basicrpg.save')),
            )
            .enabled,
        isFalse,
      );
      expect(readNpcs(harness), isEmpty);
    },
  );

  testWidgets('BRANCH cancel_new: Cancel drops a new NPC', (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNpc(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('npc_basicrpg.field.name')),
      'Temp',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('npc_basicrpg.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game.npc.grid')), findsOne);
    expect(readNpcs(harness), isEmpty);
  });

  testWidgets('BRANCH unsaved_save: leaving mid-edit -> Save persists', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openNpc(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.add')));
    await tester.pumpAndSettle();
    await pickFullThenIcon(tester);
    await tester.enterText(
      find.byKey(const ValueKey('npc_basicrpg.field.name')),
      'Orc',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(readNpcs(harness).single['name'], 'Orc');
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_abandon: leaving mid-edit -> Discard drops it', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNpc(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('npc_basicrpg.field.name')),
      'Orc',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
    await tester.pumpAndSettle();

    expect(readNpcs(harness), isEmpty);
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_cancel: leaving mid-edit -> Cancel stays', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNpc(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('npc_basicrpg.field.name')),
      'Orc',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('npc_basicrpg.field.name')), findsOne);
    expect(selectedIndex(tester), npcsIndex);
    expect(readNpcs(harness), isEmpty);
  });
}
