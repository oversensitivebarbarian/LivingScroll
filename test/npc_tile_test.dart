import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/screens/npcs_screen.dart';
import 'package:living_scroll/widgets/npc_tile.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: home),
    );

const _uuid = '11111111-1111-1111-1111-111111111111';

Widget _tile({NpcVillainStats? villain, double width = NpcTile.maxExtent}) =>
    Center(
      child: SizedBox(
        width: width,
        child: NpcTile(
          uuid: _uuid,
          image: null,
          villain: villain,
          onTap: () {},
          onClone: () {},
          onDelete: () {},
        ),
      ),
    );

Finder _tileRoot() => find.byKey(const ValueKey('game.npc.tile.$_uuid'));
Finder _byUuid(String suffix) =>
    find.byKey(ValueKey('game.npc.tile.$_uuid.$suffix'));

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('NpcTile villain badges', () {
    testWidgets('a Villain shows three bottom badges with value + name',
        (tester) async {
      big(tester);
      await tester.pumpWidget(_app(_tile(
          villain: const NpcVillainStats(strength: 5, influence: 3, rank: 8))));
      await tester.pumpAndSettle();

      for (final id in ['strength', 'influence', 'rank']) {
        expect(_byUuid('villain.$id'), findsOneWidget);
      }
      // Values.
      expect(_byUuid('villain.strength.value'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // strength
      expect(find.text('3'), findsOneWidget); // influence
      expect(find.text('8'), findsOneWidget); // rank = 5 + 3
      // English trait names.
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Influence'), findsOneWidget);
      expect(find.text('Rank'), findsOneWidget);
    });

    testWidgets('badge band is 1/5 of the tile height', (tester) async {
      big(tester);
      await tester.pumpWidget(_app(_tile(
          villain: const NpcVillainStats(strength: 1, influence: 1, rank: 2))));
      await tester.pumpAndSettle();

      final tileHeight = tester.getSize(_tileRoot()).height;
      final bandHeight = tester.getSize(_byUuid('villain')).height;
      expect(bandHeight, closeTo(tileHeight / 5, 0.6));
    });

    testWidgets('each badge has a margin (touches neither edges nor neighbours)',
        (tester) async {
      big(tester);
      await tester.pumpWidget(_app(_tile(
          villain: const NpcVillainStats(strength: 1, influence: 1, rank: 2))));
      await tester.pumpAndSettle();

      final band = tester.getRect(_byUuid('villain'));
      final first = tester.getRect(_byUuid('villain.strength'));
      final third = tester.getRect(_byUuid('villain.rank'));

      // Vertical margin: the badge is shorter than the band and inset from top.
      expect(first.height, lessThan(band.height));
      expect(first.top, greaterThan(band.top));
      // Horizontal margin: narrower than a full third, inset from the tile edges.
      expect(first.width, lessThan(band.width / 3));
      expect(first.left, greaterThan(band.left)); // left edge gap
      expect(third.right, lessThan(band.right)); // right edge gap
    });

    testWidgets('Polish locale uses Siła / Wpływ / Ranga', (tester) async {
      big(tester);
      await tester.pumpWidget(_app(
          _tile(
              villain:
                  const NpcVillainStats(strength: 2, influence: 4, rank: 6)),
          locale: const Locale('pl')));
      await tester.pumpAndSettle();
      expect(find.text('Siła'), findsOneWidget);
      expect(find.text('Wpływ'), findsOneWidget);
      expect(find.text('Ranga'), findsOneWidget);
    });

    testWidgets('a non-Villain (villain: null) tile has no badges',
        (tester) async {
      big(tester);
      await tester.pumpWidget(_app(_tile(villain: null)));
      await tester.pumpAndSettle();
      expect(_byUuid('villain'), findsNothing);
    });

    testWidgets('badges never overflow at tiny tile sizes (Villain + Brute)',
        (tester) async {
      big(tester); // the SizedBox width — not the window — sets the tile size.
      // Multi-digit values stress the badge width; tiny widths make the 1/5-band
      // cell only a few px tall — the single FittedBox must scale, not overflow.
      const villain = NpcVillainStats(strength: 12, influence: 8, rank: 20);
      const brute =
          NpcVillainStats(kind: 'brute_squad', strength: 99, influence: 0, rank: 0);
      for (final w in <double>[24, 36, 48, 72, 110, 160]) {
        await tester.pumpWidget(_app(_tile(villain: villain, width: w)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'villain tile @ width $w');

        await tester.pumpWidget(_app(_tile(villain: brute, width: w)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'brute tile @ width $w');
      }
    });

    testWidgets('a Brute shows ONE centered Strength badge (no influence/rank)',
        (tester) async {
      big(tester);
      await tester.pumpWidget(_app(_tile(
          villain: const NpcVillainStats(
              kind: 'brute_squad', strength: 7, influence: 0, rank: 0))));
      await tester.pumpAndSettle();

      // Only the Strength badge — no Influence / Rank.
      expect(_byUuid('villain.strength'), findsOneWidget);
      expect(_byUuid('villain.influence'), findsNothing);
      expect(_byUuid('villain.rank'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);

      // The single badge is CENTERED in the band and narrower than full width
      // (about a third), leaving a spacer on each side.
      final band = tester.getRect(_byUuid('villain'));
      final badge = tester.getRect(_byUuid('villain.strength'));
      expect(badge.center.dx, closeTo(band.center.dx, 0.6)); // centered
      expect(badge.width, lessThan(band.width / 2)); // not full width
      expect(badge.left, greaterThan(band.left)); // left spacer
      expect(badge.right, lessThan(band.right)); // right spacer
    });
  });

  group('NpcsScreen wires villain badges by system + kind', () {
    NpcsController buildController(
        {required String systemId, required Map<String, dynamic> stats}) {
      final c = NpcsController(newId: () => 'x');
      c.setTemplate(SevenSea.template,
          systemId: systemId, pruneHiddenStats: true);
      c.loadFrom({
        'npcs': [
          {'name': 'Foe', 'npc_uuid': _uuid, 'stats': stats}
        ],
      });
      return c;
    }

    Future<void> pumpScreen(WidgetTester tester, NpcsController c) async {
      await tester.pumpWidget(_app(NpcsScreen(
        controller: c,
        imagesBasePath: '/nowhere',
        onSave: () async {},
        onClone: (_) async {},
        onDelete: (_) async {},
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('7th Sea Villain NPC tile shows the badges', (tester) async {
      big(tester);
      await pumpScreen(
          tester,
          buildController(systemId: SevenSea.systemId, stats: {
            'kind': 'villain',
            'strength': 6,
            'influence': 4,
          }));
      expect(_byUuid('villain'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // strength
      expect(find.text('4'), findsOneWidget); // influence
      expect(find.text('10'), findsOneWidget); // rank = 6 + 4
    });

    testWidgets(
        'Villain Influence AND Rank drop by the influence invested in schemes',
        (tester) async {
      big(tester);
      await pumpScreen(
          tester,
          buildController(systemId: SevenSea.systemId, stats: {
            'kind': 'villain',
            'strength': 6,
            'influence': 10,
            'schemes': [
              {'type': 'scheme', 'name': 'A', 'cost': 4},
              {'type': 'scheme', 'name': 'B', 'cost': 3},
            ],
          }));
      // Influence badge = 10 − (4 + 3) = 3; Rank = 6 + available 3 = 9
      // (recalculated from the available influence, not the full rating).
      expect(tester.widget<Text>(_byUuid('villain.influence.value')).data, '3');
      expect(tester.widget<Text>(_byUuid('villain.rank.value')).data, '9');
      expect(tester.widget<Text>(_byUuid('villain.strength.value')).data, '6');
    });

    testWidgets('7th Sea Brute NPC tile shows a single Strength badge',
        (tester) async {
      big(tester);
      await pumpScreen(
          tester,
          buildController(systemId: SevenSea.systemId, stats: {
            'kind': 'brute_squad',
            'strength': 8,
          }));
      expect(_byUuid('villain'), findsOneWidget);
      expect(_byUuid('villain.strength'), findsOneWidget);
      expect(_byUuid('villain.influence'), findsNothing);
      expect(_byUuid('villain.rank'), findsNothing);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('7th Sea Monster NPC tile has no badges', (tester) async {
      big(tester);
      await pumpScreen(tester,
          buildController(systemId: SevenSea.systemId, stats: {'kind': 'monster'}));
      expect(_byUuid('villain'), findsNothing);
    });

    testWidgets('a non-7th-Sea system never shows the badges', (tester) async {
      big(tester);
      await pumpScreen(
          tester,
          buildController(systemId: 'basic', stats: {
            'kind': 'villain',
            'strength': 6,
            'influence': 4,
          }));
      expect(_byUuid('villain'), findsNothing);
    });
  });

  group('sevenSeaVillain — influence spent on schemes', () {
    test('influence AND rank use the available influence (− scheme costs)', () {
      final v = sevenSeaVillain('7thsea2e', {
        'kind': 'villain',
        'strength': 6,
        'influence': 10,
        'schemes': [
          {'type': 'scheme', 'name': 'A', 'cost': 4},
          {'type': 'scheme', 'name': 'B', 'cost': 3},
        ],
      })!;
      expect(v.influence, 3); // 10 − 7
      expect(v.rank, 9); // 6 + available 3 (recalculated from invested influence)
      expect(v.rank, v.strength + v.influence); // always consistent
      expect(v.strength, 6);
    });

    test('no schemes -> influence = stored, rank = strength + influence', () {
      final v = sevenSeaVillain(
          '7thsea2e', {'kind': 'villain', 'strength': 6, 'influence': 10})!;
      expect(v.influence, 10);
      expect(v.rank, 16); // 6 + 10
    });

    test('a Brute is unaffected (no influence, no schemes)', () {
      final v =
          sevenSeaVillain('7thsea2e', {'kind': 'brute_squad', 'strength': 8})!;
      expect(v.influence, 0);
      expect(v.rank, 0);
    });
  });
}
