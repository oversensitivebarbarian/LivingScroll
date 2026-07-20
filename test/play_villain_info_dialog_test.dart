// The Play view's NPC info dialog for a 7th Sea 2nd Edition VILLAIN:
// below the height-filling description it shows the
// SAME Strength / Influence / Rank blocks as the villain's tile, then the
// selected Advantages laid out in two columns (localized PL vs EN).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';
import 'package:living_scroll/widgets/npc_tile.dart' show NpcVillainStats;

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

PlayNpc _villain(NpcVillainStats stats) => (
  uuid: 'v1',
  name: 'The Count',
  iconImage: null,
  fullImage: null,
  description: 'A dangerous foe.',
  backstory: 'Once a hero.',
  state: 'active',
  stats: const <({String label, String value})>[],
  villain: stats,
  sevenSeaStats: const {},
);

Widget _play(NpcVillainStats stats, {Locale locale = const Locale('en')}) =>
    _app(
      PlayScreen(
        scene: _scene(),
        mode: PlayMode.gameplay,
        keyEvents: const [],
        nextScenes: const [],
        npcs: [_villain(stats)],
        notes: const [],
        images: const [],
        onExit: () {},
      ),
      locale: locale,
    );

Future<void> _openInfo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('play.npc.tile.v1')));
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('villain info shows the same three stat blocks as the tile', (
    tester,
  ) async {
    await _resize(tester, const Size(1600, 1200));
    await tester.pumpWidget(
      _play(
        const NpcVillainStats(
          strength: 5,
          influence: 3,
          rank: 8,
          advantages: ['sorcery'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openInfo(tester);

    // The badge bar sits under the description, keyed like the tile's badges but
    // scoped to the info dialog. All three blocks are present with their values.
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.villain')),
      findsOneWidget,
    );
    for (final id in ['strength', 'influence', 'rank']) {
      expect(
        find.byKey(ValueKey('play.npc.info.v1.villain.$id')),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('play.npc.info.v1.villain.strength.value'),
            ),
          )
          .data,
      '5',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('play.npc.info.v1.villain.influence.value'),
            ),
          )
          .data,
      '3',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('play.npc.info.v1.villain.rank.value')),
          )
          .data,
      '8',
    );
  });

  testWidgets('selected advantages are displayed (English labels)', (
    tester,
  ) async {
    await _resize(tester, const Size(1600, 1200));
    await tester.pumpWidget(
      _play(
        const NpcVillainStats(
          strength: 6,
          influence: 2,
          rank: 8,
          advantages: ['sorcery', 'able_drunker'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openInfo(tester);

    // The advantages block lists exactly the selected advantages, by label.
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.advantages')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.advantage.sorcery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.advantage.able_drunker')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('play.npc.info.v1.advantage.sorcery')),
          )
          .data,
      'Sorcery',
    );
    // An unselected advantage is not shown.
    expect(
      find.byKey(
        const ValueKey('play.npc.info.v1.advantage.cast_iron_stomach'),
      ),
      findsNothing,
    );
  });

  testWidgets('advantages lay out in two columns', (tester) async {
    await _resize(tester, const Size(1600, 1200));
    await tester.pumpWidget(
      _play(
        const NpcVillainStats(
          strength: 6,
          influence: 2,
          rank: 8,
          advantages: ['sorcery', 'able_drunker'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openInfo(tester);

    // Two advantages -> one per column: same row (equal dy), different columns
    // (different dx).
    final a0 = find.byKey(const ValueKey('play.npc.info.v1.advantage.sorcery'));
    final a1 = find.byKey(
      const ValueKey('play.npc.info.v1.advantage.able_drunker'),
    );
    expect(tester.getTopLeft(a0).dy, closeTo(tester.getTopLeft(a1).dy, 0.5));
    expect(tester.getTopLeft(a0).dx, isNot(tester.getTopLeft(a1).dx));
  });

  testWidgets('advantage labels are Polish under the pl locale', (
    tester,
  ) async {
    await _resize(tester, const Size(1600, 1200));
    await tester.pumpWidget(
      _play(
        const NpcVillainStats(
          strength: 5,
          influence: 3,
          rank: 8,
          advantages: ['sorcery'],
        ),
        locale: const Locale('pl'),
      ),
    );
    await tester.pumpAndSettle();
    await _openInfo(tester);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('play.npc.info.v1.advantage.sorcery')),
          )
          .data,
      'Magia',
    );
  });

  testWidgets(
    'the bar sits in the right column and the image fills full height',
    (tester) async {
      await _resize(tester, const Size(1600, 1200));
      await tester.pumpWidget(
        _play(
          const NpcVillainStats(
            strength: 5,
            influence: 3,
            rank: 8,
            advantages: ['sorcery', 'able_drunker'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openInfo(tester);

      final frame = tester.getSize(
        find.byKey(const ValueKey('play.npc.info.v1.frame')),
      );
      final image = tester.getRect(
        find.byKey(const ValueKey('play.npc.info.v1.image')),
      );
      final bar = tester.getRect(
        find.byKey(const ValueKey('play.npc.info.v1.villain')),
      );
      final adv = tester.getRect(
        find.byKey(const ValueKey('play.npc.info.v1.advantages')),
      );

      // The full image spans the WHOLE dialog height (the bar no longer steals a
      // full-width strip below it).
      expect(image.height, closeTo(frame.height, 0.5));
      // The stat bar and advantages live in the RIGHT column — entirely to the
      // right of the image, never joining both columns.
      expect(bar.left, greaterThanOrEqualTo(image.right));
      expect(adv.left, greaterThanOrEqualTo(image.right));
    },
  );

  testWidgets(
    'a villain with no advantages shows the bar but no advantages block',
    (tester) async {
      await _resize(tester, const Size(1600, 1200));
      await tester.pumpWidget(
        _play(const NpcVillainStats(strength: 4, influence: 1, rank: 5)),
      );
      await tester.pumpAndSettle();
      await _openInfo(tester);

      expect(
        find.byKey(const ValueKey('play.npc.info.v1.villain')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('play.npc.info.v1.advantages')),
        findsNothing,
      );
    },
  );

  testWidgets('a Brute info dialog shows the Strength bar, no advantages block', (
    tester,
  ) async {
    await _resize(tester, const Size(1600, 1200));
    await tester.pumpWidget(
      _play(
        const NpcVillainStats(
          kind: 'brute_squad',
          strength: 7,
          influence: 0,
          rank: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openInfo(tester);

    // The bar under the description holds ONLY the Strength block (centered), no
    // Influence / Rank, and there is no advantages block.
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.villain')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.villain.strength')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.villain.influence')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.villain.rank')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('play.npc.info.v1.advantages')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('play.npc.info.v1.villain.strength.value'),
            ),
          )
          .data,
      '7',
    );

    // The full image still fills the whole dialog height.
    final frame = tester.getSize(
      find.byKey(const ValueKey('play.npc.info.v1.frame')),
    );
    final image = tester.getSize(
      find.byKey(const ValueKey('play.npc.info.v1.image')),
    );
    expect(image.height, closeTo(frame.height, 0.5));
  });
}
