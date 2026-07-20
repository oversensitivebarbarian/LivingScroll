// A started game opened in the editor freezes its immutable base content (no
// delete, no edit) — with the next_scenes exception on a frozen scene — while new
// content stays editable. Runs under a real binding:
// `flutter test -d linux integration_test/game_save_frozen_test.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/game_screen.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const saveName = 'Frozen-1.0-Wed';

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder byId(String k) => find.byKey(ValueKey(k));

  Future<void> seedSave(CreateHarness harness) async {
    final dir = Directory('${harness.savesDir.path}/$saveName');
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Frozen',
          'system': 'basic',
          'version': '1.0',
          'author': '',
          'description': '',
        },
        'key_events': [],
        'gm_notes': [],
        'npcs': [
          {
            'npc_uuid': 'p1',
            'name': 'Guard',
            'state': 'active',
            'immutable': true,
          },
        ],
        'images': [
          {'image_uuid': 'img1', 'name': 'Map', 'immutable': true},
        ],
        'audio': [
          {'audio_uuid': 'a1', 'name': 'Theme', 'immutable': true},
        ],
        'paths': [
          {
            'name': 'Bloody',
            'color': 'red',
            'description': 'd',
            'immutable': true,
          },
        ],
        'notes': [
          {
            'note_uuid': 'n1',
            'note_name': 'Clue',
            'note_content': 'x',
            'immutable': true,
          },
        ],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Base',
            'description': '...',
            'scene_type': 'start',
            'next_scenes': ['s2'],
            'notes': ['n1'],
            'npcs': ['Guard'],
            'images': ['img1'],
            'audio': ['a1'],
            'bg_image': 'bg1',
            'immutable': true,
          },
          {
            'scene_uuid': 's2',
            'name': 'Old target',
            'description': '...',
            'scene_type': 'standard',
            'immutable': true,
          },
        ],
      }),
    );
    await File(
      '${dir.path}/group.json',
    ).writeAsString(jsonEncode({'group': 'Wed', 'players': <String>[]}));
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: GameScreen.save(saveName: saveName, onHome: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('game_save_frozen: frozen scene locked + next_scenes exception + '
      'add stays; frozen note locked; paths read-only', (tester) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSave(harness);
    await pumpEditor(tester);

    // STEP 1 — Scenes: the base scene is locked (no delete); adding stays. The
    // rail's Export / Export elements actions are hidden in save-edit.
    expect(byId('game.root'), findsOneWidget);
    expect(byId('scene.tile.s1.locked'), findsOneWidget);
    expect(byId('scene.tile.s1.delete'), findsNothing);
    expect(byId('scene.new'), findsOneWidget);
    expect(byId('nav.game.publish'), findsNothing);
    expect(byId('nav.game.export_part'), findsNothing);

    // STEP 2 — a frozen scene STILL opens, in the restricted editor: next_scenes
    // is editable, but the link to the immutable s2 is not removable.
    await tester.tap(byId('scene.tile.s1'));
    await tester.pumpAndSettle();
    expect(byId('game.scenes.edit.root'), findsOneWidget);
    expect(byId('game.scenes.edit.nextscenes.add'), findsOneWidget);
    expect(byId('game.scenes.edit.nextscenes.tile.s2.locked'), findsOneWidget);
    expect(byId('game.scenes.edit.nextscenes.tile.s2.delete'), findsNothing);

    // The frozen scene's linked reference tiles show a LOCK instead of a delete
    // button: bg image, note, NPC, image, soundtrack.
    expect(byId('game.scenes.edit.bgimage.tile.bg1.locked'), findsOneWidget);
    expect(byId('game.scenes.edit.bgimage.tile.bg1.delete'), findsNothing);
    expect(byId('game.scenes.edit.notes.tile.n1.locked'), findsOneWidget);
    expect(byId('game.scenes.edit.notes.tile.n1.delete'), findsNothing);
    expect(
      byId('game.scenes.edit.npc.carousel.tile.p1.locked'),
      findsOneWidget,
    );
    expect(byId('game.scenes.edit.npc.carousel.tile.p1.delete'), findsNothing);
    expect(
      byId('game.scenes.edit.images.carousel.tile.img1.locked'),
      findsOneWidget,
    );
    expect(
      byId('game.scenes.edit.images.carousel.tile.img1.delete'),
      findsNothing,
    );
    expect(byId('game.scenes.edit.audio.tile.a1.locked'), findsOneWidget);
    expect(byId('game.scenes.edit.audio.tile.a1.delete'), findsNothing);

    // STEP 3 — the next-scene picker offers ONLY non-immutable scenes: the
    // immutable s2 is not a candidate (so it can be neither added nor toggled
    // off — this closes the earlier removal bypass). The add button is inside the
    // scrollable form, so scroll it into view before tapping.
    await tester.ensureVisible(byId('game.scenes.edit.nextscenes.add'));
    await tester.pumpAndSettle();
    await tester.tap(byId('game.scenes.edit.nextscenes.add'));
    await tester.pumpAndSettle();
    expect(byId('scene.nextscenes.select.tile.s2'), findsNothing);
    await tester.tap(byId('scene.nextscenes.select.cancel'));
    await tester.pumpAndSettle();

    // STEP 4 — back to the scene list.
    await tester.tap(byId('game.scenes.edit.cancel'));
    await tester.pumpAndSettle();

    // STEP 4 — Notes: the frozen note is locked (no delete).
    await tester.tap(byId('nav.game.notes'));
    await tester.pumpAndSettle();
    expect(byId('note.tile.n1.locked'), findsOneWidget);
    expect(byId('note.tile.n1.delete'), findsNothing);

    // BRANCH paths_readonly — every path colour is locked (read-only section).
    await tester.tap(byId('nav.game.paths'));
    await tester.pumpAndSettle();
    expect(byId('path.tile.red.locked'), findsOneWidget);
  });
}
