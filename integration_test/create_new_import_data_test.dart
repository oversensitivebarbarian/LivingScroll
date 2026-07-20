// The new-adventure form's Import button works exactly like the Adventure
// settings Import: pick a `.ls`/`.lse` archive, unpack + validate by extension,
// show the per-element selection dialog, and STAGE the selection — applied to the
// new adventure on Create (same merge + media-copy path as settings).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/services/adventure_packager.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // A full-metadata import document carrying one of several categories.
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
    'paths': [],
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
    'scenes': [],
  };

  // Packs [doc] (+ a real image at images/other/i1.png) into a portable archive
  // and returns its path — exactly what the Import picker returns.
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

  Future<void> openFormWithRequired(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create_new.field.title')),
      'TEST',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create_new.field.system')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('create_new.field.system.item.basic')).last,
    );
    await tester.pumpAndSettle();
  }

  List<Map> coll(Map<String, dynamic> doc, String key) =>
      (doc[key] as List).cast<Map>();

  testWidgets('create_new_import_data: archive import -> dialog -> staged -> '
      'merged on Create with media', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
    addTearDown(() => srcRoot.delete(recursive: true));
    harness.archivePath = await writeImportArchive(srcRoot);

    await harness.pumpApp(tester);
    await openFormWithRequired(tester);

    // Import -> the per-element selection dialog (same as settings).
    await tester.tap(find.byKey(const ValueKey('create_new.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import.dialog')), findsOne);
    expect(find.byKey(const ValueKey('import.dialog.item.notes.N1')), findsOne);

    await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
    await tester.pumpAndSettle();
    // Staged, nothing written yet.
    expect(find.byKey(const ValueKey('create_new.import.staged')), findsOne);
    expect(harness.projects(), isEmpty);

    // Create applies the staged import (merge + media copy) onto the new project.
    await tester.tap(find.byKey(const ValueKey('create_new.create')));
    await tester.pumpAndSettle();

    final project = harness.soleProject();
    final doc = harness.readDocument(project);
    expect(doc['metadata']['name'], 'TEST'); // from the form
    expect(coll(doc, 'notes').single['note_uuid'], 'N1');
    expect(coll(doc, 'npcs').single['npc_uuid'], 'P1');
    expect(coll(doc, 'key_events').single['key_event_uuid'], 'k1');
    // Related media was copied into the new adventure.
    expect(File('${project.path}/images/other/i1.png').existsSync(), isTrue);
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  });

  testWidgets('BRANCH select_one: only the chosen element is staged + merged', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
    addTearDown(() => srcRoot.delete(recursive: true));
    harness.archivePath = await writeImportArchive(srcRoot);

    await harness.pumpApp(tester);
    await openFormWithRequired(tester);

    await tester.tap(find.byKey(const ValueKey('create_new.import')));
    await tester.pumpAndSettle();
    // Deselect everything except notes.N1.
    for (final k in ['npcs.P1', 'key_events.k1', 'images.i1']) {
      final f = find.byKey(ValueKey('import.dialog.item.$k'));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('import.dialog.import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create_new.create')));
    await tester.pumpAndSettle();

    final project = harness.soleProject();
    final doc = harness.readDocument(project);
    expect(coll(doc, 'notes').single['note_uuid'], 'N1');
    expect(coll(doc, 'npcs'), isEmpty);
    expect(coll(doc, 'key_events'), isEmpty);
    expect(coll(doc, 'images'), isEmpty);
    expect(File('${project.path}/images/other/i1.png').existsSync(), isFalse);
  });

  testWidgets(
    'BRANCH invalid_schema: a .ls failing PUBLISHED validation is rejected',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
      // A `.ls` with incomplete metadata (name + system only) -> PUBLISHED fails.
      harness.archivePath = await writeImportArchive(
        srcRoot,
        withImage: false,
        doc: {
          'metadata': {'name': 'Bad', 'system': 'basic'},
          'notes': [
            {'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': 'x'},
          ],
        },
      );

      await harness.pumpApp(tester);
      await openFormWithRequired(tester);

      await tester.tap(find.byKey(const ValueKey('create_new.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import.dialog')), findsNothing);
      expect(find.byKey(const ValueKey('create_new.import.error')), findsOne);
      expect(
        find.byKey(const ValueKey('create_new.import.staged')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('create_new.create')));
      await tester.pumpAndSettle();
      final doc = harness.readDocument(harness.soleProject());
      expect(coll(doc, 'notes'), isEmpty); // nothing imported
    },
  );

  testWidgets(
    'BRANCH lse_project_level: a .lse with only name + system is accepted',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      final srcRoot = await Directory.systemTemp.createTemp('ls_import_src_');
      addTearDown(() => srcRoot.delete(recursive: true));
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
      await openFormWithRequired(tester);

      await tester.tap(find.byKey(const ValueKey('create_new.import')));
      await tester.pumpAndSettle();
      // Accepted at PROJECT level -> the dialog opens, no validation error.
      expect(find.byKey(const ValueKey('import.dialog')), findsOne);
      expect(
        find.byKey(const ValueKey('create_new.import.error')),
        findsNothing,
      );
    },
  );
}
