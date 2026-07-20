import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/keyevents/key_events_controller.dart';

void main() {
  group('KeyEvent uuid creation + persistence', () {
    test('a new event is minted a key_event_uuid and saves the canonical shape',
        () {
      final controller = KeyEventsController(newId: () => 'kev-1');
      controller.loadFrom({'key_events': []});

      controller.beginNew();
      controller.editName = 'Met the duke';
      expect(controller.save(), isTrue);

      final event = controller.events.single;
      expect(event.uuid, 'kev-1');

      // toJson is the exact object written to LivingScroll.json's key_events[]:
      // only name + uuid + (default) state — no description.
      expect(controller.toJson(), [
        {
          'name': 'Met the duke',
          'key_event_uuid': 'kev-1',
          'state': 'unchecked',
        }
      ]);
    });

    test('each new event gets its own uuid', () {
      var n = 0;
      final controller = KeyEventsController(newId: () => 'kev-${++n}');
      controller.loadFrom({'key_events': []});

      controller.beginNew();
      controller.editName = 'A';
      controller.save();
      controller.beginNew();
      controller.editName = 'B';
      controller.save();

      expect(controller.events.map((e) => e.uuid), ['kev-1', 'kev-2']);
    });

    test('fromJson reads key_event_uuid + state; renaming preserves both', () {
      final controller = KeyEventsController(newId: () => 'should-not-be-used');
      controller.loadFrom({
        'key_events': [
          {
            'name': 'Met the duke',
            'key_event_uuid': 'existing-uuid',
            'state': 'checked',
          }
        ],
      });
      expect(controller.events.single.uuid, 'existing-uuid');
      expect(controller.events.single.checked, isTrue);

      // Renaming keeps the durable uuid and the app-managed state.
      controller.beginEdit('Met the duke');
      controller.editName = 'Met the duchess';
      expect(controller.save(), isTrue);

      expect(controller.toJson().single, {
        'name': 'Met the duchess',
        'key_event_uuid': 'existing-uuid',
        'state': 'checked',
      });
    });

    test('a duplicate name is rejected (no new uuid minted)', () {
      var minted = 0;
      final controller = KeyEventsController(newId: () => 'kev-${++minted}');
      controller.loadFrom({
        'key_events': [
          {'name': 'a', 'key_event_uuid': 'u1', 'state': 'unchecked'}
        ],
      });

      controller.beginNew();
      controller.editName = 'a';
      expect(controller.save(), isFalse);
      expect(controller.events.length, 1);
      expect(minted, 0);
    });

    test('isDirty tracks only the name', () {
      final controller = KeyEventsController(newId: () => 'kev-1');
      controller.loadFrom({
        'key_events': [
          {'name': 'a', 'key_event_uuid': 'u1', 'state': 'unchecked'}
        ],
      });
      controller.beginEdit('a');
      expect(controller.isDirty, isFalse);
      controller.editName = 'b';
      expect(controller.isDirty, isTrue);
    });
  });
}
