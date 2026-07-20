// Integration test for the Library Adventures
// tile's "Export to LaTeX" context-menu item: build the document, save the ZIP
// (native save dialog, mocked), and verify main.tex + assets.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Seeds {Adventures}/Pack with a scene (path colour, background, NPC, image,
  // next scene) + an NPC, all real image files, and the library index entry.
  Future<void> seedPack(CreateHarness harness) async {
    final adv = Directory('${harness.adventuresDir.path}/Pack');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Pack',
          'system': 'basic',
          'version': '1.0.0',
          'author': 'A',
          'language': 'en',
        },
        'paths': [
          {'name': 'Red', 'color': 'red'},
        ],
        'key_events': [],
        'images': [
          {'image_uuid': 'im1', 'name': 'Map'},
        ],
        'npcs': [
          {
            'npc_uuid': 'n1',
            'name': 'Guard',
            'icon_image': 'ic1',
            'full_image': 'f1',
            'description': 'A sentry.',
            'backstory': 'Once a soldier.',
          },
        ],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Opening',
            'scene_type': 'start',
            'path_names': ['Red'],
            'bg_image': 'bg1',
            'description': 'It begins.',
            'npcs': ['Guard'],
            'images': ['im1'],
            'next_scenes': ['s2'],
          },
          {'scene_uuid': 's2', 'name': 'Gate', 'scene_type': 'end'},
        ],
      }),
    );
    // The cover is RENDERED by the library tile, so it must be a real image.
    final cover = File('${adv.path}/cover.jpg');
    await cover.parent.create(recursive: true);
    await cover.writeAsBytes(
      await File(CreateHarness.asset('cover_sample.jpg')).readAsBytes(),
    );
    // The other images are only read as bytes for the ZIP (never decoded), so a
    // PNG signature is enough.
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (final rel in const [
      'images/bg_images/bg1.png',
      'images/npcs/ic1.png',
      'images/npcs/f1.png',
      'images/other/im1.png',
    ]) {
      final f = File('${adv.path}/$rel');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(png);
    }
    final idx = File('${harness.settingsDir.path}/adventures.json');
    await idx.parent.create(recursive: true);
    await idx.writeAsString(
      jsonEncode([
        {
          'title': 'Pack',
          'version': '1.0.0',
          'system': 'basic',
          'author': 'A',
          'language': 'en',
          'dir': 'Pack',
        },
      ]),
    );
  }

  Future<void> openExportMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.menu.Pack')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('adventure.tile.menu.Pack.item.latex')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('library_export_latex: exports the adventure as a LaTeX ZIP', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedPack(harness);

    final zipPath = '${harness.adventuresDir.parent.path}/Pack-latex.zip';
    harness.saveFilePath = zipPath;

    await harness.pumpApp(tester);
    await openExportMenu(tester);

    // The ZIP is written and a confirmation SnackBar shows.
    final zip = File(zipPath);
    expect(zip.existsSync(), isTrue);
    expect(
      find.byKey(const ValueKey('library.export.latex.done')),
      findsOneWidget,
    );

    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('main.tex'));
    expect(
      names,
      containsAll(<String>[
        'assets/cover.jpg',
        'assets/bg_bg1.png',
        'assets/npcicon_ic1.png',
        'assets/npcfull_f1.png',
        'assets/img_im1.png',
      ]),
    );

    final tex = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'main.tex').content
          as List<int>,
    );
    expect(tex, contains(r'\chapter{Scenes}'));
    expect(tex, contains(r'\chapter{NPCs}'));
    expect(tex, contains(r'\label{scene:s1}'));
    expect(tex, contains(r'\hyperref[npc:n1]{'));
    expect(tex, contains(r'\label{npc:n1}'));
    expect(tex, contains(r'\hyperref[scene:s2]{Gate}'));
  });

  testWidgets('library_export_latex: cancelling the save writes nothing', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedPack(harness);

    harness.saveFilePath = null; // native dialog cancelled

    await harness.pumpApp(tester);
    await openExportMenu(tester);

    // No confirmation, and no stray file under the support root.
    expect(
      find.byKey(const ValueKey('library.export.latex.done')),
      findsNothing,
    );
    final strayZips = harness.adventuresDir.parent
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'));
    expect(strayZips, isEmpty);
  });
}
