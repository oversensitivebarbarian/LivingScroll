// Integration test for party split from the play view:
// the Split dialog, the PiP bar of the un-focused track, switching focus, track
// divergence (no merge), and resume-after-split (party.json restore).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:living_scroll/widgets/pip_track_tile.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const saveName = 'Pack-1.0.0-Team A';

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // A library adventure "Pack" — one start scene s1 branching to s2 "Left" and
  // s3 "Middle", so two tracks can diverge.
  Future<void> seedSplitPack(CreateHarness harness) async {
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
            'next_scenes': ['s2', 's3'],
          },
          {'scene_uuid': 's2', 'name': 'Left', 'scene_type': 'standard'},
          {'scene_uuid': 's3', 'name': 'Middle', 'scene_type': 'standard'},
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

  Directory saveDir(CreateHarness h) =>
      Directory('${h.savesDir.path}/$saveName');

  Future<void> settleIO(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> party(CreateHarness h) =>
      jsonDecode(File('${saveDir(h).path}/party.json').readAsStringSync())
          as Map<String, dynamic>;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  // Library -> Pack info -> Play -> launch: enter the group + players Alice/Bob,
  // then Play into gameplay at s1.
  Future<void> launchGameplay(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Pack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library.adventure.info.play')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('launch.field.group')),
      'Team A',
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('launch.players.add')));
      await tester.pumpAndSettle();
    }
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
  }

  // Opens the Split dialog, assigns Bob to the new track, confirms.
  Future<void> splitBobOut(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('play.split')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.pc.Bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('play_split: split -> PiP -> focus switch -> track divergence', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSplitPack(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester);

    // STEP 1: on s1 the Split button is enabled (2 players, 1 track).
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Opening',
    );
    expect(enabled(tester, 'play.split'), isTrue);
    expect(find.byType(PipTrackTile), findsNothing); // not split yet

    // Split Bob onto a new track (Alice stays, focused).
    await splitBobOut(tester);
    await settleIO(tester);

    // PiP bar shows the un-focused track (Bob); Split now disabled (tracks==players).
    expect(find.byType(PipTrackTile), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget); // Bob's PiP label
    expect(enabled(tester, 'play.split'), isFalse);

    // party.json: 2 tracks, Alice focused on s1, Bob not focused on s1.
    final p = party(harness);
    final tracks = p['tracks'] as List;
    expect(tracks.length, 2);
    expect((tracks[0] as Map)['pc_names'], ['Alice']);
    expect((tracks[0] as Map)['focused'], true);
    expect((tracks[0] as Map)['current_scene_uuid'], 's1');
    expect((tracks[1] as Map)['pc_names'], ['Bob']);
    expect((tracks[1] as Map)['focused'], false);

    // STEP 2: tap the PiP tile -> focus switches to Bob; now Alice is the PiP.
    await tester.tap(find.byType(PipTrackTile));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    final p2 = party(harness);
    expect(((p2['tracks'] as List)[1] as Map)['focused'], true);

    // STEP 3: navigate Bob to Middle (s3); Alice's track stays on s1. No merge.
    await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Middle',
    );
    expect(find.byType(PipTrackTile), findsOneWidget); // still split (no merge)
    final p3 = party(harness);
    final t3 = p3['tracks'] as List;
    expect(t3.length, 2);
    expect((t3[0] as Map)['current_scene_uuid'], 's1'); // Alice
    expect((t3[1] as Map)['current_scene_uuid'], 's3'); // Bob

    // group.json roster is untouched by the split.
    final group =
        jsonDecode(
              File('${saveDir(harness).path}/group.json').readAsStringSync(),
            )
            as Map;
    expect(group['players'], ['Alice', 'Bob']);
  });

  testWidgets('play_split: Cancel on the split dialog creates no track', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSplitPack(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester);

    await tester.tap(find.byKey(const ValueKey('play.split')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.pc.Bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.cancel')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    // No new track: no PiP bar, Split still enabled, no party.json written.
    expect(find.byType(PipTrackTile), findsNothing);
    expect(enabled(tester, 'play.split'), isTrue);
    expect(File('${saveDir(harness).path}/party.json').existsSync(), isFalse);
  });

  testWidgets('play_split: resume after a split restores the two tracks', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedSplitPack(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester);
    await splitBobOut(tester);
    await settleIO(tester);
    // Diverge: focus Bob and move him to Middle.
    await tester.tap(find.byType(PipTrackTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.nextscene.Middle')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    // Pause -> Home.
    await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.pause.ok')));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(find.byKey(const ValueKey('play.scene.title')), findsNothing);

    // Resume via Library Saves -> the save tile -> launch resume -> Play.
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('adventure.tile.$saveName')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    // The split is restored: Bob focused on Middle, Alice as the PiP on s1.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data,
      'Middle',
    );
    expect(find.byType(PipTrackTile), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });
}
