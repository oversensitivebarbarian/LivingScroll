// Smoke tests for the LivingScroll main navigation shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:living_scroll/main.dart';
import 'package:living_scroll/widgets/rail_state.dart';

void main() {
  // The rail's open/collapsed state is app-wide and shared; reset it to
  // collapsed before each case (these tests assume a collapsed start).
  setUp(() => RailState.extended.value = false);

  testWidgets('Collapsed rail renders content with labels hidden',
      (tester) async {
    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

    // Collapsed: icons only, no labels under them.
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.none);

    // Unselected destination icons are present (Home is the selected default).
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // The active (Home) destination renders the Home view (its sections; empty
    // here as there is no path provider).
    expect(find.byKey(const ValueKey('home.root')), findsOneWidget);

    // Switching destinations via the icon keeps the shell functional: Library is
    // now its own 4-tab view (not a placeholder).
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library.tabs')), findsOneWidget);
  });

  testWidgets('Menu button toggles the rail expand/collapse', (tester) async {
    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();

    NavigationRail rail() =>
        tester.widget<NavigationRail>(find.byType(NavigationRail));

    // Starts collapsed.
    expect(rail().extended, isFalse);

    // Tapping the Side Navigation toggle expands it (destination labels show).
    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();
    expect(rail().extended, isTrue);

    // Tapping again collapses it back to icons only.
    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();
    expect(rail().extended, isFalse);
  });

  testWidgets('Settings is a selectable rail destination', (tester) async {
    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();

    NavigationRail rail() =>
        tester.widget<NavigationRail>(find.byType(NavigationRail));

    // Settings is now a real destination (4 total), not a separate button.
    expect(rail().destinations.length, 4);
    expect(rail().selectedIndex, 0);

    // Tapping it selects it through the rail.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 3);
  });
}
