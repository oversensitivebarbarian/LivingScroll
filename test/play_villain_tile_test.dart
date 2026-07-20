import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/npc_tile.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: home),
    );

Scene _scene() => Scene.fromJson({
      'name': 'Scene',
      'scene_uuid': 's1',
      'scene_type': 'start',
      'description': 'A room.',
    });

PlayNpc _npc({NpcVillainStats? villain}) => (
      uuid: 'v1',
      name: 'The Boss',
      iconImage: null,
      fullImage: null,
      description: '',
      backstory: '',
      state: 'active',
      stats: const <({String label, String value})>[],
      villain: villain,
      sevenSeaStats: const {},
    );

Widget _play(PlayNpc npc, {Locale locale = const Locale('en')}) => _app(
      PlayScreen(
        scene: _scene(),
        mode: PlayMode.gameplay,
        keyEvents: const [],
        nextScenes: const [],
        npcs: [npc],
        notes: const [],
        images: const [],
        onExit: () {},
      ),
      locale: locale,
    );

Finder _villain(String suffix) =>
    find.byKey(ValueKey('play.npc.tile.v1.villain$suffix'));

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('play view Villain tile shows the same Strength/Influence/Rank badges',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_play(_npc(
        villain: const NpcVillainStats(strength: 6, influence: 4, rank: 10))));
    await tester.pumpAndSettle();

    // The NPC grid is the default centre view when the scene has NPCs.
    expect(find.byKey(const ValueKey('play.npc.grid')), findsOneWidget);
    // The badge band + three badges (same keys shape as the game tile).
    expect(_villain(''), findsOneWidget);
    for (final id in ['.strength', '.influence', '.rank']) {
      expect(_villain(id), findsOneWidget);
    }
    // Values (Rank = strength + influence).
    expect(find.text('6'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    // English trait names.
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Influence'), findsOneWidget);
    expect(find.text('Rank'), findsOneWidget);
  });

  testWidgets('play view Villain badge band is 1/5 of the tile height',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_play(_npc(
        villain: const NpcVillainStats(strength: 1, influence: 1, rank: 2))));
    await tester.pumpAndSettle();

    final tileHeight =
        tester.getSize(find.byKey(const ValueKey('play.npc.tile.v1'))).height;
    final bandHeight = tester.getSize(_villain('')).height;
    expect(bandHeight, closeTo(tileHeight / 5, 0.6));
  });

  testWidgets('play view Polish locale uses Siła / Wpływ / Ranga',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_play(
        _npc(villain: const NpcVillainStats(strength: 2, influence: 3, rank: 5)),
        locale: const Locale('pl')));
    await tester.pumpAndSettle();
    expect(find.text('Siła'), findsOneWidget);
    expect(find.text('Wpływ'), findsOneWidget);
    expect(find.text('Ranga'), findsOneWidget);
  });

  testWidgets('play view Villain Influence AND Rank drop by scheme costs',
      (tester) async {
    big(tester);
    // Built through the shared sevenSeaVillain() helper (the same path the Play
    // hosts use) so the badges reflect the influence-spent-on-schemes calc.
    final v = sevenSeaVillain('7thsea2e', {
      'kind': 'villain',
      'strength': 6,
      'influence': 10,
      'schemes': [
        {'type': 'scheme', 'name': 'A', 'cost': 7}
      ],
    })!;
    await tester.pumpWidget(_play(_npc(villain: v)));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_villain('.influence.value')).data, '3'); // 10-7
    expect(tester.widget<Text>(_villain('.rank.value')).data, '9'); // 6 + 3
  });

  testWidgets('play view Brute tile shows a single Strength badge',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_play(_npc(
        villain: const NpcVillainStats(
            kind: 'brute_squad', strength: 8, influence: 0, rank: 0))));
    await tester.pumpAndSettle();

    expect(_villain(''), findsOneWidget);
    expect(_villain('.strength'), findsOneWidget);
    expect(_villain('.influence'), findsNothing);
    expect(_villain('.rank'), findsNothing);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
  });

  testWidgets('play view non-Villain NPC tile has no badges', (tester) async {
    big(tester);
    await tester.pumpWidget(_play(_npc(villain: null)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play.npc.tile.v1')), findsOneWidget);
    expect(_villain(''), findsNothing);
  });
}
