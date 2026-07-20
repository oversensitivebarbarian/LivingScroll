// WINDOW-RESIZE REGRESSION GUARD.
//
// Opens each dialog at a battery of window sizes and asserts NO layout exception
// (RenderFlex overflow, unbounded-constraint throw, …). Guards the resize-audit
// fixes: Finding 1 (villain info right column scrolls), Finding 2 (info-frame
// height clamp), Finding 3 (note-content / add-GM-note dialogs are scrollable).
//
// NOTE — the PlayScreen-hosted dialogs are probed only at realistic heights
// (>= 480px). Below ~300px the PLAY STAGE itself (title + narration + the two
// bottom rows) overflows independently of any dialog — a separate concern
// (Finding 5) that a minimum window size covers; it is out of scope here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/detail_dialog.dart';
import 'package:living_scroll/widgets/npc_tile.dart' show NpcVillainStats;

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: home),
    );

// Hostile sizes for dialogs opened from a plain host (no PlayScreen behind them):
// includes an extreme 1100x250 short window.
const _isolatedSizes = <(String, Size)>[
  ('tiny 320x480', Size(320, 480)),
  ('short-wide 1100x250', Size(1100, 250)),
  ('phone 360x640', Size(360, 640)),
  ('control 1600x1000', Size(1600, 1000)),
];

// Sizes for PlayScreen-hosted dialogs — realistic minimums only (see header).
const _hostedSizes = <(String, Size)>[
  ('tiny 320x480', Size(320, 480)),
  ('short-wide 1400x480', Size(1400, 480)),
  ('phone 360x640', Size(360, 640)),
  ('control 1600x1000', Size(1600, 1000)),
];

Future<Object?> _probe(
  WidgetTester tester,
  Size size,
  Widget host,
  Future<void> Function(WidgetTester) open,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(host));
  await tester.pumpAndSettle();
  try {
    await open(tester);
    await tester.pumpAndSettle();
  } catch (e) {
    return e;
  }
  return tester.takeException();
}

Widget _opener(Future<void> Function(BuildContext) open) => Builder(
      builder: (ctx) => Center(
        child: ElevatedButton(
          key: const ValueKey('open'),
          onPressed: () => open(ctx),
          child: const Text('open'),
        ),
      ),
    );

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Scene _scene() => Scene.fromJson({
      'name': 'Scene',
      'scene_uuid': 's1',
      'scene_type': 'start',
      'description': 'A room with a long enough description to wrap a few lines.',
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

PlayScreen _play({
  List<PlayNpc> npcs = const [],
  List<({String uuid, String name, String content})> notes = const [],
}) =>
    PlayScreen(
      scene: _scene(),
      mode: PlayMode.gameplay,
      keyEvents: const [],
      nextScenes: const [],
      npcs: npcs,
      notes: notes,
      images: const [],
      onExit: () {},
    );

void main() {
  // ---- Dialogs openable from a plain host (probed down to 250px) ----
  for (final (label, size) in _isolatedSizes) {
    testWidgets('detail dialog @ $label', (tester) async {
      final ex = await _probe(
        tester,
        size,
        _opener((ctx) => showDetailDialog(
              ctx,
              rootKey: 'audit.detail',
              title: 'A title',
              body: 'Body text. ' * 60,
              bodyKey: 'audit.detail.body',
              okKey: 'audit.detail.ok',
            )),
        _tapOpen,
      );
      expect(ex, isNull, reason: 'detail dialog overflowed at $label: $ex');
    });

    testWidgets('add-GM-note dialog @ $label', (tester) async {
      final ex = await _probe(
        tester,
        size,
        _opener((ctx) => showAddGmNoteDialog(ctx)),
        _tapOpen,
      );
      expect(ex, isNull, reason: 'add-GM-note dialog overflowed at $label: $ex');
    });
  }

  // ---- PlayScreen-hosted dialogs (probed at realistic heights) ----
  for (final (label, size) in _hostedSizes) {
    testWidgets('play note-content dialog @ $label', (tester) async {
      final ex = await _probe(
        tester,
        size,
        _play(notes: const [
          (uuid: 'n1', name: 'Clue', content: 'A hidden lever behind the shelf.'),
        ]),
        (t) async {
          await t.tap(find.byKey(const ValueKey('play.note.tile.n1')));
          await t.pumpAndSettle();
        },
      );
      expect(ex, isNull, reason: 'note-content dialog overflowed at $label: $ex');
    });

    testWidgets('play NPC info dialog (plain) @ $label', (tester) async {
      final ex = await _probe(
        tester,
        size,
        _play(npcs: [_npc()]),
        (t) async {
          await t.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
          await t.pumpAndSettle();
        },
      );
      expect(ex, isNull, reason: 'NPC info dialog overflowed at $label: $ex');
    });

    testWidgets('play NPC info dialog (villain) @ $label', (tester) async {
      final ex = await _probe(
        tester,
        size,
        _play(npcs: [
          _npc(
              villain: const NpcVillainStats(
                  strength: 6, influence: 4, rank: 10, advantages: ['sorcery'])),
        ]),
        (t) async {
          await t.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
          await t.pumpAndSettle();
        },
      );
      expect(ex, isNull, reason: 'villain info dialog overflowed at $label: $ex');
    });
  }
}
