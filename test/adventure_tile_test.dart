import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_tile.dart';

Widget _host(AdventureTile tile) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: tile)),
    );

void main() {
  testWidgets('VALID tile: openable, has the context menu, no Block glyph',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(AdventureTile(
      adventure: const AdventureSummary(slug: 'Good', name: 'Good'),
      onOpen: () => opened++,
      onClone: () {},
      onDelete: () {},
    )));

    expect(find.byKey(const ValueKey('adventure.tile.Good')), findsOneWidget);
    expect(find.byKey(const ValueKey('adventure.tile.menu.Good')), findsOneWidget);
    expect(find.byKey(const ValueKey('adventure.tile.Good.block')), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);

    await tester.tap(find.byKey(const ValueKey('adventure.tile.Good')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets(
      'INVALID tile: greyed Block, not openable, no menu, but deletable',
      (tester) async {
    var opened = 0;
    var deleted = 0;
    await tester.pumpWidget(_host(AdventureTile(
      adventure: const AdventureSummary(slug: 'Legacy', name: 'Legacy', valid: false),
      onOpen: () => opened++,
      onClone: () {},
      onDelete: () => deleted++,
    )));

    // The tile is still findable but carries the Block indicator instead.
    expect(find.byKey(const ValueKey('adventure.tile.Legacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('adventure.tile.Legacy.block')), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);

    // No context menu in the invalid state.
    expect(find.byKey(const ValueKey('adventure.tile.menu.Legacy')), findsNothing);

    // The Block circle reuses the context-menu colour pair.
    final scheme = ThemeData().colorScheme;
    final circle = tester.widget<Container>(
        find.byKey(const ValueKey('adventure.tile.Legacy.block')));
    expect((circle.decoration as BoxDecoration).color, scheme.secondaryContainer);
    expect(tester.widget<Icon>(find.byIcon(Icons.block)).color,
        scheme.onSecondaryContainer);

    // Tapping the invalid tile does nothing (no open).
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Legacy')));
    await tester.pumpAndSettle();
    expect(opened, 0);

    // The delete button uses the standard tile delete treatment: an
    // onSecondaryContainer circle behind a secondaryContainer Close glyph.
    final delete = find.byKey(const ValueKey('adventure.tile.Legacy.delete'));
    expect(delete, findsOneWidget);
    final deleteBackdrop = tester.widget<Container>(find.ancestor(
        of: delete, matching: find.byType(Container)));
    expect((deleteBackdrop.decoration as BoxDecoration).color,
        scheme.onSecondaryContainer);
    expect(tester.widget<Icon>(find.byIcon(Icons.close)).color,
        scheme.secondaryContainer);

    // Tapping delete invokes the cascade callback (the dialog lives on the grid).
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('INVALID tile keeps the adventure cover as its background',
      (tester) async {
    final cover = File('${Directory.current.path}/Test_Assets/cover_sample.jpg');
    await tester.pumpWidget(_host(AdventureTile(
      adventure: AdventureSummary(
          slug: 'Legacy', name: 'Legacy', cover: cover, valid: false),
      onOpen: () {},
      onClone: () {},
      onDelete: () {},
    )));

    // Still the invalid state (Block + delete present) but the cover shows.
    expect(find.byKey(const ValueKey('adventure.tile.Legacy.block')), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('adventure.tile.Legacy')),
          matching: find.byType(Image),
        ),
        findsOneWidget);
  });
}
