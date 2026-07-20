// PATH: open adventure -> Images "all photos" grid -> "+" opens the add form
// (required image picker + visibility) -> Add writes a PNG under
// images/other/<uuid>.png and appends to images[]. Branches: visibility,
// image-required, cancel, load, delete (confirm / cancel), unsaved-changes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenesIndex = 2;
  const imagesIndex = 6;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');
  Directory imagesOtherDir(CreateHarness harness) =>
      Directory('${demoDir(harness).path}/images/other');

  const dukeEvent = [
    {'name': 'Met the duke', 'key_event_uuid': 'ke-duke', 'state': 'unchecked'},
  ];

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> images = const [],
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
        'images': images,
        'audio': [],
        'paths': [],
        'key_events': keyEvents,
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
    if (imageFiles.isNotEmpty) {
      await imagesOtherDir(harness).create(recursive: true);
      final png = img.encodePng(img.Image(width: 4, height: 4));
      for (final name in imageFiles) {
        await File('${imagesOtherDir(harness).path}/$name').writeAsBytes(png);
      }
    }
  }

  Future<void> openImages(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.images')));
    await tester.pumpAndSettle();
  }

  // Open the add form and pick the (mocked) image.
  Future<void> openFormAndPick(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('image.new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.images.edit.image')));
    await tester.pumpAndSettle();
  }

  bool addEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.byKey(const ValueKey('game.images.edit.add')))
      .enabled;

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  List<Map<String, dynamic>> readImages(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['images']
              as List)
          .cast<Map<String, dynamic>>();

  testWidgets(
    'game_images: "+" -> form -> pick + Add -> PNG + images[] entry',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness, keyEvents: dukeEvent);
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openImages(tester);
      expect(find.byKey(const ValueKey('image.grid')), findsOne);

      // The add tile shows the Add Photo Alternate glyph (not a plain +).
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('image.new')),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.add_photo_alternate_outlined,
      );

      // STEP 2: the form opens; Add disabled (no image yet); visibility editor.
      await tester.tap(find.byKey(const ValueKey('image.new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vis.root')), findsOne);
      expect(find.byKey(const ValueKey('vis.event.Met the duke')), findsOne);
      expect(addEnabled(tester), isFalse);

      // STEP 3: pick an image -> preview shown, Add enabled.
      await tester.tap(find.byKey(const ValueKey('game.images.edit.image')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game.images.edit.image.preview')),
        findsOne,
      );
      expect(addEnabled(tester), isTrue);
      expect(readImages(harness), isEmpty); // not written until Add

      // STEP 4: Add.
      await tester.tap(find.byKey(const ValueKey('game.images.edit.add')));
      await tester.pumpAndSettle();

      final images = readImages(harness);
      expect(images.length, 1);
      expect(images.single['name'], 'cover_sample');
      final uuid = images.single['image_uuid'] as String;

      final saved = File('${imagesOtherDir(harness).path}/$uuid.png');
      expect(saved.existsSync(), isTrue);
      final bytes = saved.readAsBytesSync();
      expect(
        [bytes[0], bytes[1], bytes[2], bytes[3]],
        [0x89, 0x50, 0x4E, 0x47],
      ); // PNG magic
      final source = img.decodeImage(
        File(CreateHarness.asset('cover_sample.jpg')).readAsBytesSync(),
      )!;
      final out = img.decodeImage(bytes)!;
      expect(out.width, source.width);
      expect(out.height, source.height);

      expect(find.byKey(const ValueKey('image.grid')), findsOne);
      expect(find.byKey(ValueKey('image.tile.$uuid')), findsOne);
    },
  );

  testWidgets('BRANCH with_visibility: ticking a key event stores its uuid', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness, keyEvents: dukeEvent);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openImages(tester);
    await openFormAndPick(tester);

    await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.images.edit.add')));
    await tester.pumpAndSettle();

    expect(readImages(harness).single['visibility_rules'], {
      'op': 'and',
      'key_events': ['ke-duke'],
    });
  });

  testWidgets('BRANCH image_required: Add disabled until an image is picked', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness, keyEvents: dukeEvent);

    await harness.pumpApp(tester);
    await openImages(tester);

    await tester.tap(find.byKey(const ValueKey('image.new')));
    await tester.pumpAndSettle();
    // Tick visibility but pick no image -> Add still disabled.
    await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
    await tester.pumpAndSettle();
    expect(addEnabled(tester), isFalse);
    expect(readImages(harness), isEmpty);
  });

  testWidgets('BRANCH cancel: Cancel discards the staged image', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openImages(tester);
    await openFormAndPick(tester);

    await tester.tap(find.byKey(const ValueKey('game.images.edit.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('image.grid')), findsOne);
    expect(readImages(harness), isEmpty);
    expect(imagesOtherDir(harness).existsSync(), isFalse);
  });

  testWidgets('BRANCH existing_loaded: a seeded image shows on its tile', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      images: const [
        {'image_uuid': 'i1', 'name': 'Map'},
      ],
      imageFiles: const ['i1.png'],
    );

    await harness.pumpApp(tester);
    await openImages(tester);

    expect(find.byKey(const ValueKey('image.new')), findsOne);
    expect(find.byKey(const ValueKey('image.tile.i1')), findsOne);
  });

  testWidgets('BRANCH delete: confirming removes the image and its file', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      images: const [
        {'image_uuid': 'i1', 'name': 'Map'},
      ],
      imageFiles: const ['i1.png'],
    );

    await harness.pumpApp(tester);
    await openImages(tester);

    await tester.tap(find.byKey(const ValueKey('image.tile.i1.delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('image.delete.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('image.delete.confirm')));
    await tester.pumpAndSettle();

    expect(readImages(harness), isEmpty);
    expect(
      File('${imagesOtherDir(harness).path}/i1.png').existsSync(),
      isFalse,
    );
    expect(find.byKey(const ValueKey('image.tile.i1')), findsNothing);
  });

  testWidgets('BRANCH delete_cancel: cancelling keeps the image', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      images: const [
        {'image_uuid': 'i1', 'name': 'Map'},
      ],
      imageFiles: const ['i1.png'],
    );

    await harness.pumpApp(tester);
    await openImages(tester);

    await tester.tap(find.byKey(const ValueKey('image.tile.i1.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('image.delete.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('image.tile.i1')), findsOne);
    expect(readImages(harness).length, 1);
    expect(File('${imagesOtherDir(harness).path}/i1.png').existsSync(), isTrue);
  });

  testWidgets(
    'BRANCH unsaved_save: leaving the form mid-add -> Save persists',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openImages(tester);
      await openFormAndPick(tester);

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      expect(readImages(harness).length, 1);
      expect(selectedIndex(tester), scenesIndex);
    },
  );

  testWidgets('BRANCH unsaved_abandon: leaving the form mid-add -> Discard', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openImages(tester);
    await openFormAndPick(tester);

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
    await tester.pumpAndSettle();

    expect(readImages(harness), isEmpty);
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets(
    'BRANCH unsaved_cancel: leaving the form mid-add -> Cancel stays',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      harness.coverPath = CreateHarness.asset('cover_sample.jpg');

      await harness.pumpApp(tester);
      await openImages(tester);
      await openFormAndPick(tester);

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('game.images.edit.image.preview')),
        findsOne,
      );
      expect(selectedIndex(tester), imagesIndex);
      expect(readImages(harness), isEmpty);
    },
  );

  // --- EDIT mode (tap a tile) ------------------------------------------------

  testWidgets(
    'BRANCH edit_visibility: tap a tile -> edit form (picker disabled) -> Save',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: dukeEvent,
        images: const [
          {'image_uuid': 'i1', 'name': 'Map'},
        ],
        imageFiles: const ['i1.png'],
      );

      await harness.pumpApp(tester);
      await openImages(tester);

      await tester.tap(find.byKey(const ValueKey('image.tile.i1')));
      await tester.pumpAndSettle();

      // EDIT mode: the picker is absent; the current image + visibility editor show.
      expect(
        find.byKey(const ValueKey('game.images.edit.image')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('game.images.edit.image.preview')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('vis.event.Met the duke')), findsOne);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('game.images.edit.save')),
            )
            .enabled,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game.images.edit.save')));
      await tester.pumpAndSettle();

      final images = readImages(harness);
      expect(images.length, 1);
      expect(images.single['image_uuid'], 'i1');
      expect(images.single['visibility_rules'], {
        'op': 'and',
        'key_events': ['ke-duke'],
      });
      // The image file is unchanged.
      expect(
        File('${imagesOtherDir(harness).path}/i1.png').existsSync(),
        isTrue,
      );
      expect(find.byKey(const ValueKey('image.grid')), findsOne);
    },
  );

  testWidgets(
    'BRANCH edit_reopen_shows_rule: a saved rule is reflected ticked',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: dukeEvent,
        images: const [
          {
            'image_uuid': 'i1',
            'name': 'Map',
            'visibility_rules': {
              'op': 'and',
              'key_events': ['ke-duke'],
            },
          },
        ],
        imageFiles: const ['i1.png'],
      );

      await harness.pumpApp(tester);
      await openImages(tester);

      await tester.tap(find.byKey(const ValueKey('image.tile.i1')));
      await tester.pumpAndSettle();

      final cb = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('vis.event.Met the duke')),
      );
      expect(cb.value, isTrue);
    },
  );

  testWidgets(
    'BRANCH edit_unsaved_cancel: leaving an edit mid-change -> Cancel',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: dukeEvent,
        images: const [
          {'image_uuid': 'i1', 'name': 'Map'},
        ],
        imageFiles: const ['i1.png'],
      );

      await harness.pumpApp(tester);
      await openImages(tester);

      await tester.tap(find.byKey(const ValueKey('image.tile.i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
      await tester.pumpAndSettle();

      expect(selectedIndex(tester), imagesIndex);
      expect(find.byKey(const ValueKey('vis.root')), findsOne);
      expect(
        readImages(harness).single.containsKey('visibility_rules'),
        isFalse,
      );
    },
  );
}
