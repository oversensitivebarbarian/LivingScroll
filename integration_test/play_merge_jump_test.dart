// Integration test for party-split convergence and
// routing: automatic merge (via a shared scene AND via the marked next-scene
// option), dead-end + Jump to scene, jumping onto another track's ad-hoc scene
// (merge), ending one of several tracks, and resuming onto an ad-hoc scene.

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

  Future<void> writeIndex(CreateHarness harness) async {
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

  // Graph: s1 -> {s2 "Left", s3 "Right"} -> s4 "Meet" -> {s5 "DeadEnd", s6 "Finale"(end)}.
  Future<void> seedGraph(CreateHarness harness) async {
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
            'scene_type': 'start',
            'next_scenes': ['s2', 's3'],
          },
          {
            'scene_uuid': 's2',
            'name': 'Left',
            'scene_type': 'standard',
            'next_scenes': ['s4'],
          },
          {
            'scene_uuid': 's3',
            'name': 'Right',
            'scene_type': 'standard',
            'next_scenes': ['s4'],
          },
          {
            'scene_uuid': 's4',
            'name': 'Meet',
            'scene_type': 'standard',
            'next_scenes': ['s5', 's6'],
          },
          {'scene_uuid': 's5', 'name': 'DeadEnd', 'scene_type': 'standard'},
          {'scene_uuid': 's6', 'name': 'Finale', 'scene_type': 'end'},
        ],
      }),
    );
    await writeIndex(harness);
  }

  // Two DISJOINT end paths so each track can reach an end without the global
  // `visited` hiding the other's route: s1 -> {s2 "Left"(end), s3 "Right"(end)}.
  Future<void> seedEndTrack(CreateHarness harness) async {
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
            'scene_type': 'start',
            'next_scenes': ['s2', 's3'],
          },
          {'scene_uuid': 's2', 'name': 'Left', 'scene_type': 'end'},
          {'scene_uuid': 's3', 'name': 'Right', 'scene_type': 'end'},
        ],
      }),
    );
    await writeIndex(harness);
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

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('play.scene.title'))).data!;

  // Library -> Pack -> Play -> launch (group + optional players) -> Play (gameplay).
  Future<void> launchGameplay(
    WidgetTester tester, {
    List<String> players = const [],
  }) async {
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
    for (var i = 0; i < players.length; i++) {
      await tester.tap(find.byKey(const ValueKey('launch.players.add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('launch.player.$i')),
        players[i],
      );
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
  }

  Future<void> splitBobOut(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('play.split')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.pc.Bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.split.confirm')));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('play.nextscene.$name')));
    await tester.pumpAndSettle();
  }

  Future<void> switchFocus(WidgetTester tester) async {
    await tester.tap(find.byType(PipTrackTile).first);
    await tester.pumpAndSettle();
  }

  testWidgets('play_merge_jump: two tracks converge on a scene -> merge', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedGraph(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester, players: ['Alice', 'Bob']);
    await splitBobOut(tester); // focus Alice(s1), PiP Bob(s1)
    await settleIO(tester);

    // Alice: s1 -> Left(s2) -> Meet(s4).
    await tapNext(tester, 'Left');
    await tapNext(tester, 'Meet');
    expect(title(tester), 'Meet');
    expect(find.byType(PipTrackTile), findsOneWidget); // Bob still split

    // Focus Bob (on s1) -> Right(s3).
    await switchFocus(tester);
    await tapNext(tester, 'Right');
    expect(title(tester), 'Right');

    // Bob's Next scenes: Meet carries the "-> merge" marker (Alice stands on s4).
    expect(
      find.byKey(const ValueKey('play.nextscene.Meet.merge')),
      findsOneWidget,
    );

    // Follow Meet -> Bob enters s4 where Alice is -> MERGE.
    await tapNext(tester, 'Meet');
    await settleIO(tester);
    expect(title(tester), 'Meet');
    expect(find.byType(PipTrackTile), findsNothing); // merged: no PiP
    final tracks = party(harness)['tracks'] as List;
    expect(tracks.length, 1);
    expect(Set<String>.from((tracks.single as Map)['pc_names'] as List), {
      'Alice',
      'Bob',
    }); // PC unioned
  });

  testWidgets('play_merge_jump: a dead end shows Jump to scene', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedGraph(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester); // single track (no players)

    // Walk to the dead-end scene s5 (no next scenes): s1 -> Left -> Meet -> DeadEnd.
    await tapNext(tester, 'Left');
    await tapNext(tester, 'Meet');
    await tapNext(tester, 'DeadEnd');
    await settleIO(tester);
    expect(title(tester), 'DeadEnd');

    // No next-scene buttons, but Jump to scene appears (dead end).
    expect(find.byKey(const ValueKey('play.nextscene.Meet')), findsNothing);
    expect(find.byKey(const ValueKey('play.jump')), findsOneWidget);

    // The jump dialog lists unvisited AUTHOR scenes; tapping one navigates there.
    await tester.tap(find.byKey(const ValueKey('play.jump')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.jump.dialog')), findsOneWidget);
    // s3 "Right" was never visited -> it is a target.
    expect(find.text('Right'), findsOneWidget);
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(find.byKey(const ValueKey('play.jump.dialog')), findsNothing);
    expect(title(tester), 'Right');
  });

  testWidgets('play_merge_jump: jumping onto another track ad-hoc scene merges', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedGraph(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester, players: ['Alice', 'Bob']);
    await splitBobOut(tester); // focus Alice(s1), PiP Bob(s1)
    await settleIO(tester);

    // Focus Bob, start an ad-hoc scene "Zasadzka".
    await switchFocus(tester); // focus Bob
    await tester.tap(find.byKey(const ValueKey('play.nextscene.adhoc')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('play.adhoc.name')),
      'Zasadzka',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.adhoc.confirm')));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(title(tester), 'Zasadzka');

    // Focus Alice; Jump dialog offers Bob's ad-hoc position (merge marker) but NOT
    // as a generic target.
    await switchFocus(tester); // focus Alice (on s1)
    await tester.tap(find.byKey(const ValueKey('play.jump')));
    await tester.pumpAndSettle();
    expect(find.text('Zasadzka'), findsOneWidget); // Bob's ad-hoc position
    expect(find.byIcon(Icons.merge), findsOneWidget); // its "-> merge" marker

    // Jump onto it -> Alice lands on the shared ad-hoc uuid -> MERGE.
    await tester.tap(find.text('Zasadzka'));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(title(tester), 'Zasadzka');
    expect(find.byType(PipTrackTile), findsNothing); // merged
    final tracks = party(harness)['tracks'] as List;
    expect(tracks.length, 1);
    expect(Set<String>.from((tracks.single as Map)['pc_names'] as List), {
      'Alice',
      'Bob',
    });
  });

  testWidgets(
    'play_merge_jump: Finish adventure is disabled while split until every '
    'track reaches an end scene',
    (tester) async {
      useDesktopView(tester);
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedEndTrack(harness);

      await harness.pumpApp(tester);
      await launchGameplay(tester, players: ['Alice', 'Bob']);
      await splitBobOut(tester); // focus Alice(s1), PiP Bob(s1)
      await settleIO(tester);

      // Alice: s1 -> Left(end). Bob is still on the start scene (NOT an end), so
      // the whole adventure cannot finish yet: Finish adventure is shown but
      // DISABLED, and there is no per-track "End track" button anymore.
      await tapNext(tester, 'Left');
      expect(title(tester), 'Left');
      expect(find.byKey(const ValueKey('play.finish.track')), findsNothing);
      final finish = find.byKey(const ValueKey('play.finish'));
      expect(finish, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(finish).enabled, isFalse);

      // Bring Bob to his OWN end scene (Right) — a DIFFERENT end scene from Alice's.
      await switchFocus(tester); // focus Bob (on s1)
      await tapNext(tester, 'Right');
      await settleIO(tester);
      expect(title(tester), 'Right');
      expect(
        find.byType(PipTrackTile),
        findsOneWidget,
      ); // still two tracks split

      // Now EVERY track stands on an end scene -> Finish adventure is enabled.
      expect(tester.widget<ButtonStyleButton>(finish).enabled, isTrue);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      await settleIO(tester);
      // The whole save is archived to {Finished} and we return Home.
      expect(find.byKey(const ValueKey('play.scene.title')), findsNothing);
      expect(saveDir(harness).existsSync(), isFalse);
    },
  );

  testWidgets('play_merge_jump: an ad-hoc scene is resumable (single track)', (
    tester,
  ) async {
    useDesktopView(tester);
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedGraph(harness);

    await harness.pumpApp(tester);
    await launchGameplay(tester); // single track
    // Start an ad-hoc scene, then pause.
    await tester.tap(find.byKey(const ValueKey('play.nextscene.adhoc')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('play.adhoc.name')),
      'Detour',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.adhoc.confirm')));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(title(tester), 'Detour');

    await tester.tap(find.byKey(const ValueKey('nav.play.pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.pause.ok')));
    await tester.pumpAndSettle();
    await settleIO(tester);

    // Resume -> lands back on the ad-hoc scene (restored from party.json).
    await tester.tap(find.byKey(const ValueKey('nav.library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library.tab.saves')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('adventure.tile.$saveName')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('launch.play')));
    await tester.pumpAndSettle();
    await settleIO(tester);
    expect(title(tester), 'Detour');
  });
}
