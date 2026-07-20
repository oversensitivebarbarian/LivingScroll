// Integration test: from the in-game view, the Home destination navigates to
// the app's Home view (not the previous screen).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('game Home navigates to the Home view', (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // Seed one adventure so the Create grid has a tile to open.
    final dir = Directory('${harness.projectsDir.path}/demo');
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(jsonEncode({
      'metadata': {
        'name': 'Demo',
        'system': 'basic',
        'version': '1.0.0',
        'author': 'A',
        'description': 'd',
        'language': 'en',
        'content_warnings': 'none',
        'license': 'x',
      },
      'images': [],
      'audio': [],
      'paths': [],
      'key_events': [],
      'notes': [],
      'gm_notes': [],
      'npcs': [],
      'scenes': [],
    }));

    await harness.pumpApp(tester);

    // Open the Create grid, then the seeded adventure -> game.
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);

    // Home in the game rail -> leave the game and land on the Home view.
    await tester.tap(find.byKey(const ValueKey('nav.game.home')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game.root')), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 0); // Home destination selected
  });
}
