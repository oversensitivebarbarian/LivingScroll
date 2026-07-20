// PATH: Create -> new form -> cover + required metadata -> Create
// EFFECT: a new {Projects}/<slug> with LivingScroll.json + cover.jpg, then game.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // STEP 1: from Home open the Create grid, then the new-adventure form.
  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.new')));
    await tester.pumpAndSettle();
  }

  Future<void> selectSystem(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('create_new.field.system')));
    await tester.pumpAndSettle();
    // The catalogue offers the selectable systems (Basic RPG + 7th Sea 2e).
    expect(
      find.byKey(const ValueKey('create_new.field.system.item.basic')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('create_new.field.system.item.7thsea2e')),
      findsWidgets,
    );
    await tester.tap(
      find.byKey(const ValueKey('create_new.field.system.item.basic')).last,
    );
    await tester.pumpAndSettle();
  }

  bool createEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.byKey(const ValueKey('create_new.create')))
      .enabled;

  testWidgets('create_new_create_adventure: cover + metadata -> project + game', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openForm(tester);

    // STEP 1: Create disabled, nothing on disk.
    expect(createEnabled(tester), isFalse);
    expect(harness.projects(), isEmpty);

    // The Import data button carries the Material upload_file glyph (the
    // import-a-file-from-device convention), not the plain file_upload arrow.
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('create_new.import')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.upload_file_outlined,
    );

    // STEP 2: pick a cover -> the crop dialog (locked to 1:1.43).
    await tester.tap(find.byKey(const ValueKey('create_new.cover')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create_new.cover.crop')), findsOne);
    // A resize handle in every corner.
    for (final corner in ['tl', 'tr', 'bl', 'br']) {
      expect(
        find.byKey(ValueKey('create_new.cover.crop.handle.$corner')),
        findsOne,
      );
    }

    // STEP 3: confirm the (default centered) crop -> staged, still nothing written.
    await tester.tap(
      find.byKey(const ValueKey('create_new.cover.crop.confirm')),
    );
    await tester.pumpAndSettle();
    expect(harness.projects(), isEmpty);

    // STEP 4: fill the required fields -> Create enabled.
    await tester.enterText(
      find.byKey(const ValueKey('create_new.field.title')),
      'TEST',
    );
    await tester.pumpAndSettle();
    await selectSystem(tester);
    expect(createEnabled(tester), isTrue);

    // STEP 4: Create.
    await tester.tap(find.byKey(const ValueKey('create_new.create')));
    await tester.pumpAndSettle();

    // EFFECT: exactly one new project dir with the expected document.
    final project = harness.soleProject();
    final doc = harness.readDocument(project);
    expect(doc['metadata']['name'], 'TEST');
    expect(doc['metadata']['system'], 'basic');

    // EFFECT: cover.jpg saved as JPG at the cover profile size.
    final cover = File('${project.path}/cover.jpg');
    expect(cover.existsSync(), isTrue);
    final bytes = cover.readAsBytesSync();
    expect([bytes[0], bytes[1], bytes[2]], [0xFF, 0xD8, 0xFF]); // JPEG magic
    final decoded = img.decodeImage(bytes)!;
    expect(decoded.width, 1000);
    expect(decoded.height, 1430);

    // NAVIGATE TO LAYOUT: game.
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  });

  testWidgets('BRANCH no_cover: Create without a cover writes no cover.jpg', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await harness.pumpApp(tester);
    await openForm(tester);

    await tester.enterText(
      find.byKey(const ValueKey('create_new.field.title')),
      'TEST',
    );
    await tester.pumpAndSettle();
    await selectSystem(tester);

    await tester.tap(find.byKey(const ValueKey('create_new.create')));
    await tester.pumpAndSettle();

    final project = harness.soleProject();
    expect(harness.readDocument(project)['metadata']['name'], 'TEST');
    expect(File('${project.path}/cover.jpg').existsSync(), isFalse);
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  });

  testWidgets('BRANCH missing_title: Create stays disabled without a Title', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await harness.pumpApp(tester);
    await openForm(tester);

    await selectSystem(tester); // system only
    expect(createEnabled(tester), isFalse);
    expect(harness.projects(), isEmpty);
  });

  testWidgets('BRANCH missing_system: Create stays disabled without a System', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await harness.pumpApp(tester);
    await openForm(tester);

    await tester.enterText(
      find.byKey(const ValueKey('create_new.field.title')),
      'TEST',
    );
    await tester.pumpAndSettle();
    expect(createEnabled(tester), isFalse);
    expect(harness.projects(), isEmpty);
  });

  testWidgets('BRANCH crop_cancel: cancelling the crop stages no cover', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openForm(tester);

    // Open the crop dialog, then Cancel.
    await tester.tap(find.byKey(const ValueKey('create_new.cover')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create_new.cover.crop')), findsOne);
    await tester.tap(
      find.byKey(const ValueKey('create_new.cover.crop.cancel')),
    );
    await tester.pumpAndSettle();

    // Nothing staged: dialog gone, Create still disabled (no other input).
    expect(find.byKey(const ValueKey('create_new.cover.crop')), findsNothing);
    expect(createEnabled(tester), isFalse);
    expect(harness.projects(), isEmpty);
  });
}
