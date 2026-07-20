import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/widgets/event_tile.dart';
import 'package:living_scroll/widgets/note_tile.dart';
import 'package:living_scroll/widgets/npc_tile.dart';
import 'package:living_scroll/widgets/path_tile.dart';
import 'package:living_scroll/widgets/scene_tile.dart';
import 'package:living_scroll/widgets/soundtrack_tile.dart';

/// A `locked` (immutable, save-edit) tile shows a lock badge
/// instead of a delete button; a NON-scene locked tile does not open its editor;
/// a locked SCENE tile still opens (the editor restricts it to next_scenes). An
/// unlocked (mutable) tile keeps its delete button and opens as usual.

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  Finder byId(String k) => find.byKey(ValueKey(k));

  group('locked tiles show a lock, hide delete, and (non-scene) do not open', () {
    testWidgets('NoteTile', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          NoteTile(
            uuid: 'n1',
            name: 'Clue',
            onTap: () => opened = true,
            onDelete: () {},
            locked: true,
          ),
        ),
      );
      expect(byId('note.tile.n1.locked'), findsOneWidget);
      expect(byId('note.tile.n1.delete'), findsNothing);
      await tester.tap(byId('note.tile.n1'));
      await tester.pump();
      expect(opened, isFalse, reason: 'locked note must not open its editor');
    });

    testWidgets('NoteTile unlocked keeps delete and opens', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          NoteTile(
            uuid: 'n2',
            name: 'New',
            onTap: () => opened = true,
            onDelete: () {},
          ),
        ),
      );
      expect(byId('note.tile.n2.locked'), findsNothing);
      expect(byId('note.tile.n2.delete'), findsOneWidget);
      await tester.tap(byId('note.tile.n2'));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('EventTile', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          EventTile(
            name: 'Alarm',
            onTap: () => opened = true,
            onDelete: () {},
            locked: true,
          ),
        ),
      );
      expect(byId('event.tile.Alarm.locked'), findsOneWidget);
      expect(byId('event.tile.Alarm.delete'), findsNothing);
      await tester.tap(byId('event.tile.Alarm'));
      await tester.pump();
      expect(opened, isFalse);
    });

    testWidgets('SoundtrackTile (locked = no delete)', (tester) async {
      await tester.pumpWidget(
        _host(
          SoundtrackTile(
            name: 'Theme',
            isPlaying: false,
            onPlayStop: () {},
            onDelete: () {},
            locked: true,
          ),
        ),
      );
      expect(byId('sound.tile.Theme.locked'), findsOneWidget);
      expect(byId('sound.tile.Theme.delete'), findsNothing);
      // Play/Stop stays available even when frozen.
      expect(byId('sound.tile.Theme.play'), findsOneWidget);
    });

    testWidgets('PathTile (locked = no open)', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          PathTile(
            colorId: 'red',
            color: const Color(0xFFD22828),
            name: 'Bloody',
            onTap: () => opened = true,
            locked: true,
          ),
        ),
      );
      expect(byId('path.tile.red.locked'), findsOneWidget);
      await tester.tap(byId('path.tile.red'));
      await tester.pump();
      expect(opened, isFalse);
    });

    // ImageTile is not pumped here — Image.file hangs in headless `flutter test`;
    // its lock uses the SAME shared TileLockBadge as the tiles above and the
    // same `locked ? null : onTap` gate, and is exercised end-to-end in the
    // integration test.

    testWidgets('NpcTile (locked = no open, menu keeps Clone, drops Delete)', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          NpcTile(
            uuid: 'p1',
            image: null,
            onTap: () => opened = true,
            onClone: () {},
            onDelete: () {},
            locked: true,
          ),
        ),
      );
      expect(byId('game.npc.tile.p1.locked'), findsOneWidget);
      await tester.tap(byId('game.npc.tile.p1'));
      await tester.pump();
      expect(opened, isFalse);
      // Open the menu: Clone present, Delete gone.
      await tester.tap(byId('game.npc.tile.menu.p1'));
      await tester.pumpAndSettle();
      expect(byId('game.npc.tile.menu.p1.item.clone'), findsOneWidget);
      expect(byId('game.npc.tile.menu.p1.item.delete'), findsNothing);
    });
  });

  group('locked SCENE tile still opens', () {
    testWidgets('SceneTile locked hides delete but keeps onTap', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          SceneTile(
            uuid: 's1',
            name: 'Room',
            sceneType: 'standard',
            discs: const [],
            onTap: () => opened = true,
            onDelete: () {},
            onPreview: () {},
            locked: true,
          ),
        ),
      );
      expect(byId('scene.tile.s1.locked'), findsOneWidget);
      expect(byId('scene.tile.s1.delete'), findsNothing);
      await tester.tap(byId('scene.tile.s1'));
      await tester.pump();
      expect(opened, isTrue, reason: 'a frozen scene must still open');
    });
  });
}
