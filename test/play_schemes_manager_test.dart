// The play-view Villain Schemes / Intrygi MANAGER:
// opened from the NPC info dialog's "Schemes" button, a two-panel dialog — LEFT
// Intrygi (settle pays cost×2 into influence, fail is a no-op; both grey + reorder),
// RIGHT purchased Koszty (Buy reduces influence). Every change is reported via
// onUpdateNpcStats.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/npc_tile.dart' show sevenSeaVillain;

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: home),
);

Scene _scene() => Scene.fromJson({
  'name': 'Scene',
  'scene_uuid': 's1',
  'scene_type': 'start',
  'description': 'A room.',
});

PlayNpc _npc(Map<String, dynamic> stats) => (
  uuid: 'v1',
  name: 'The Count',
  iconImage: null,
  fullImage: null,
  description: 'A foe.',
  backstory: '',
  state: 'active',
  stats: const <({String label, String value})>[],
  villain: sevenSeaVillain('7thsea2e', stats),
  sevenSeaStats: stats,
);

class _Host extends StatelessWidget {
  const _Host({required this.stats, required this.onUpdate});
  final Map<String, dynamic> stats;
  final void Function(String, Map<String, dynamic>) onUpdate;
  @override
  Widget build(BuildContext context) => PlayScreen(
    scene: _scene(),
    mode: PlayMode.gameplay,
    keyEvents: const [],
    nextScenes: const [],
    npcs: [_npc(stats)],
    notes: const [],
    images: const [],
    onExit: () {},
    onUpdateNpcStats: onUpdate,
  );
}

/// Opens the manager and returns a one-element holder that the manager fills with
/// its updated stats (via onUpdateNpcStats) on every mutation. The manager edits a
/// DEEP COPY of [stats]; the reported map is what the host would persist.
Future<List<Map<String, dynamic>?>> _openManager(
  WidgetTester tester,
  Map<String, dynamic> stats,
) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final reported = <Map<String, dynamic>?>[null];
  await tester.pumpWidget(
    _app(_Host(stats: stats, onUpdate: (_, s) => reported[0] = s)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('play.npc.info.v1.schemes')));
  await tester.pumpAndSettle();
  return reported;
}

Map<String, dynamic> _villain({
  int influence = 10,
  List<Map<String, dynamic>> schemes = const [],
}) => {
  'kind': 'villain',
  'strength': 6,
  'influence': influence,
  'advantages': <String>[],
  'schemes': schemes,
};

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final f = find.byKey(key);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  const mk = 'play.npc.info.v1.schemes'; // manager key prefix

  testWidgets('info dialog has a Schemes button that opens the manager', (
    tester,
  ) async {
    await _openManager(
      tester,
      _villain(
        schemes: [
          {'type': 'scheme', 'name': 'Plot', 'cost': 4},
        ],
      ),
    );
    expect(find.byKey(const ValueKey('$mk.dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('$mk.intrigue.0.label')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('$mk.intrigue.0.label')))
          .data,
      'Plot (4)',
    );
    // Close returns to the info window.
    await tester.tap(find.byKey(const ValueKey('$mk.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('$mk.dialog')), findsNothing);
    expect(find.byKey(const ValueKey('play.npc.info.v1')), findsOneWidget);
  });

  testWidgets('a Brute NPC info dialog has NO Schemes button', (tester) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        _Host(
          stats: {'kind': 'brute_squad', 'strength': 8},
          onUpdate: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.schemes')),
      findsNothing,
    );
  });

  testWidgets(
    'settle (check) adds cost×2 to influence; scheme greys + moves last',
    (tester) async {
      final reported = await _openManager(
        tester,
        _villain(
          influence: 10,
          schemes: [
            {'type': 'scheme', 'name': 'A', 'cost': 4},
            {'type': 'scheme', 'name': 'B', 'cost': 2},
          ],
        ),
      );

      await _tapVisible(tester, const ValueKey('$mk.intrigue.0.settle'));

      // 10 + 4*2 = 18; A is resolved and moved to the END of the list.
      final s = reported[0]!;
      final schemes = (s['schemes'] as List).cast<Map<String, dynamic>>();
      expect(s['influence'], 18);
      expect(schemes.last['name'], 'A');
      expect(schemes.last['resolved'], true);
      expect(schemes.first['name'], 'B'); // B rose to the front
    },
  );

  testWidgets('fail (X) computes nothing but still resolves the scheme', (
    tester,
  ) async {
    final reported = await _openManager(
      tester,
      _villain(
        influence: 10,
        schemes: [
          {'type': 'scheme', 'name': 'A', 'cost': 4},
        ],
      ),
    );

    await _tapVisible(tester, const ValueKey('$mk.intrigue.0.fail'));

    final s = reported[0]!;
    expect(s['influence'], 10); // unchanged
    expect((s['schemes'] as List).last['resolved'], true);
  });

  testWidgets('adding a scheme from the manager uses the game scheme dialog', (
    tester,
  ) async {
    final reported = await _openManager(tester, _villain(influence: 10));

    await _tapVisible(tester, const ValueKey('$mk.new'));
    // The SAME dialog as in the game view.
    expect(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.name')),
      'Ambush',
    );
    await tester.enterText(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.cost')),
      '3',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
    );
    await tester.pumpAndSettle();

    expect((reported[0]!['schemes'] as List).single, {
      'type': 'scheme',
      'name': 'Ambush',
      'cost': 3,
      'resolved': false,
    });
  });

  testWidgets('buying a cost reduces influence and lists it on the right', (
    tester,
  ) async {
    final reported = await _openManager(tester, _villain(influence: 10));

    await _tapVisible(tester, const ValueKey('$mk.buy'));
    expect(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog.name')),
      'Bribe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog.cost')),
      '3',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog.buy')),
    );
    await tester.pumpAndSettle();

    // Influence dropped by 3; a cost entry recorded and shown as text.
    final s = reported[0]!;
    expect(s['influence'], 7);
    expect((s['schemes'] as List).single, {
      'type': 'cost',
      'name': 'Bribe',
      'cost': 3,
    });
    expect(find.byKey(const ValueKey('$mk.cost.0')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('$mk.cost.0'))).data,
      'Bribe (3)',
    );
  });

  testWidgets('settling updates the Influence + Rank shown in the info dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        _Host(
          stats: _villain(
            influence: 10,
            schemes: [
              {'type': 'scheme', 'name': 'Plot', 'cost': 4},
            ],
          ),
          onUpdate: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the info dialog. Available influence = 10 − 4 = 6; rank = 6 + 6 = 12.
    await tester.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
    await tester.pumpAndSettle();
    String badge(String id) => tester
        .widget<Text>(
          find.byKey(ValueKey('play.npc.info.v1.villain.$id.value')),
        )
        .data!;
    expect(badge('influence'), '6');
    expect(badge('rank'), '12');

    // Open the manager and settle the Intryga.
    await tester.tap(find.byKey(const ValueKey(mk)));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const ValueKey('$mk.intrigue.0.settle'));

    // The info window (behind the manager) recomputed LIVE: stored influence
    // 10 + 4*2 = 18 -> available 18 − 4 = 14; rank = 6 + 14 = 20.
    expect(badge('influence'), '14');
    expect(badge('rank'), '20');
  });

  testWidgets('buying more than the available influence is blocked', (
    tester,
  ) async {
    final stats = _villain(influence: 3);
    await _openManager(tester, stats);
    await _tapVisible(tester, const ValueKey('$mk.buy'));
    await tester.enterText(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog.name')),
      'Big',
    );
    await tester.enterText(
      find.byKey(const ValueKey('play.npc.scheme.buy.dialog.cost')),
      '5',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('play.npc.scheme.buy.dialog.buy')),
          )
          .enabled,
      isFalse,
    );
  });
}
