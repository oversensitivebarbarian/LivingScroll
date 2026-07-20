// Integration test for the Home view's three sections
// (Active sessions / Adventures / Projects): shown only when non-empty, each a
// row of tiles + a More link to the matching Library tab, with the same tile-tap
// behaviour as the corresponding Library tab.

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
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> writeAdventure(
    Directory dir,
    String slug,
    String name, {
    Map<String, dynamic>? metaExtra,
    List<Object> scenes = const [],
  }) async {
    final adv = Directory('${dir.path}/$slug');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {'name': name, 'system': 'basic', ...?metaExtra},
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': scenes,
      }),
    );
  }

  // Packs a full-metadata adventure into a `.ls` under [root] (so it passes
  // PUBLISHED validation when imported), returning its path. Mirrors the Library
  // import test's helper.
  Future<String> writeLs(Directory root) async {
    final adv = Directory('${root.path}/adv');
    await adv.create(recursive: true);
    final body = {
      'metadata': {
        'name': 'Pack',
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
      'notes': [],
      'gm_notes': [],
      'npcs': [],
      'scenes': [],
    };
    await File('${adv.path}/LivingScroll.json').writeAsString(jsonEncode(body));
    final bytes = const AdventurePackager().pack(
      sourceDir: adv,
      header: AdventurePackager.headerFromMetadata(body['metadata']),
    );
    final file = File('${root.path}/Pack.ls');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // Seeds a save and an adventure (each in its own root).
  Future<void> seedAll(CreateHarness harness) async {
    await writeAdventure(
      harness.savesDir,
      'SaveOne',
      'Save',
      scenes: const [
        {'scene_uuid': 's1', 'name': 'Opening', 'scene_type': 'start'},
      ],
    );
    // history.json holds scene UUIDs: Opening is s1.
    await File(
      '${harness.savesDir.path}/SaveOne/history.json',
    ).writeAsString(jsonEncode(['s1']));
    await File(
      '${harness.savesDir.path}/SaveOne/group.json',
    ).writeAsString(jsonEncode({'group': 'G'}));
    await writeAdventure(
      harness.adventuresDir,
      'AdvOne',
      'Adv',
      metaExtra: {'version': '2.0.0', 'author': 'A', 'description': 'd'},
    );
  }

  testWidgets('home: sections list their tiles and a More link each', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAll(harness);

    await harness.pumpApp(tester); // lands on Home
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home.root')), findsOne);
    // Both sections present (each has content); there is NO Projects section.
    expect(find.byKey(const ValueKey('home.section.saves')), findsOne);
    expect(find.byKey(const ValueKey('home.section.adventures')), findsOne);
    expect(find.byKey(const ValueKey('home.section.projects')), findsNothing);
    // Each has a More link.
    expect(find.byKey(const ValueKey('home.more.saves')), findsOne);
    expect(find.byKey(const ValueKey('home.more.adventures')), findsOne);
    expect(find.byKey(const ValueKey('home.more.projects')), findsNothing);
    // Each section shows its tile.
    expect(find.byKey(const ValueKey('adventure.tile.SaveOne')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.AdvOne')), findsOne);
    // The Active sessions tile shows the playthrough group as a bottom overlay;
    // the (non-save) Adventures tile has none.
    final groupText = tester.widget<Text>(
      find.byKey(const ValueKey('adventure.tile.SaveOne.group')),
    );
    expect(groupText.data, 'G');
    expect(
      find.byKey(const ValueKey('adventure.tile.AdvOne.group')),
      findsNothing,
    );
  });

  testWidgets('home: an empty section is hidden', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    // Only an adventure — no saves, no projects.
    await writeAdventure(harness.adventuresDir, 'AdvOne', 'Adv');

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home.section.adventures')), findsOne);
    expect(find.byKey(const ValueKey('home.section.saves')), findsNothing);
    expect(find.byKey(const ValueKey('home.section.projects')), findsNothing);
  });

  testWidgets('home: tapping a Saves tile resumes it (launch screen)', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAll(harness);

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.SaveOne')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('launch.root')), findsOne);
  });

  testWidgets('home: tapping an Adventures tile opens the info window', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAll(harness);

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.AdvOne')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.adventure.info')), findsOne);
  });

  testWidgets('home: More links open the matching Library tab', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAll(harness);

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();

    int libTab() => DefaultTabController.of(
      tester.element(find.byKey(const ValueKey('library.tabs'))),
    ).index;

    Future<void> backHome() async {
      await tester.tap(find.byKey(const ValueKey('nav.home')));
      await tester.pumpAndSettle();
    }

    // More (Active sessions) -> Library, Saves tab (index 1).
    await tester.tap(find.byKey(const ValueKey('home.more.saves')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.tabs')), findsOne);
    expect(libTab(), 1);

    // More (Adventures) -> Adventures tab (index 0).
    await backHome();
    await tester.tap(find.byKey(const ValueKey('home.more.adventures')));
    await tester.pumpAndSettle();
    expect(libTab(), 0);
  });

  testWidgets('home empty: no saves and no adventures shows two entry tiles', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    // No seed: {Saves} and {Adventures} are empty.

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();

    // The empty state replaces the sections.
    expect(find.byKey(const ValueKey('home.empty')), findsOne);
    expect(find.byKey(const ValueKey('home.empty.create')), findsOne);
    expect(find.byKey(const ValueKey('home.empty.import')), findsOne);
    expect(find.byKey(const ValueKey('home.section.saves')), findsNothing);
    expect(find.byKey(const ValueKey('home.section.adventures')), findsNothing);
  });

  testWidgets('home empty: the create tile opens the new-adventure form', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home.empty.create')));
    await tester.pumpAndSettle();

    // The Create destination is now showing the new-adventure form.
    expect(find.byKey(const ValueKey('create_new.create')), findsOne);
  });

  testWidgets('home empty: the add tile imports a .ls (same as Library import)', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    final srcRoot = await Directory.systemTemp.createTemp('ls_home_');
    addTearDown(() => srcRoot.delete(recursive: true));
    harness.lsPath = await writeLs(srcRoot);

    await harness.pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home.empty.import')));
    await tester.pumpAndSettle();

    // Imported, unpacked into {Adventures}, and Home reloaded so the empty state
    // is replaced by the Adventures section.
    expect(find.byKey(const ValueKey('library.import.done')), findsOne);
    expect(
      Directory('${harness.adventuresDir.path}/Pack').existsSync(),
      isTrue,
    );
    expect(find.byKey(const ValueKey('home.section.adventures')), findsOne);
  });
}
