// PATH: create key_events (each minted a uuid) -> add a note and tick events
// into its visibility_rules. The editor lists events BY NAME but the saved rule
// stores their key_event_uuid. Branches: empty rule (omitted), unticking, and
// reopening a note whose rule reflects the ticked event.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> keyEvents = const [],
    List<Object> notes = const [],
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
        'scenes': [],
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

  List<Map<String, dynamic>> readNotes(CreateHarness harness) =>
      (readDoc(harness)['notes'] as List).cast<Map<String, dynamic>>();

  String uuidOf(CreateHarness harness, String name) =>
      readEvents(harness).firstWhere((e) => e['name'] == name)['key_event_uuid']
          as String;

  Future<void> openGame(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
  }

  Future<void> tapNav(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> addKeyEvent(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('event.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.keyevents.edit.field.name')),
      name,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
    await tester.pumpAndSettle();
  }

  Future<void> addNoteNamed(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.notes.edit.field.name')),
      name,
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveNote(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('game.notes.edit.save')),
    );
    await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
    await tester.pumpAndSettle();
  }

  bool checkboxValue(WidgetTester tester, String name) =>
      tester
          .widget<CheckboxListTile>(find.byKey(ValueKey('vis.event.$name')))
          .value ??
      false;

  testWidgets(
    'create key events, then author a note visibility_rules over them (by uuid)',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      await harness.pumpApp(tester);
      await openGame(tester);

      // STEP 1-2: create the two key events (each minted a uuid).
      await tapNav(tester, 'nav.game.keyevents');
      await addKeyEvent(tester, 'Met the duke');
      await addKeyEvent(tester, 'Found the map');
      expect(readEvents(harness).length, 2);
      final uuidA = uuidOf(harness, 'Met the duke');
      final uuidB = uuidOf(harness, 'Found the map');
      expect(uuidA.isNotEmpty, isTrue);
      expect(uuidB.isNotEmpty, isTrue);
      expect(uuidA == uuidB, isFalse);

      // STEP 3: add a note; the freshly created events are available in the editor.
      await tapNav(tester, 'nav.game.notes');
      await addNoteNamed(tester, 'Hook');
      expect(find.byKey(const ValueKey('vis.event.Met the duke')), findsOne);
      expect(find.byKey(const ValueKey('vis.event.Found the map')), findsOne);
      expect(find.byKey(const ValueKey('vis.empty')), findsOne);

      // STEP 4: tick both events (by name).
      await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vis.empty')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('vis.event.Found the map')));
      await tester.pumpAndSettle();

      // STEP 5: choose ANY (OR).
      await tester.tap(find.byKey(const ValueKey('vis.op.any')));
      await tester.pumpAndSettle();

      // STEP 6: Save -> the rule stores the events' uuids, in tick order.
      await saveNote(tester);
      final note = readNotes(harness).single;
      expect(note['note_name'], 'Hook');
      expect(note['visibility_rules'], {
        'op': 'or',
        'key_events': [uuidA, uuidB],
      });
    },
  );

  testWidgets(
    'BRANCH empty_rule_always_visible: nothing ticked omits the rule',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: const [
          {
            'name': 'Met the duke',
            'key_event_uuid': 'ke-a',
            'state': 'unchecked',
          },
        ],
      );

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.notes');
      await addNoteNamed(tester, 'Hook');

      expect(find.byKey(const ValueKey('vis.empty')), findsOne);
      await saveNote(tester);

      // Empty rule -> visibility_rules omitted (always visible).
      expect(
        readNotes(harness).single.containsKey('visibility_rules'),
        isFalse,
      );
    },
  );

  testWidgets('BRANCH untick_leaves_the_other: unticking drops only its uuid', (
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
          'key_event_uuid': 'ke-a',
          'state': 'unchecked',
        },
        {
          'name': 'Found the map',
          'key_event_uuid': 'ke-b',
          'state': 'unchecked',
        },
      ],
    );

    await harness.pumpApp(tester);
    await openGame(tester);
    await tapNav(tester, 'nav.game.notes');
    await addNoteNamed(tester, 'Hook');

    await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vis.event.Found the map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
    await tester.pumpAndSettle();

    await saveNote(tester);

    // Default op (AND), only the still-ticked event's uuid remains.
    expect(readNotes(harness).single['visibility_rules'], {
      'op': 'and',
      'key_events': ['ke-b'],
    });
  });

  testWidgets('BRANCH reopen_shows_ticked: a rule reflects its ticked event', (
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
          'key_event_uuid': 'ke-a',
          'state': 'unchecked',
        },
      ],
      notes: const [
        {
          'note_uuid': 'n1',
          'note_name': 'N',
          'note_content': 'c',
          'visibility_rules': {
            'op': 'and',
            'key_events': ['ke-a'],
          },
        },
      ],
    );

    await harness.pumpApp(tester);
    await openGame(tester);
    await tapNav(tester, 'nav.game.notes');

    await tester.tap(find.byKey(const ValueKey('note.tile.n1')));
    await tester.pumpAndSettle();

    // The rule's uuid (ke-a) ticks the row found by name.
    expect(find.byKey(const ValueKey('game.notes.edit.field.name')), findsOne);
    expect(checkboxValue(tester, 'Met the duke'), isTrue);
    expect(readNotes(harness).length, 1); // nothing written
  });
}
