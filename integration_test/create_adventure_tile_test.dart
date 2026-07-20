// PATH: the Create grid validates each adventure's LivingScroll.json. A VALID
// adventure's tile opens the game; an INVALID one (unsupported system, or a
// schema-broken document) renders greyed with a Block glyph and is not openable.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedAdventure(
    CreateHarness harness,
    String slug, {
    String? name,
    String system = 'basic',
    bool cover = false,
    // When true, only title + system are filled (the other metadata empty) —
    // exactly what the new-adventure form writes for a minimal project.
    bool minimalMetadata = false,
  }) async {
    final dir = Directory('${harness.projectsDir.path}/$slug');
    await dir.create(recursive: true);
    if (cover) {
      await File(
        CreateHarness.asset('cover_sample.jpg'),
      ).copy('${dir.path}/cover.jpg');
    }
    final metadata = <String, dynamic>{
      'name': ?name,
      'system': system,
      'version': minimalMetadata ? '' : '1.0.0',
      'author': minimalMetadata ? '' : 'A',
      'description': minimalMetadata ? '' : 'd',
      'language': minimalMetadata ? '' : 'en',
      'content_warnings': minimalMetadata ? '' : 'none',
      'license': minimalMetadata ? '' : 'x',
    };
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': metadata,
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
  }

  Future<void> openCreate(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create.grid')), findsOne);
  }

  testWidgets('valid tile opens; unsupported-system tile is a Block, inert', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedAdventure(harness, 'Good', name: 'Good', system: 'basic');
    await seedAdventure(
      harness,
      'Legacy',
      name: 'Legacy',
      system: 'generic',
      cover: true,
    );

    await harness.pumpApp(tester);
    await openCreate(tester);

    // Both tiles exist; only the legacy one carries the Block indicator.
    expect(find.byKey(const ValueKey('adventure.tile.Good')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.Legacy')), findsOne);
    expect(find.byKey(const ValueKey('adventure.tile.Legacy.block')), findsOne);
    expect(
      find.byKey(const ValueKey('adventure.tile.Good.block')),
      findsNothing,
    );

    // The INVALID tile keeps the adventure cover as its background.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('adventure.tile.Legacy')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    // Tapping the INVALID tile never opens the adventure.
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Legacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsNothing);
    expect(find.byKey(const ValueKey('create.grid')), findsOne);

    // The VALID tile opens the game shell.
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Good')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  });

  testWidgets('BRANCH minimal_project_valid: title + system only is openable', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    // A freshly created project: only title + system, the rest empty.
    await seedAdventure(
      harness,
      'Fresh',
      name: 'Fresh',
      system: 'basic',
      minimalMetadata: true,
    );

    await harness.pumpApp(tester);
    await openCreate(tester);

    // No Block — a minimal project is valid.
    expect(find.byKey(const ValueKey('adventure.tile.Fresh')), findsOne);
    expect(
      find.byKey(const ValueKey('adventure.tile.Fresh.block')),
      findsNothing,
    );

    // And it opens like any valid adventure.
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Fresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  });

  testWidgets(
    'BRANCH delete_invalid: an invalid adventure can still be deleted',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedAdventure(harness, 'Legacy', name: 'Legacy', system: 'generic');

      await harness.pumpApp(tester);
      await openCreate(tester);
      expect(
        find.byKey(const ValueKey('adventure.tile.Legacy.block')),
        findsOne,
      );

      // The standard tile delete button opens the shared confirm dialog.
      await tester.tap(
        find.byKey(const ValueKey('adventure.tile.Legacy.delete')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create.delete.dialog')), findsOne);

      await tester.tap(find.byKey(const ValueKey('create.delete.confirm')));
      await tester.pumpAndSettle();

      // The adventure is gone from the grid and from disk.
      expect(find.byKey(const ValueKey('adventure.tile.Legacy')), findsNothing);
      expect(
        Directory('${harness.projectsDir.path}/Legacy').existsSync(),
        isFalse,
      );
    },
  );

  testWidgets('BRANCH schema_broken: a schema-broken document is a Block too', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    // Missing required metadata.name -> schema-invalid even though the system is
    // supported.
    await seedAdventure(harness, 'Broken', name: null, system: 'basic');

    await harness.pumpApp(tester);
    await openCreate(tester);

    expect(find.byKey(const ValueKey('adventure.tile.Broken.block')), findsOne);

    await tester.tap(find.byKey(const ValueKey('adventure.tile.Broken')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsNothing);
  });
}
