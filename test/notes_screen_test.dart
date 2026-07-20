import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/notes/notes_controller.dart';
import 'package:living_scroll/screens/notes_screen.dart';
import 'package:living_scroll/widgets/note_tile.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        // The note editor uses flutter_quill, whose widgets need this delegate.
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key))).enabled;

void main() {
  testWidgets('list shows the Add-note row and one tile per note',
      (tester) async {
    final controller = NotesController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'Intro', 'note_content': 'x'}
      ],
      'key_events': [],
    });

    await tester.pumpWidget(_app(
        NotesScreen(controller: controller, onPersist: () async {})));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.new')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);

    // The add row shows ONLY the Note Add glyph (no "+", no "Add note" text).
    expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.byKey(const ValueKey('note.new')),
              matching: find.byType(Icon),
            ))
            .icon,
        Icons.note_add_outlined);
    expect(find.text('Add note'), findsNothing);
  });

  testWidgets('Add note -> editor -> Save persists and shows the new tile',
      (tester) async {
    var persisted = 0;
    final controller = NotesController(newId: () => 'new1');
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [],
      'key_events': [
        {'name': 'Met the duke'}
      ],
    });

    await tester.pumpWidget(_app(NotesScreen(
        controller: controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();

    // Editor shown, with the visibility editor + its key-event option.
    expect(find.byKey(const ValueKey('game.notes.edit.field.name')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('vis.root')), findsOneWidget);
    expect(find.byKey(const ValueKey('vis.event.Met the duke')), findsOneWidget);

    // Save disabled until the note has a name.
    expect(_enabled(tester, 'game.notes.edit.save'), isFalse);
    await tester.enterText(
        find.byKey(const ValueKey('game.notes.edit.field.name')), 'Hook');
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'game.notes.edit.save'), isTrue);

    await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
    await tester.pumpAndSettle();

    // Back on the list; the note was added and persisted.
    expect(find.byKey(const ValueKey('note.list')), findsOneWidget);
    expect(persisted, 1);
    expect(controller.notes.single.name, 'Hook');
    expect(find.byKey(const ValueKey('note.tile.new1')), findsOneWidget);
    expect(find.text('Hook'), findsOneWidget);
  });

  testWidgets('search filters the list by title and content', (tester) async {
    final controller = NotesController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'Alpha', 'note_content': 'dragons'},
        {'note_uuid': 'n2', 'note_name': 'Beta', 'note_content': 'castles'},
      ],
      'key_events': [],
    });

    await tester.pumpWidget(_app(
        NotesScreen(controller: controller, onPersist: () async {})));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note.tile.n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOneWidget);

    // By title (case-insensitive).
    await tester.enterText(find.byKey(const ValueKey('note.search')), 'ALPH');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsNothing);
    expect(find.byKey(const ValueKey('note.new')), findsOneWidget);

    // By content.
    await tester.enterText(find.byKey(const ValueKey('note.search')), 'castle');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsNothing);

    // Cleared -> both back.
    await tester.enterText(find.byKey(const ValueKey('note.search')), '');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOneWidget);
  });

  testWidgets('clear button empties the query and restores the list',
      (tester) async {
    final controller = NotesController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'Alpha', 'note_content': 'dragons'},
        {'note_uuid': 'n2', 'note_name': 'Beta', 'note_content': 'castles'},
      ],
      'key_events': [],
    });

    await tester.pumpWidget(_app(
        NotesScreen(controller: controller, onPersist: () async {})));
    await tester.pumpAndSettle();

    // No clear button while empty.
    expect(find.byKey(const ValueKey('note.search.clear')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('note.search')), 'alph');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.search.clear')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('note.search.clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.search.clear')), findsNothing);
    expect(find.byKey(const ValueKey('note.tile.n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.tile.n2')), findsOneWidget);
  });

  testWidgets('Save with a duplicate title is rejected and not persisted',
      (tester) async {
    var persisted = 0;
    final controller = NotesController(newId: () => 'new1');
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'a', 'note_content': 'x'}
      ],
      'key_events': [],
    });

    await tester.pumpWidget(_app(NotesScreen(
        controller: controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('game.notes.edit.field.name')), 'a');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game.notes.edit.save')));
    await tester.pumpAndSettle();

    // Warned, nothing saved, still editing.
    expect(
        find.byKey(const ValueKey('notes.name.not.unique.dialog')), findsOne);
    expect(persisted, 0);
    expect(controller.notes.length, 1);

    await tester.tap(find.byKey(const ValueKey('notes.name.not.unique.ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.notes.edit.field.name')), findsOne);
    expect(controller.notes.length, 1);
  });

  testWidgets('Cancel discards the new note', (tester) async {
    var persisted = 0;
    final controller = NotesController(newId: () => 'new1');
    addTearDown(controller.dispose);
    controller.loadFrom({'notes': [], 'key_events': []});

    await tester.pumpWidget(_app(NotesScreen(
        controller: controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('game.notes.edit.field.name')), 'Temp');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game.notes.edit.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note.list')), findsOneWidget);
    expect(controller.notes, isEmpty);
    expect(persisted, 0);
  });

  testWidgets('delete asks to confirm, then removes and persists',
      (tester) async {
    var persisted = 0;
    final controller = NotesController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'Intro', 'note_content': 'x'}
      ],
      'key_events': [],
    });

    await tester.pumpWidget(_app(NotesScreen(
        controller: controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note.tile.n1.delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note.delete.dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note.delete.confirm')));
    await tester.pumpAndSettle();

    expect(controller.notes, isEmpty);
    expect(persisted, 1);
    expect(find.byType(NoteTile), findsNothing);
  });
}
