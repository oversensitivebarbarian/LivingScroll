// PATH: open adventure -> Notes list -> Add note (name + content + visibility) ->
// Save writes notes[] (with visibility_rules). Branches: load, cancel-new,
// delete (confirm / cancel) and the unsaved-changes choices.

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

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> notes = const [],
    List<Object> keyEvents = const [],
    List<Object> images = const [],
    List<Object> npcs = const [],
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
        'images': images,
        'audio': [],
        'paths': [],
        'key_events': keyEvents,
        'notes': notes,
        'gm_notes': [],
        'npcs': npcs,
        'scenes': [],
      }),
    );
  }

  Future<void> openNotes(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.notes')));
    await tester.pumpAndSettle();
  }

  // Add note -> type a name (leaving the editor dirty).
  Future<void> addNoteNamed(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('game.notes.edit.field.name')),
      name,
    );
    await tester.pumpAndSettle();
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  List<Map<String, dynamic>> readNotes(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['notes']
              as List)
          .cast<Map<String, dynamic>>();

  const seededNote = [
    {'note_uuid': 'n1', 'note_name': 'Intro', 'note_content': 'c'},
  ];

  testWidgets('game_notes: add a note with a visibility rule -> written to disk', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      keyEvents: [
        {
          'name': 'Met the duke',
          'key_event_uuid': 'ke-duke',
          'description': '',
          'state': 'unchecked',
        },
      ],
    );

    await harness.pumpApp(tester);
    await openNotes(tester);
    expect(find.byKey(const ValueKey('note.search')), findsOne);
    expect(find.byKey(const ValueKey('note.list')), findsOne);

    // STEP 2: the editor, Save disabled (no name yet), visibility editor present.
    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vis.event.Met the duke')), findsOne);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('game.notes.edit.save')),
          )
          .enabled,
      isFalse,
    );

    // STEP 3: fill name, confirm the rich content editor is present, tick the
    // event (by name) into the rule. (The content body is a flutter_quill editor,
    // not a typeable TextField, so it is left untouched here.)
    await tester.enterText(
      find.byKey(const ValueKey('game.notes.edit.field.name')),
      'Hook',
    );
    expect(
      find.byKey(const ValueKey('game.notes.edit.field.content')),
      findsOne,
    );
    await tester.tap(find.byKey(const ValueKey('vis.event.Met the duke')));
    await tester.pumpAndSettle();

    // STEP 4: Save.
    await tester.ensureVisible(
      find.byKey(const ValueKey('game.notes.edit.save')),
    );
    await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
    await tester.pumpAndSettle();

    final notes = readNotes(harness);
    expect(notes.length, 1);
    final note = notes.single;
    expect(note['note_name'], 'Hook');
    // An untouched rich body persists as the empty string.
    expect(note['note_content'], '');
    expect((note['note_uuid'] as String).isNotEmpty, isTrue);
    // The rule stores the event's key_event_uuid, not its name.
    expect(note['visibility_rules'], {
      'op': 'and',
      'key_events': ['ke-duke'],
    });
    expect(find.byKey(const ValueKey('note.list')), findsOne);
    expect(find.text('Hook'), findsOne);
  });

  testWidgets('BRANCH existing_loaded: a seeded note shows on its tile', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness, notes: seededNote);

    await harness.pumpApp(tester);
    await openNotes(tester);

    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.text('Intro'), findsOne);
  });

  testWidgets('BRANCH search_filter: search filters by title and content', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      notes: const [
        {'note_uuid': 'n1', 'note_name': 'Alpha', 'note_content': 'dragons'},
        {'note_uuid': 'n2', 'note_name': 'Beta', 'note_content': 'castles'},
      ],
    );

    await harness.pumpApp(tester);
    await openNotes(tester);

    // Both tiles visible with an empty query.
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOne);

    // Match by TITLE -> only Alpha (n1).
    await tester.enterText(find.byKey(const ValueKey('note.search')), 'alph');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsNothing);
    expect(find.byKey(const ValueKey('note.new')), findsOne); // add cell stays
    expect(readNotes(harness).length, 2); // search never writes

    // Match by CONTENT -> only Beta (n2, content "castles").
    await tester.enterText(find.byKey(const ValueKey('note.search')), 'castle');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsNothing);

    // Clearing the query restores both.
    await tester.enterText(find.byKey(const ValueKey('note.search')), '');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOne);
  });

  testWidgets('BRANCH search_clear: the clear button empties the query', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      notes: const [
        {'note_uuid': 'n1', 'note_name': 'Alpha', 'note_content': 'dragons'},
        {'note_uuid': 'n2', 'note_name': 'Beta', 'note_content': 'castles'},
      ],
    );

    await harness.pumpApp(tester);
    await openNotes(tester);

    // Empty query -> no clear button.
    expect(find.byKey(const ValueKey('note.search.clear')), findsNothing);

    // Typing filters the list and reveals the clear button.
    await tester.enterText(find.byKey(const ValueKey('note.search')), 'alph');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.search.clear')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsNothing);

    // Tapping clear empties the field, hides the button and restores all tiles.
    await tester.tap(find.byKey(const ValueKey('note.search.clear')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note.search')))
          .controller!
          .text,
      '',
    );
    expect(find.byKey(const ValueKey('note.search.clear')), findsNothing);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOne);
    expect(readNotes(harness).length, 2); // nothing written
  });

  testWidgets('BRANCH cancel_new: Cancel drops a new note', (tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNotes(tester);
    await addNoteNamed(tester, 'Temp');

    await tester.tap(find.byKey(const ValueKey('game.notes.edit.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note.list')), findsOne);
    expect(readNotes(harness), isEmpty); // nothing written
  });

  testWidgets('BRANCH delete: confirming removes the note from disk', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness, notes: seededNote);

    await harness.pumpApp(tester);
    await openNotes(tester);

    await tester.tap(find.byKey(const ValueKey('note.tile.n1.delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.delete.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('note.delete.confirm')));
    await tester.pumpAndSettle();

    expect(readNotes(harness), isEmpty);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsNothing);
  });

  testWidgets('BRANCH delete_cancel: cancelling the dialog keeps the note', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness, notes: seededNote);

    await harness.pumpApp(tester);
    await openNotes(tester);

    await tester.tap(find.byKey(const ValueKey('note.tile.n1.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note.delete.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note.tile.n1')), findsOne);
    expect(readNotes(harness).length, 1); // unchanged
  });

  testWidgets('BRANCH unsaved_save: leaving mid-edit -> Save persists', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNotes(tester);
    await addNoteNamed(tester, 'Hook');

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    expect(readNotes(harness).single['note_name'], 'Hook');
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_abandon: leaving mid-edit -> Discard drops it', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNotes(tester);
    await addNoteNamed(tester, 'Hook');

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
    await tester.pumpAndSettle();

    expect(readNotes(harness), isEmpty);
    expect(selectedIndex(tester), scenesIndex);
  });

  testWidgets('BRANCH unsaved_cancel: leaving mid-edit -> Cancel stays', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(harness);

    await harness.pumpApp(tester);
    await openNotes(tester);
    await addNoteNamed(tester, 'Hook');

    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game.notes.edit.field.name')), findsOne);
    expect(selectedIndex(tester), notesIndex);
    expect(readNotes(harness), isEmpty);
  });

  // A note already titled "a" is on disk; a second note may not reuse it.
  const dupNote = [
    {'note_uuid': 'n1', 'note_name': 'a', 'note_content': 'c'},
  ];

  testWidgets(
    'BRANCH duplicate_name_edit_save: editor Save rejects a duplicate',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness, notes: dupNote);

      await harness.pumpApp(tester);
      await openNotes(tester);
      await addNoteNamed(tester, 'a');

      await tester.ensureVisible(
        find.byKey(const ValueKey('game.notes.edit.save')),
      );
      await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
      await tester.pumpAndSettle();

      // Rejected: the not-unique dialog is shown and nothing was written.
      expect(
        find.byKey(const ValueKey('notes.name.not.unique.dialog')),
        findsOne,
      );
      expect(readNotes(harness).length, 1); // still just the seeded note

      await tester.tap(find.byKey(const ValueKey('notes.name.not.unique.ok')));
      await tester.pumpAndSettle();

      // Still on the edit form, nothing persisted.
      expect(
        find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsOne,
      );
      expect(readNotes(harness).length, 1);
    },
  );

  testWidgets(
    'BRANCH duplicate_name_guard_save: rail-guard Save rejects a duplicate',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness, notes: dupNote);

      await harness.pumpApp(tester);
      await openNotes(tester);
      await addNoteNamed(tester, 'a');

      // Leave the section mid-edit -> the unsaved-changes prompt -> Save.
      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      // The reported bug: this must NOT save. Instead the not-unique dialog shows
      // and the duplicate is not written.
      expect(
        find.byKey(const ValueKey('notes.name.not.unique.dialog')),
        findsOne,
      );
      expect(readNotes(harness).length, 1); // duplicate not added

      await tester.tap(find.byKey(const ValueKey('notes.name.not.unique.ok')));
      await tester.pumpAndSettle();

      // Navigation was aborted: still on Notes, still editing, nothing written.
      expect(selectedIndex(tester), notesIndex);
      expect(
        find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsOne,
      );
      expect(readNotes(harness).length, 1);
    },
  );

  testWidgets(
    'BRANCH embed_image: the editor embeds an adventure image AND an NPC '
    'portrait',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        images: const [
          {'image_uuid': 'img-1', 'name': 'Map'},
        ],
        npcs: const [
          {
            'npc_uuid': 'npc-1',
            'name': 'Duke',
            'full_image': 'full-1',
            'icon_image': 'icon-1',
            'description': '',
            'backstory': '',
            'state': 'active',
          },
        ],
      );

      await harness.pumpApp(tester);
      await openNotes(tester);
      await addNoteNamed(tester, 'Hook');

      // Open the picker: it lists BOTH the adventure image and the NPC portrait.
      await tester.tap(
        find.byKey(const ValueKey('game.notes.edit.content.image')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('game.notes.edit.image.pick')),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey('game.notes.edit.image.pick.tile.other.img-1'),
        ),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey('game.notes.edit.image.pick.tile.npc.full-1'),
        ),
        findsOne,
      );

      // Embed the adventure image.
      await tester.tap(
        find.byKey(
          const ValueKey('game.notes.edit.image.pick.tile.other.img-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Embed the NPC portrait too.
      await tester.tap(
        find.byKey(const ValueKey('game.notes.edit.content.image')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('game.notes.edit.image.pick.tile.npc.full-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Save -> note_content carries both image embeds as scope:uuid references.
      await tester.ensureVisible(
        find.byKey(const ValueKey('game.notes.edit.save')),
      );
      await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
      await tester.pumpAndSettle();

      final note = readNotes(harness).single;
      final ops = jsonDecode(note['note_content'] as String) as List;
      final embeds = [
        for (final op in ops)
          if (op is Map && op['insert'] is Map) (op['insert'] as Map)['image'],
      ];
      expect(embeds, contains('other:img-1'));
      expect(embeds, contains('npc:full-1'));
    },
  );
}
