import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/keyevents/key_events_controller.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/key_events_screen.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key))).enabled;

KeyEventsScreen _screen(
  KeyEventsController controller, {
  Future<void> Function()? onPersist,
  Future<void> Function(String)? onDeleteEvent,
}) =>
    KeyEventsScreen(
      controller: controller,
      onPersist: onPersist ?? () async {},
      onDeleteEvent: onDeleteEvent ?? (_) async {},
    );

void main() {
  testWidgets('list shows the Add-event row and one tile per event',
      (tester) async {
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'key_events': [
        {'name': 'Met the duke', 'description': 'd', 'state': 'unchecked'},
      ],
    });

    await tester.pumpWidget(_app(_screen(controller)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('event.new')), findsOneWidget);
    expect(find.byKey(const ValueKey('event.tile.Met the duke')), findsOneWidget);
    expect(find.text('Met the duke'), findsOneWidget);

    // The tile's leading glyph is a Check Circle.
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('event.tile.Met the duke')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget);

    // The add row shows the Add task icon (no "+" sign, no "Add event" text).
    expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.byKey(const ValueKey('event.new')),
              matching: find.byType(Icon),
            ))
            .icon,
        Icons.add_task);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('event.new')),
          matching: find.text('+'),
        ),
        findsNothing);
    expect(find.text('Add event'), findsNothing);
  });

  testWidgets('Add event -> editor -> Save persists and shows the new tile',
      (tester) async {
    var persisted = 0;
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({'key_events': []});

    await tester.pumpWidget(
        _app(_screen(controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('event.new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsOneWidget);

    // Save disabled until the event has a name.
    expect(_enabled(tester, 'game.keyevents.edit.save'), isFalse);
    await tester.enterText(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')), 'Found the map');
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'game.keyevents.edit.save'), isTrue);

    await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event.list')), findsOneWidget);
    expect(persisted, 1);
    expect(controller.events.single.name, 'Found the map');
    expect(find.byKey(const ValueKey('event.tile.Found the map')), findsOneWidget);
  });

  testWidgets('search filters the list by name; clear restores', (tester) async {
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'key_events': [
        {'name': 'Alpha', 'key_event_uuid': 'u1', 'state': 'unchecked'},
        {'name': 'Beta', 'key_event_uuid': 'u2', 'state': 'unchecked'},
      ],
    });

    await tester.pumpWidget(_app(_screen(controller)));
    await tester.pumpAndSettle();

    // By name (case-insensitive).
    await tester.enterText(find.byKey(const ValueKey('event.search')), 'ALPH');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.tile.Alpha')), findsOneWidget);
    expect(find.byKey(const ValueKey('event.tile.Beta')), findsNothing);
    expect(find.byKey(const ValueKey('event.new')), findsOneWidget);

    // Clear button restores all.
    expect(find.byKey(const ValueKey('event.search.clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event.search.clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.search.clear')), findsNothing);
    expect(find.byKey(const ValueKey('event.tile.Alpha')), findsOneWidget);
    expect(find.byKey(const ValueKey('event.tile.Beta')), findsOneWidget);
  });

  testWidgets('Save with a duplicate name is rejected and not persisted',
      (tester) async {
    var persisted = 0;
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'key_events': [
        {'name': 'a', 'description': '', 'state': 'unchecked'},
      ],
    });

    await tester.pumpWidget(
        _app(_screen(controller, onPersist: () async => persisted++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('event.new')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('game.keyevents.edit.field.name')), 'a');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.keyevents.edit.save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('keyevents.name.not.unique.dialog')),
        findsOneWidget);
    expect(persisted, 0);
    expect(controller.events.length, 1);

    await tester.tap(find.byKey(const ValueKey('keyevents.name.not.unique.ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.keyevents.edit.field.name')),
        findsOneWidget);
  });

  testWidgets('delete asks to confirm, then invokes the cascade callback',
      (tester) async {
    String? deleted;
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'key_events': [
        {'name': 'Met the duke', 'description': '', 'state': 'unchecked'},
      ],
    });

    await tester.pumpWidget(_app(_screen(controller,
        onDeleteEvent: (name) async => deleted = name)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('event.tile.Met the duke.delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event.delete.dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event.delete.confirm')));
    await tester.pumpAndSettle();

    expect(deleted, 'Met the duke');
  });

  testWidgets('delete cancel does not invoke the callback', (tester) async {
    var called = 0;
    final controller = KeyEventsController();
    addTearDown(controller.dispose);
    controller.loadFrom({
      'key_events': [
        {'name': 'Met the duke', 'description': '', 'state': 'unchecked'},
      ],
    });

    await tester.pumpWidget(_app(_screen(controller,
        onDeleteEvent: (_) async => called++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('event.tile.Met the duke.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event.delete.cancel')));
    await tester.pumpAndSettle();

    expect(called, 0);
    expect(find.byKey(const ValueKey('event.tile.Met the duke')), findsOneWidget);
  });
}
