import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/widgets/rail_menu_button.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  // RailMenuButton must live inside a NavigationRail (it reads the rail's
  // extended animation), so each case pumps it in the rail's leading slot.
  Widget host({required bool extended}) => MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: extended,
                leading: RailMenuButton(tooltip: 'Menu', onTap: () {}),
                selectedIndex: 0,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );

  testWidgets('uses the Side Navigation icon, never the old menu icon',
      (tester) async {
    await tester.pumpWidget(host(extended: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.side_navigation), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('shows NO visible label, even when the rail is expanded',
      (tester) async {
    await tester.pumpWidget(host(extended: true));
    await tester.pumpAndSettle();
    // The icon is present...
    expect(find.byIcon(Symbols.side_navigation), findsOneWidget);
    // ...but the "Menu" text is not rendered (it is only a tooltip now).
    expect(find.text('Menu'), findsNothing);
  });

  testWidgets('tapping toggles via onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: false,
              leading: RailMenuButton(tooltip: 'Menu', onTap: () => taps++),
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.home), label: Text('Home')),
                NavigationRailDestination(
                    icon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.side_navigation));
    expect(taps, 1);
  });
}
