import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_tile.dart';

/// Widget coverage for the "Export to LaTeX" context-menu item on a Library
/// Adventures tile.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Center(child: SizedBox(width: 220, height: 315, child: child)),
    ),
  );

  testWidgets(
    'the Adventures tile menu has Export to LaTeX between Copy and Delete',
    (tester) async {
      var exported = false;
      await tester.pumpWidget(
        wrap(
          AdventureTile(
            adventure: const AdventureSummary(slug: 'Pack', name: 'Pack'),
            onOpen: () {},
            onClone: () {},
            cloneLabel: 'Copy as project',
            onExportLatex: () => exported = true,
            exportLatexLabel: 'Export to LaTeX',
            onDelete: () {},
          ),
        ),
      );

      // Open the tile's context menu.
      await tester.tap(find.byKey(const ValueKey('adventure.tile.menu.Pack')));
      await tester.pumpAndSettle();

      // All three items present.
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.Pack.item.clone')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.Pack.item.latex')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('adventure.tile.menu.Pack.item.delete')),
        findsOneWidget,
      );

      // Export to LaTeX sits between Copy as project and Delete.
      final cloneY = tester
          .getCenter(
            find.byKey(const ValueKey('adventure.tile.menu.Pack.item.clone')),
          )
          .dy;
      final latexY = tester
          .getCenter(
            find.byKey(const ValueKey('adventure.tile.menu.Pack.item.latex')),
          )
          .dy;
      final deleteY = tester
          .getCenter(
            find.byKey(const ValueKey('adventure.tile.menu.Pack.item.delete')),
          )
          .dy;
      expect(cloneY, lessThan(latexY));
      expect(latexY, lessThan(deleteY));

      // Tapping it fires the callback.
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.menu.Pack.item.latex')),
      );
      await tester.pumpAndSettle();
      expect(exported, isTrue);
    },
  );

  testWidgets('a browse-only tile (no callbacks) shows no menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AdventureTile(
          adventure: const AdventureSummary(slug: 'Pack', name: 'Pack'),
          onOpen: () {},
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('adventure.tile.menu.Pack')),
      findsNothing,
    );
  });
}
