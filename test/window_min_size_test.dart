// MINIMUM-WINDOW-SIZE layout guard.
//
// The app enforces a minimum window of 640×480 dp. This
// suite pumps every reasonably-instantiable surface at that footprint in BOTH
// orientations — landscape 640×480 and portrait 480×640 — and asserts NO layout
// exception (overflow / unbounded-constraint throw). If any of these fail, the
// UI is not safe at the declared minimum.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/npcs/stat_template.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/npc_7thsea_screen.dart';
import 'package:living_scroll/screens/npc_basicrpg_screen.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/detail_dialog.dart';
import 'package:living_scroll/widgets/npc_tile.dart';

// The minimum footprint in both orientations.
const _landscape = Size(640, 480);
const _portrait = Size(480, 640);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: home),
);

/// Pumps [build] at [size], runs the optional [after] action, and returns any
/// layout exception (overflow / thrown error) or null when clean.
Future<Object?> _run(
  WidgetTester tester,
  Size size,
  Widget Function() build, {
  Future<void> Function(WidgetTester)? after,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(build()));
  await tester.pumpAndSettle();
  try {
    if (after != null) await after(tester);
    await tester.pumpAndSettle();
  } catch (e) {
    return e;
  }
  return tester.takeException();
}

// --- fixtures ---------------------------------------------------------------

Scene _scene() => Scene.fromJson({
  'name': 'A scene with a title long enough to exercise wrapping',
  'scene_uuid': 's1',
  'scene_type': 'start',
  'description':
      'A long narration paragraph that spans several lines so the left '
      'column has real content to lay out in the two-column stage.',
});

PlayNpc _npc({NpcVillainStats? villain}) => (
  uuid: 'v1',
  name: 'The Count',
  iconImage: null,
  fullImage: null,
  description: 'A dangerous foe with a reasonably long description here.',
  backstory: 'Once a hero.',
  state: 'active',
  stats: const <({String label, String value})>[],
  villain: villain,
  sevenSeaStats: const {},
);

PlayScreen _play({List<PlayNpc> npcs = const []}) => PlayScreen(
  scene: _scene(),
  mode: PlayMode.gameplay,
  keyEvents: const [
    (name: 'Met the duke', checked: false),
    (name: 'Found the key', checked: false),
  ],
  // Empty next-scenes list; the bottom row still renders the Ad-hoc button
  // (a non-end scene), so the two bottom rows are exercised.
  nextScenes: const [],
  npcs: npcs,
  notes: const [
    (uuid: 'n1', name: 'A clue', content: 'A hidden lever behind the shelf.'),
  ],
  images: const [],
  onExit: () {},
);

NpcsController _seaVillain() {
  final c = NpcsController(newId: () => 'x')
    ..setTemplate(
      SevenSea.template,
      systemId: SevenSea.systemId,
      pruneHiddenStats: true,
    );
  c.loadFrom({
    'npcs': [
      {
        'name': 'The Count',
        'npc_uuid': 'v1',
        'full_image': 'full',
        'icon_image': 'icon',
        'stats': {
          ...SevenSea.template.defaults(),
          'kind': 'villain',
          'strength': 6,
          'influence': 4,
          'advantages': ['sorcery', 'able_drunker'],
        },
      },
    ],
  });
  c.beginEdit('v1');
  return c;
}

NpcsController _basic() {
  final c = NpcsController(newId: () => 'x')..setTemplate(StatTemplate.empty);
  c.loadFrom({
    'npcs': [
      {
        'name': 'Innkeeper',
        'npc_uuid': 'v1',
        'full_image': 'full',
        'icon_image': 'icon',
      },
    ],
  });
  c.beginEdit('v1');
  return c;
}

void main() {
  // Each surface is checked at BOTH orientations.
  const orientations = <(String, Size)>[
    ('landscape 640x480', _landscape),
    ('portrait 480x640', _portrait),
  ];

  for (final (label, size) in orientations) {
    group('@ $label', () {
      testWidgets('Play view (gameplay, NPC grid) has no overflow', (
        tester,
      ) async {
        final ex = await _run(tester, size, () => _play(npcs: [_npc()]));
        expect(find.byKey(const ValueKey('play.root')), findsOneWidget);
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets('Play view with a Villain (badges) has no overflow', (
        tester,
      ) async {
        final ex = await _run(
          tester,
          size,
          () => _play(
            npcs: [
              _npc(
                villain: const NpcVillainStats(
                  strength: 6,
                  influence: 4,
                  rank: 10,
                  advantages: ['sorcery'],
                ),
              ),
            ],
          ),
        );
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets('Play NPC info dialog (villain) has no overflow', (
        tester,
      ) async {
        final ex = await _run(
          tester,
          size,
          () => _play(
            npcs: [
              _npc(
                villain: const NpcVillainStats(
                  strength: 6,
                  influence: 4,
                  rank: 10,
                  advantages: ['sorcery'],
                ),
              ),
            ],
          ),
          after: (t) async {
            await t.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
            await t.pumpAndSettle();
          },
        );
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets(
        '7th Sea NPC editor (Villain details + advantages) no overflow',
        (tester) async {
          final c = _seaVillain();
          final ex = await _run(
            tester,
            size,
            () => Npc7thSeaScreen(
              controller: c,
              imagesBasePath: '/nowhere',
              onSave: () async => c.save(),
              onCancel: () {},
            ),
          );
          expect(
            find.byKey(const ValueKey('npc.7thsea.full_image')),
            findsOneWidget,
          );
          expect(ex, isNull, reason: '$ex');
        },
      );

      testWidgets('Basic RPG NPC editor has no overflow', (tester) async {
        final c = _basic();
        final ex = await _run(
          tester,
          size,
          () => NpcBasicRpgScreen(
            controller: c,
            imagesBasePath: '/nowhere',
            onSave: () async => c.save(),
            onCancel: () {},
          ),
        );
        expect(
          find.byKey(const ValueKey('npc_basicrpg.full_image')),
          findsOneWidget,
        );
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets('shared detail dialog has no overflow', (tester) async {
        final ex = await _run(
          tester,
          size,
          () => Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () => showDetailDialog(
                  ctx,
                  rootKey: 'd',
                  title: 'Title',
                  body: 'Body. ' * 80,
                  bodyKey: 'd.body',
                  okKey: 'd.ok',
                ),
                child: const Text('open'),
              ),
            ),
          ),
          after: (t) async {
            await t.tap(find.byKey(const ValueKey('open')));
            await t.pumpAndSettle();
          },
        );
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets('add-GM-note dialog has no overflow', (tester) async {
        final ex = await _run(
          tester,
          size,
          () => Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open'),
                onPressed: () => showAddGmNoteDialog(ctx),
                child: const Text('open'),
              ),
            ),
          ),
          after: (t) async {
            await t.tap(find.byKey(const ValueKey('open')));
            await t.pumpAndSettle();
          },
        );
        expect(ex, isNull, reason: '$ex');
      });

      testWidgets('Villain + Brute tiles in a small grid have no overflow', (
        tester,
      ) async {
        final ex = await _run(
          tester,
          size,
          () => GridView.count(
            crossAxisCount: 3,
            children: [
              NpcTile(
                uuid: 'a',
                image: null,
                villain: const NpcVillainStats(
                  strength: 12,
                  influence: 8,
                  rank: 20,
                ),
                onTap: () {},
                onClone: () {},
                onDelete: () {},
              ),
              NpcTile(
                uuid: 'b',
                image: null,
                villain: const NpcVillainStats(
                  kind: 'brute_squad',
                  strength: 99,
                  influence: 0,
                  rank: 0,
                ),
                onTap: () {},
                onClone: () {},
                onDelete: () {},
              ),
            ],
          ),
        );
        expect(ex, isNull, reason: '$ex');
      });
    });
  }
}
