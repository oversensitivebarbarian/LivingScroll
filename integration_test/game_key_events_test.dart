// PATH: open adventure -> Key events list -> Add event writes key_events[];
// search filters by name/content; a duplicate name is rejected (editor + rail
// guard); deleting an event cascade-strips every reference to it (notes'
// visibility_rules, scenes' key_events) and removes the event itself.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenesIndex = 2;
  const keyEventsIndex = 5;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> keyEvents = const [],
    List<Object> notes = const [],
    List<Object> scenes = const [],
  }) async {
    final dir = demoDir(harness);
    await dir.create(recursive: true);
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
        'key_events': keyEvents,
        'notes': notes,
        'gm_notes': [],
        'npcs': [],
        'scenes': scenes,
      }),
    );
  }

  Map<String, dynamic> readDoc(CreateHarness harness) =>
      jsonDecode(
            File(
              '${demoDir(harness).path}/LivingScroll.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> readEvents(CreateHarness harness) =>
      (readDoc(harness)['key_events'] as List).cast<Map<String, dynamic>>();

  Future<void> openKeyEvents(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.keyevents')));
    await tester.pumpAndSettle();
  }

  Future<void> addEventNamed(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('event.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.keyevents.edit.field.name')),
      name,
    );
    await tester.pumpAndSettle();
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  testWidgets('game_key_events: add an event -> written to disk', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openKeyEvents(tester);
    expect(find.byKey(const ValueKey('event.search')), findsOne);
    expect(find.byKey(const ValueKey('event.list')), findsOne);

    await addEventNamed(tester, 'Met the duke');
    await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
    await tester.pumpAndSettle();

    final events = readEvents(harness);
    expect(events.length, 1);
    // Only name + a minted uuid + default state are written (no description).
    expect(events.single.keys.toSet(), {'name', 'key_event_uuid', 'state'});
    expect(events.single['name'], 'Met the duke');
    expect(events.single['state'], 'unchecked');
    expect((events.single['key_event_uuid'] as String).isNotEmpty, isTrue);
    expect(find.byKey(const ValueKey('event.tile.Met the duke')), findsOne);
  });

  testWidgets('BRANCH search_filter: filters by name; clear restores', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      keyEvents: const [
        {'name': 'Alpha', 'key_event_uuid': 'u1', 'state': 'unchecked'},
        {'name': 'Beta', 'key_event_uuid': 'u2', 'state': 'unchecked'},
      ],
    );

    await harness.pumpApp(tester);
    await openKeyEvents(tester);

    await tester.enterText(find.byKey(const ValueKey('event.search')), 'alph');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.tile.Alpha')), findsOne);
    expect(find.byKey(const ValueKey('event.tile.Beta')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('event.search.clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.tile.Alpha')), findsOne);
    expect(find.byKey(const ValueKey('event.tile.Beta')), findsOne);
  });

  testWidgets('BRANCH delete_cascade: deleting strips every reference', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      keyEvents: const [
        {
          'name': 'Met the duke',
          'key_event_uuid': 'ke-duke',
          'state': 'checked',
        },
        {'name': 'Other', 'key_event_uuid': 'ke-other', 'state': 'unchecked'},
      ],
      // visibility_rules reference events BY UUID...
      notes: const [
        {
          'note_uuid': 'n1',
          'note_name': 'Both',
          'note_content': 'c',
          'visibility_rules': {
            'op': 'and',
            'key_events': ['ke-duke', 'ke-other'],
          },
        },
        {
          'note_uuid': 'n2',
          'note_name': 'Only',
          'note_content': 'c',
          'visibility_rules': {
            'op': 'and',
            'key_events': ['ke-duke'],
          },
        },
      ],
      // ...while a scene references the event BY NAME.
      scenes: const [
        {
          'name': 'S1',
          'key_events': ['Met the duke'],
        },
      ],
    );

    await harness.pumpApp(tester);
    await openKeyEvents(tester);

    await tester.tap(
      find.byKey(const ValueKey('event.tile.Met the duke.delete')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.delete.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('event.delete.confirm')));
    await tester.pumpAndSettle();

    final doc = readDoc(harness);

    // The event itself is gone; the other one remains.
    final names = (doc['key_events'] as List).map((e) => e['name']).toList();
    expect(names, ['Other']);

    final notes = (doc['notes'] as List).cast<Map<String, dynamic>>();
    // n1 kept its rule, minus the deleted event's uuid.
    final n1 = notes.firstWhere((n) => n['note_uuid'] == 'n1');
    expect(n1['visibility_rules']['key_events'], ['ke-other']);
    // n2's rule had only the deleted event -> the empty rule is dropped.
    final n2 = notes.firstWhere((n) => n['note_uuid'] == 'n2');
    expect(n2.containsKey('visibility_rules'), isFalse);

    // The scene reference is stripped.
    final scene = (doc['scenes'] as List).first as Map<String, dynamic>;
    expect(scene['key_events'], isEmpty);

    // The tile is gone from the list.
    expect(find.byKey(const ValueKey('event.tile.Met the duke')), findsNothing);
    expect(find.byKey(const ValueKey('event.tile.Other')), findsOne);
  });

  testWidgets(
    'BRANCH duplicate_name_edit_save: editor Save rejects a duplicate',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: const [
          {'name': 'a', 'description': '', 'state': 'unchecked'},
        ],
      );

      await harness.pumpApp(tester);
      await openKeyEvents(tester);
      await addEventNamed(tester, 'a');

      await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('keyevents.name.not.unique.dialog')),
        findsOne,
      );
      expect(readEvents(harness).length, 1);

      await tester.tap(
        find.byKey(const ValueKey('keyevents.name.not.unique.ok')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsOne,
      );
      expect(readEvents(harness).length, 1);
    },
  );

  testWidgets('BRANCH duplicate_name_guard_save: rail-guard Save rejects', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      keyEvents: const [
        {'name': 'a', 'description': '', 'state': 'unchecked'},
      ],
    );

    await harness.pumpApp(tester);
    await openKeyEvents(tester);
    await addEventNamed(tester, 'a');

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('keyevents.name.not.unique.dialog')),
      findsOne,
    );
    expect(readEvents(harness).length, 1);

    await tester.tap(
      find.byKey(const ValueKey('keyevents.name.not.unique.ok')),
    );
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), keyEventsIndex); // navigation aborted
    expect(
      find.byKey(const ValueKey('game.keyevents.edit.field.name')),
      findsOne,
    );
    expect(readEvents(harness).length, 1);
  });

  testWidgets('BRANCH unsaved_save: leaving mid-edit -> Save persists', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openKeyEvents(tester);
    await addEventNamed(tester, 'Found the map');

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(readEvents(harness).single['name'], 'Found the map');
    expect(selectedIndex(tester), scenesIndex);
  });
}
