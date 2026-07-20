// The 7th Sea Villain "Schemes / Intrygi" section on the NPC details form:
// add via the New-scheme dialog (name + cost, cost
// spent from Influence), edit by tapping a tile, delete via the tile button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/screens/npc_7thsea_screen.dart';

const _uuid = '11111111-1111-1111-1111-111111111111';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: Scaffold(body: home),
);

NpcsController _controller({
  String kind = 'villain',
  int influence = 10,
  List<Map<String, dynamic>> schemes = const [],
}) {
  final c = NpcsController(newId: () => 'new-uuid')
    ..setTemplate(
      SevenSea.template,
      systemId: SevenSea.systemId,
      pruneHiddenStats: true,
    );
  c.loadFrom({
    'npcs': [
      {
        'name': 'The Count',
        'npc_uuid': _uuid,
        'full_image': 'full',
        'icon_image': 'icon',
        'stats': {
          ...SevenSea.template.defaults(),
          'kind': kind,
          'strength': 5,
          'influence': influence,
          'schemes': schemes,
        },
      },
    ],
  });
  c.beginEdit(_uuid);
  return c;
}

Future<void> _pump(
  WidgetTester tester,
  NpcsController c, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      Npc7thSeaScreen(
        key: ValueKey('sea-${locale.languageCode}'),
        controller: c,
        imagesBasePath: '/nowhere',
        onSave: () async => c.save(),
        onCancel: () {},
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openNew(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('npc.7thsea.scheme.new')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pump();
}

List<dynamic> _schemes(NpcsController c) =>
    (c.editStats['schemes'] as List?) ?? const [];

bool _addEnabled(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
    )
    .enabled;

void main() {
  group('section visibility', () {
    testWidgets('Villain shows the Schemes section; Monster/Brute do not', (
      tester,
    ) async {
      await _pump(tester, _controller(kind: 'villain'));
      expect(find.byKey(const ValueKey('npc.7thsea.schemes')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.new')),
        findsOneWidget,
      );

      await _pump(tester, _controller(kind: 'monster'));
      expect(find.byKey(const ValueKey('npc.7thsea.schemes')), findsNothing);

      await _pump(tester, _controller(kind: 'brute_squad'));
      expect(find.byKey(const ValueKey('npc.7thsea.schemes')), findsNothing);
    });
  });

  group('add a scheme', () {
    testWidgets('name + cost within budget adds a tile and persists the stat', (
      tester,
    ) async {
      final c = _controller(influence: 10);
      await _pump(tester, c);
      await _openNew(tester);

      // Add is disabled until name + valid cost are entered.
      expect(_addEnabled(tester), isFalse);
      await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'Poison the well');
      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '4');
      expect(_addEnabled(tester), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
      );
      await tester.pumpAndSettle();

      // A tile appeared; the stat holds a {type:scheme, name, cost}.
      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.tile.0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('npc.7thsea.scheme.tile.0.name')),
            )
            .data,
        'Poison the well',
      );
      final schemes = _schemes(c);
      expect(schemes, hasLength(1));
      expect(schemes.first, {
        'type': SevenSea.schemeTypeScheme,
        'name': 'Poison the well',
        'cost': 4,
      });
    });

    testWidgets('name is required — Add stays disabled with only a cost', (
      tester,
    ) async {
      await _pump(tester, _controller());
      await _openNew(tester);
      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '2');
      expect(_addEnabled(tester), isFalse);
    });

    testWidgets('cost input accepts digits only', (tester) async {
      await _pump(tester, _controller());
      await _openNew(tester);
      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', 'a1b2');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('npc.7thsea.scheme.dialog.cost')),
            )
            .controller!
            .text,
        '12',
      );
    });
  });

  group('cost is spent from influence', () {
    testWidgets('a cost greater than available influence cannot be added', (
      tester,
    ) async {
      // influence 3, no schemes yet -> available 3; cost 5 is too high.
      await _pump(tester, _controller(influence: 3));
      await _openNew(tester);
      await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'Grand plot');
      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '5');
      expect(_addEnabled(tester), isFalse); // over budget

      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '3');
      expect(_addEnabled(tester), isTrue); // exactly the budget is allowed
    });

    testWidgets('an existing scheme reduces the budget for the next', (
      tester,
    ) async {
      // influence 10, one scheme already costing 7 -> only 3 left.
      final c = _controller(
        influence: 10,
        schemes: [
          {'type': 'scheme', 'name': 'First', 'cost': 7},
        ],
      );
      await _pump(tester, c);
      await _openNew(tester);
      await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'Second');
      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '4');
      expect(_addEnabled(tester), isFalse); // 4 > remaining 3

      await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '3');
      expect(_addEnabled(tester), isTrue);
    });
  });

  group('edit and delete', () {
    testWidgets(
      'tapping a tile opens the edit dialog pre-filled; Save updates',
      (tester) async {
        final c = _controller(
          influence: 10,
          schemes: [
            {'type': 'scheme', 'name': 'Old name', 'cost': 2},
          ],
        );
        await _pump(tester, c);

        final tile = find.byKey(const ValueKey('npc.7thsea.scheme.tile.0'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        // Pre-filled with the current values.
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('npc.7thsea.scheme.dialog.name')),
              )
              .controller!
              .text,
          'Old name',
        );

        await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'New name');
        await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '6');
        await tester.tap(
          find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
        );
        await tester.pumpAndSettle();

        expect(_schemes(c).first, {
          'type': SevenSea.schemeTypeScheme,
          'name': 'New name',
          'cost': 6,
        });
      },
    );

    testWidgets('the delete button removes the scheme', (tester) async {
      final c = _controller(
        schemes: [
          {'type': 'scheme', 'name': 'Doomed', 'cost': 1},
        ],
      );
      await _pump(tester, c);
      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.tile.0')),
        findsOneWidget,
      );

      final del = find.byKey(const ValueKey('npc.7thsea.scheme.tile.0.delete'));
      await tester.ensureVisible(del);
      await tester.pumpAndSettle();
      await tester.tap(del);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.tile.0')),
        findsNothing,
      );
      expect(_schemes(c), isEmpty);
    });
  });

  group('isDirty guard on the dialog', () {
    testWidgets('cancelling with pending input prompts Save/Abandon/Cancel', (
      tester,
    ) async {
      final c = _controller();
      await _pump(tester, c);
      await _openNew(tester);
      await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'Half-typed');

      await tester.tap(
        find.byKey(const ValueKey('npc.7thsea.scheme.dialog.cancel')),
      );
      await tester.pumpAndSettle();
      // The unsaved-changes prompt appears.
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsOneWidget,
      );

      // Abandon -> nothing added, dialogs closed.
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.dialog')),
        findsNothing,
      );
      expect(_schemes(c), isEmpty);
    });

    testWidgets('cancelling a pristine dialog closes without a prompt', (
      tester,
    ) async {
      await _pump(tester, _controller());
      await _openNew(tester);
      await tester.tap(
        find.byKey(const ValueKey('npc.7thsea.scheme.dialog.cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('npc.7thsea.scheme.dialog')),
        findsNothing,
      );
    });
  });

  testWidgets('adding a scheme recalculates the Villainy Rank field live', (
    tester,
  ) async {
    // strength 5, influence 10 -> rank 15 before any scheme.
    final c = _controller(influence: 10);
    await _pump(tester, c);
    String rank() => tester
        .widget<Text>(
          find.byKey(const ValueKey('npc.7thsea.derived.villainy_rank')),
        )
        .data!;
    expect(rank(), '15');

    await _openNew(tester);
    await _enter(tester, 'npc.7thsea.scheme.dialog.name', 'Plot');
    await _enter(tester, 'npc.7thsea.scheme.dialog.cost', '4');
    await tester.tap(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
    );
    await tester.pumpAndSettle();

    // Rank recalculated from the available influence: 5 + (10 - 4) = 11.
    expect(rank(), '11');
  });

  testWidgets('Polish locale labels the section "Intrygi"', (tester) async {
    await _pump(tester, _controller(), locale: const Locale('pl'));
    expect(find.text('Intrygi'), findsWidgets);
    await _openNew(tester);
    expect(find.text('Nazwa intrygi'), findsOneWidget);
    expect(find.text('Koszt'), findsWidgets);
  });
}
