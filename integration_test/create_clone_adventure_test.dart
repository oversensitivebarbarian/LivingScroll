// PATH: the Adventure tile's context menu Clone copies the whole project into a
// NEW unique directory under {Projects} and renames the copy (metadata.name =
// original + " cloned", disambiguated). The original is untouched; a new tile
// appears. The test verifies a NEW unique directory is actually created.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedDemo(CreateHarness harness) async {
    final dir = Directory('${harness.projectsDir.path}/Demo');
    await dir.create(recursive: true);
    await File(
      CreateHarness.asset('cover_sample.jpg'),
    ).copy('${dir.path}/cover.jpg');
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
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
        'notes': [
          {'note_uuid': 'nt1', 'note_name': 'Lore', 'note_content': 'x'},
        ],
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

  Future<void> cloneDemo(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('adventure.tile.menu.Demo')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('adventure.tile.menu.Demo.item.clone')),
    );
    await tester.pumpAndSettle();
  }

  String slugOf(Directory d) =>
      d.uri.pathSegments.where((s) => s.isNotEmpty).last;

  testWidgets('clone copies the project into a NEW unique directory, renamed', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openCreate(tester);
    expect(find.byKey(const ValueKey('adventure.tile.Demo')), findsOne);

    await cloneDemo(tester);

    // Exactly one NEW directory was created, distinct from the original.
    final dirs = harness.projects();
    expect(dirs.length, 2);
    final clone = dirs.firstWhere((d) => slugOf(d) != 'Demo');
    final cloneSlug = slugOf(clone);
    expect(cloneSlug, isNot('Demo'));
    expect(Directory(clone.path).existsSync(), isTrue);

    // The clone is renamed; every other field is copied verbatim.
    final cloneDoc = harness.readDocument(clone);
    expect((cloneDoc['metadata'] as Map)['name'], 'Demo cloned');
    expect((cloneDoc['metadata'] as Map)['system'], 'basic');
    expect((cloneDoc['notes'] as List).length, 1);
    expect(((cloneDoc['notes'] as List).first as Map)['note_name'], 'Lore');

    // The cover file was copied too.
    expect(File('${clone.path}/cover.jpg').existsSync(), isTrue);

    // The original is untouched.
    final demoDoc =
        jsonDecode(
              File(
                '${harness.projectsDir.path}/Demo/LivingScroll.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect((demoDoc['metadata'] as Map)['name'], 'Demo');

    // Both tiles are in the grid.
    expect(find.byKey(const ValueKey('adventure.tile.Demo')), findsOne);
    expect(find.byKey(ValueKey('adventure.tile.$cloneSlug')), findsOne);
  });

  testWidgets('BRANCH clone_twice: a second clone disambiguates the name', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openCreate(tester);

    await cloneDemo(tester); // -> "Demo cloned"
    await cloneDemo(tester); // -> "Demo cloned 2"

    final dirs = harness.projects();
    expect(dirs.length, 3); // Demo + two distinct clone directories

    final names = <String>{};
    for (final d in dirs) {
      names.add((harness.readDocument(d)['metadata'] as Map)['name'] as String);
    }
    expect(names, {'Demo', 'Demo cloned', 'Demo cloned 2'});

    // The three directories are all distinct slugs.
    expect(dirs.map(slugOf).toSet().length, 3);
  });
}
