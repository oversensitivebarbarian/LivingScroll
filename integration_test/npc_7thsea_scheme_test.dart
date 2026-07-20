// PATH: in a 7th Sea 2e adventure, on a Villain NPC's details form, the Schemes /
// Intrygi section — add a scheme via the New-scheme dialog (name + cost, cost
// spent from Influence), edit it by tapping its tile, delete it via the tile
// button; Save persists npcs[].stats.schemes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory demoDir(CreateHarness h) => Directory('${h.projectsDir.path}/Demo');

  void bigWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> seedDemo(
    CreateHarness h, {
    List<Map<String, dynamic>> npcs = const [],
  }) async {
    final dir = demoDir(h);
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {
          'name': 'Demo',
          'system': '7thsea2e',
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
        'npcs': npcs,
        'scenes': [],
      }),
    );
  }

  Map<String, dynamic> readNpc(CreateHarness h) =>
      (jsonDecode(
                    File(
                      '${demoDir(h).path}/LivingScroll.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['npcs']
              .first
          as Map<String, dynamic>;

  List<dynamic> readSchemes(CreateHarness h) =>
      (readNpc(h)['stats'] as Map)['schemes'] as List;

  Future<void> openNpcGrid(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
    await tester.pumpAndSettle();
  }

  Future<void> pickImages(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('npc.7thsea.full_image')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('npc_7thsea.full_image.crop.confirm')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('npc_7thsea.icon_image.crop.confirm')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Key key) async {
    final f = find.byKey(key);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pump();
  }

  Map<String, dynamic> villainWithScheme() => {
    'name': 'The Count',
    'npc_uuid': 'v1',
    'full_image': 'full',
    'icon_image': 'icon',
    'stats': {
      'kind': 'villain',
      'strength': 5,
      'influence': 8,
      'advantages': <String>[],
      'schemes': [
        {'type': 'scheme', 'name': 'Plot', 'cost': 3},
      ],
    },
  };

  testWidgets('npc_7thsea_scheme: add a scheme writes it to stats.schemes', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness);
    harness.coverPath = CreateHarness.asset('cover_sample.jpg');

    await harness.pumpApp(tester);
    await openNpcGrid(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.add')));
    await tester.pumpAndSettle();

    // Villain is the default kind -> Next to the details page.
    await tester.tap(find.byKey(const ValueKey('npc.7thsea.next')));
    await tester.pumpAndSettle();

    await enter(tester, 'npc.7thsea.name', 'The Count');
    await pickImages(tester);
    await enter(tester, 'npc.7thsea.field.influence', '8');

    // Add a scheme via the New-scheme dialog.
    await tapVisible(tester, const ValueKey('npc.7thsea.scheme.new'));
    await enter(tester, 'npc.7thsea.scheme.dialog.name', 'Poison the well');
    await enter(tester, 'npc.7thsea.scheme.dialog.cost', '3');
    await tester.tap(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('npc.7thsea.scheme.tile.0')),
      findsOneWidget,
    );

    await tapVisible(tester, const ValueKey('npc.7thsea.save'));

    expect(readSchemes(harness), [
      {'type': 'scheme', 'name': 'Poison the well', 'cost': 3},
    ]);
  });

  testWidgets('npc_7thsea_scheme: editing a scheme tile updates the cost', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness, npcs: [villainWithScheme()]);

    await harness.pumpApp(tester);
    await openNpcGrid(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.tile.v1')));
    await tester.pumpAndSettle();

    await tapVisible(tester, const ValueKey('npc.7thsea.scheme.tile.0'));
    await enter(tester, 'npc.7thsea.scheme.dialog.name', 'Bigger plot');
    await enter(tester, 'npc.7thsea.scheme.dialog.cost', '5');
    await tester.tap(
      find.byKey(const ValueKey('npc.7thsea.scheme.dialog.add')),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, const ValueKey('npc.7thsea.save'));

    expect(readSchemes(harness), [
      {'type': 'scheme', 'name': 'Bigger plot', 'cost': 5},
    ]);
  });

  testWidgets('npc_7thsea_scheme: deleting a scheme tile removes it', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    bigWindow(tester);
    await seedDemo(harness, npcs: [villainWithScheme()]);

    await harness.pumpApp(tester);
    await openNpcGrid(tester);
    await tester.tap(find.byKey(const ValueKey('game.npc.tile.v1')));
    await tester.pumpAndSettle();

    await tapVisible(tester, const ValueKey('npc.7thsea.scheme.tile.0.delete'));
    expect(
      find.byKey(const ValueKey('npc.7thsea.scheme.tile.0')),
      findsNothing,
    );

    await tapVisible(tester, const ValueKey('npc.7thsea.save'));

    expect(readSchemes(harness), isEmpty);
  });
}
