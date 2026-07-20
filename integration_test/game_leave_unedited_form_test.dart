// PATH: a section's create/edit form opened but left UNTOUCHED is a pristine
// draft. Leaving the section shows no unsaved-changes prompt and navigates at
// once; returning must land on the BASE LISTING, not the still-open form.
// Covers Notes / Key events / Paths, for a new draft and an existing entity.
// Nothing is ever written on this path.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenesIndex = 2;
  const notesIndex = 4;
  const keyEventsIndex = 5;
  const pathsIndex = 8;

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> notes = const [],
    List<Object> keyEvents = const [],
    List<Object> paths = const [],
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
        'paths': paths,
        'key_events': keyEvents,
        'notes': notes,
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
  }

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

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  String diskJson(CreateHarness harness) =>
      File('${demoDir(harness).path}/LivingScroll.json').readAsStringSync();

  // --- STEPS: a brand-new note draft, untouched, resets to the list ----------

  testWidgets(
    'game_leave_unedited_form: new note draft left untouched resets to list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      final before = diskJson(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.notes');
      expect(find.byKey(const ValueKey('note.list')), findsOne);

      // STEP 2: open the editor for a new note — pristine, nothing typed.
      await tester.tap(find.byKey(const ValueKey('note.new')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsOne,
      );

      // STEP 3: leave for Scenes — no prompt, navigation proceeds at once.
      await tapNav(tester, 'nav.game.scenes');
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );
      expect(selectedIndex(tester), scenesIndex);

      // STEP 4: return to Notes — the base listing, not the open form.
      await tapNav(tester, 'nav.game.notes');
      expect(find.byKey(const ValueKey('note.list')), findsOne);
      expect(
        find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsNothing,
      );
      expect(selectedIndex(tester), notesIndex);
      expect(diskJson(harness), before); // nothing written
    },
  );

  // --- BRANCH notes_existing -------------------------------------------------

  testWidgets(
    'BRANCH notes_existing: an untouched note edit resets to the list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        notes: const [
          {'note_uuid': 'n1', 'note_name': 'Intro', 'note_content': 'c'},
        ],
      );
      final before = diskJson(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.notes');

      // Open the existing note for edit, change nothing.
      await tester.tap(find.byKey(const ValueKey('note.tile.n1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('game.notes.edit.field.name')),
            )
            .controller!
            .text,
        'Intro',
      );

      await tapNav(tester, 'nav.game.scenes');
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );
      expect(selectedIndex(tester), scenesIndex);

      await tapNav(tester, 'nav.game.notes');
      expect(find.byKey(const ValueKey('note.list')), findsOne);
      expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
      expect(
        find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsNothing,
      );
      expect(diskJson(harness), before);
    },
  );

  // --- BRANCH key_events_new -------------------------------------------------

  testWidgets(
    'BRANCH key_events_new: a new event draft left untouched resets to list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      final before = diskJson(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.keyevents');
      expect(find.byKey(const ValueKey('event.list')), findsOne);

      await tester.tap(find.byKey(const ValueKey('event.new')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsOne,
      );

      await tapNav(tester, 'nav.game.scenes');
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );
      expect(selectedIndex(tester), scenesIndex);

      await tapNav(tester, 'nav.game.keyevents');
      expect(find.byKey(const ValueKey('event.list')), findsOne);
      expect(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsNothing,
      );
      expect(selectedIndex(tester), keyEventsIndex);
      expect(diskJson(harness), before);
    },
  );

  // --- BRANCH key_events_existing --------------------------------------------

  testWidgets(
    'BRANCH key_events_existing: an untouched event edit resets to the list',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        keyEvents: const [
          {
            'name': 'Alpha',
            'key_event_uuid': 'ke-a',
            'description': '',
            'state': 'unchecked',
          },
        ],
      );
      final before = diskJson(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.keyevents');

      await tester.tap(find.byKey(const ValueKey('event.tile.Alpha')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('game.keyevents.edit.field.name')),
            )
            .controller!
            .text,
        'Alpha',
      );

      await tapNav(tester, 'nav.game.scenes');
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );

      await tapNav(tester, 'nav.game.keyevents');
      expect(find.byKey(const ValueKey('event.list')), findsOne);
      expect(find.byKey(const ValueKey('event.tile.Alpha')), findsOne);
      expect(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsNothing,
      );
      expect(diskJson(harness), before);
    },
  );

  // --- BRANCH paths_existing -------------------------------------------------

  testWidgets(
    'BRANCH paths_existing: an untouched path edit resets to the grid',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        paths: const [
          {'name': 'Old route', 'color': 'blue', 'description': 'the old way'},
        ],
      );
      final before = diskJson(harness);

      await harness.pumpApp(tester);
      await openGame(tester);
      await tapNav(tester, 'nav.game.paths');
      expect(find.byKey(const ValueKey('game.paths.list')), findsOne);

      await tester.tap(find.byKey(const ValueKey('path.tile.blue')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('game.paths.edit.field.name')),
            )
            .controller!
            .text,
        'Old route',
      );

      await tapNav(tester, 'nav.game.scenes');
      expect(
        find.byKey(const ValueKey('settings.unsaved.dialog')),
        findsNothing,
      );
      expect(selectedIndex(tester), scenesIndex);

      await tapNav(tester, 'nav.game.paths');
      expect(find.byKey(const ValueKey('game.paths.list')), findsOne);
      expect(
        find.byKey(const ValueKey('game.paths.edit.field.name')),
        findsNothing,
      );
      expect(selectedIndex(tester), pathsIndex);
      expect(diskJson(harness), before);
    },
  );
}
