import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/screens/npc_7thsea_screen.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: home),
    );

const _uuid = '11111111-1111-1111-1111-111111111111';

NpcsController _base() {
  final c = NpcsController(newId: () => 'new-uuid');
  c.setTemplate(SevenSea.template,
      systemId: SevenSea.systemId, pruneHiddenStats: true);
  return c;
}

/// A controller adding a NEW NPC (starts on the kind page).
NpcsController _controllerNew() {
  final c = _base()..loadFrom({'npcs': []});
  c.beginNew();
  return c;
}

/// A controller EDITING an existing NPC with the given stats (opens on details).
NpcsController _controllerEdit(Map<String, dynamic> stats) {
  final c = _base();
  c.loadFrom({
    'npcs': [
      {
        'name': 'The Count',
        'npc_uuid': _uuid,
        'full_image': 'full',
        'icon_image': 'icon',
        'stats': {...SevenSea.template.defaults(), ...stats},
      }
    ],
  });
  c.beginEdit(_uuid);
  return c;
}

Future<void> _pump(WidgetTester tester, NpcsController c,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(_app(
      Npc7thSeaScreen(
        // A per-locale key forces a fresh State when a test pumps twice (Flutter
        // reuses the State of an unkeyed same-type widget across pumpWidget).
        key: ValueKey('npc7s-${locale.languageCode}'),
        controller: c,
        imagesBasePath: '/nowhere',
        onSave: () async => c.save(),
        onCancel: () {},
      ),
      locale: locale));
  await tester.pumpAndSettle();
}

String _step(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('npc.7thsea.step.indicator')))
    .data!;

Future<void> _pickKind(WidgetTester tester, String kind) async {
  await tester.tap(find.byKey(ValueKey('npc.7thsea.kind.$kind')));
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('npc.7thsea.next')));
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.byKey(ValueKey('npc.7thsea.field.$key'));

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('new NPC — the two-step flow', () {
    testWidgets('opens on the kind page (1/2) with three radio options',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerNew());
      expect(_step(tester), '1/2');
      for (final k in SevenSea.kinds) {
        expect(find.byKey(ValueKey('npc.7thsea.kind.$k')), findsOneWidget);
      }
      expect(_field('strength'), findsNothing); // no stats on the kind page
    });

    testWidgets('Monster: details page has only the common fields — no stats',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerNew());
      await _pickKind(tester, 'monster');
      await _next(tester);
      expect(_step(tester), '2/2');
      expect(find.byKey(const ValueKey('npc.7thsea.name')), findsOneWidget);
      expect(find.byKey(const ValueKey('npc.7thsea.description')), findsOneWidget);
      expect(_field('strength'), findsNothing);
      expect(_field('influence'), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.derived.villainy_rank')),
          findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.advantage.sorcery')),
          findsNothing);
    });

    testWidgets('Brute squad: shows Strength, hides Influence/Rank/Advantages',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerNew());
      await _pickKind(tester, 'brute_squad');
      await _next(tester);
      expect(_field('strength'), findsOneWidget);
      expect(_field('influence'), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.derived.villainy_rank')),
          findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.advantage.sorcery')),
          findsNothing);
    });

    testWidgets('Villain: shows Strength, Influence, Advantages; Rank computes',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerNew());
      await _next(tester); // villain is the default kind
      expect(_field('strength'), findsOneWidget);
      expect(_field('influence'), findsOneWidget);
      expect(find.byKey(const ValueKey('npc.7thsea.advantage.sorcery')),
          findsOneWidget);

      await tester.enterText(_field('strength'), '5');
      await tester.pump();
      await tester.enterText(_field('influence'), '3');
      await tester.pump();
      final rank = tester
          .widget<Text>(
              find.byKey(const ValueKey('npc.7thsea.derived.villainy_rank')))
          .data!;
      expect(rank, '8'); // 5 + 3
    });

    testWidgets('numeric stat is digits-only and capped at 3 digits',
        (tester) async {
      big(tester);
      final c = _controllerNew();
      await _pump(tester, c);
      await _next(tester); // villain -> details
      final str = _field('strength');
      String text() => tester.widget<TextField>(str).controller!.text;

      await tester.enterText(str, 'ab12'); // letters stripped
      await tester.pump();
      expect(text(), '12');
      expect(c.editStats['strength'], 12);

      await tester.enterText(str, '9999'); // 4th digit rejected
      await tester.pump();
      expect(text(), '999');
      expect(c.editStats['strength'], 999);
    });

    testWidgets('nav buttons are grouped together (not split to the edges)',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerNew());
      // Kind page: Cancel + Next. They must sit side by side (a small gap),
      // never Cancel far-left and Next far-right.
      final cancel =
          tester.getRect(find.byKey(const ValueKey('npc.7thsea.cancel')));
      final next = tester.getRect(find.byKey(const ValueKey('npc.7thsea.next')));
      expect(cancel.right, lessThan(next.left)); // Cancel precedes Next
      expect(next.left - cancel.right, lessThan(40)); // adjacent, not spread apart
    });

    testWidgets('toggling an advantage updates the stored list', (tester) async {
      big(tester);
      final c = _controllerNew();
      await _pump(tester, c);
      await _next(tester); // villain
      final sorcery = find.byKey(const ValueKey('npc.7thsea.advantage.sorcery'));
      await tester.ensureVisible(sorcery);
      await tester.tap(sorcery);
      await tester.pump();
      expect(c.editStats['advantages'], contains('sorcery'));
      await tester.ensureVisible(sorcery);
      await tester.tap(sorcery);
      await tester.pump();
      expect(c.editStats['advantages'], isEmpty);
    });
  });

  group('existing NPC — details only, kind immutable', () {
    testWidgets('editing opens the details page directly (no kind page)',
        (tester) async {
      big(tester);
      await _pump(tester,
          _controllerEdit({'kind': 'villain', 'strength': 5, 'influence': 3}));

      // A single step — details — shown immediately.
      expect(_step(tester), '1/1');
      expect(find.byKey(const ValueKey('npc.7thsea.name')), findsOneWidget);
      expect(find.byKey(const ValueKey('npc.7thsea.description')), findsOneWidget);
      // The kind can NEVER be changed: no kind radios, no Next/Back.
      for (final k in SevenSea.kinds) {
        expect(find.byKey(ValueKey('npc.7thsea.kind.$k')), findsNothing);
      }
      expect(find.byKey(const ValueKey('npc.7thsea.next')), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.back')), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.save')), findsOneWidget);
      // The Villain's own stats are there from the start.
      expect(_field('strength'), findsOneWidget);
      expect(_field('influence'), findsOneWidget);
      expect(find.byKey(const ValueKey('npc.7thsea.derived.villainy_rank')),
          findsOneWidget);
    });

    testWidgets('editing a Monster opens details with no stat fields',
        (tester) async {
      big(tester);
      await _pump(tester, _controllerEdit({'kind': 'monster'}));
      expect(_step(tester), '1/1');
      expect(find.byKey(const ValueKey('npc.7thsea.name')), findsOneWidget);
      expect(_field('strength'), findsNothing);
      expect(_field('influence'), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.advantage.sorcery')),
          findsNothing);
      // Still no way to change the kind.
      for (final k in SevenSea.kinds) {
        expect(find.byKey(ValueKey('npc.7thsea.kind.$k')), findsNothing);
      }
    });

    testWidgets('editing a Brute squad shows Strength only', (tester) async {
      big(tester);
      await _pump(tester, _controllerEdit({'kind': 'brute_squad', 'strength': 7}));
      expect(_step(tester), '1/1');
      expect(_field('strength'), findsOneWidget);
      expect(_field('influence'), findsNothing);
      expect(find.byKey(const ValueKey('npc.7thsea.advantage.sorcery')),
          findsNothing);
    });
  });

  group('advantages column layout (new Villain)', () {
    // How many advantage tiles sit in the FIRST row (share the smallest dy).
    int firstRowColumns(WidgetTester tester) {
      final dys = <double>[];
      for (final a in kAdvantages) {
        final f = find.byKey(ValueKey('npc.7thsea.advantage.${a.key}'));
        if (f.evaluate().isEmpty) continue;
        dys.add(tester.getTopLeft(f).dy);
      }
      final minDy = dys.reduce(math.min);
      return dys.where((d) => (d - minDy).abs() < 0.5).length;
    }

    Future<void> pumpVillainAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = _controllerNew();
      // A unique key forces a FRESH State each call.
      await tester.pumpWidget(_app(Npc7thSeaScreen(
        key: ValueKey('npc7s-${size.width}'),
        controller: c,
        imagesBasePath: '/nowhere',
        onSave: () async => c.save(),
        onCancel: () {},
      )));
      await tester.pumpAndSettle();
      await _next(tester); // villain -> details
    }

    testWidgets('advantages lay out in multiple columns on a wide form',
        (tester) async {
      await pumpVillainAt(tester, const Size(1600, 2200));
      final a0 = find.byKey(const ValueKey('npc.7thsea.advantage.able_drunker'));
      final a1 =
          find.byKey(const ValueKey('npc.7thsea.advantage.cast_iron_stomach'));
      expect(tester.getTopLeft(a0).dy, tester.getTopLeft(a1).dy);
      expect(tester.getTopLeft(a0).dx, isNot(tester.getTopLeft(a1).dx));
      expect(firstRowColumns(tester), greaterThan(1));
    });

    testWidgets('column count adapts to the form width', (tester) async {
      await pumpVillainAt(tester, const Size(1600, 2200));
      final wide = firstRowColumns(tester);
      await pumpVillainAt(tester, const Size(820, 2200));
      final narrow = firstRowColumns(tester);
      expect(wide, greaterThan(narrow));
      expect(narrow, greaterThanOrEqualTo(1));
    });

    testWidgets('advantage names never wrap (single, non-wrapping line)',
        (tester) async {
      await pumpVillainAt(tester, const Size(1600, 2200));
      final title = tester.widget<Text>(find.descendant(
        of: find.byKey(
            const ValueKey('npc.7thsea.advantage.an_honest_misunderstanding')),
        matching: find.byType(Text),
      ));
      expect(title.softWrap, isFalse);
      expect(find.text('An honest misunderstanding'), findsOneWidget);
    });
  });

  testWidgets('advantage labels: English by default, Polish under pl locale',
      (tester) async {
    big(tester);
    await _pump(tester, _controllerNew());
    await _next(tester);
    expect(find.text('Sorcery'), findsOneWidget);

    await _pump(tester, _controllerNew(), locale: const Locale('pl'));
    await _next(tester);
    expect(find.text('Magia'), findsOneWidget);
  });

  testWidgets('image row does not overflow at a narrow window (Finding 4)',
      (tester) async {
    // The fixed-size image row (~464px natural) is wrapped in a
    // FittedBox(scaleDown), so a narrow window scales it instead of overflowing
    // horizontally. Uses the Monster kind (no advantages) at a width where the
    // form area (~352px) is narrower than the image row but still fits the nav
    // row — isolating the image-row fix from the other narrow-width concerns.
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, _controllerNew());
    await _pickKind(tester, 'monster');
    await _next(tester); // monster -> details (image row + name + description)
    expect(find.byKey(const ValueKey('npc.7thsea.full_image')), findsOneWidget);
    expect(_field('strength'), findsNothing); // no stats -> no advantages
    expect(tester.takeException(), isNull);
  });
}
