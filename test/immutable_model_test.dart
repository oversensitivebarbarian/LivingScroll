import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/images/adventure_image.dart';
import 'package:living_scroll/keyevents/key_event.dart';
import 'package:living_scroll/notes/note.dart';
import 'package:living_scroll/npcs/npc.dart';
import 'package:living_scroll/paths/paths_controller.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/soundtracks/soundtrack.dart';

/// The `immutable` runtime flag must round-trip through every
/// collection model's fromJson/toJson, be written ONLY when true (so projects and
/// exports never gain it), and coexist with the other runtime fields
/// (visited/seen/state) without dropping them.
void main() {
  group('immutable round-trips', () {
    test('Scene: immutable + visited/state preserved, omitted when false', () {
      final base = Scene.fromJson({
        'scene_uuid': 's1',
        'name': 'Room',
        'scene_type': 'standard',
        'next_scenes': ['s2'],
        'visited': true, // runtime field -> extra
        'immutable': true,
      });
      expect(base.immutable, isTrue);
      final back = Scene.fromJson(base.toJson());
      expect(back.immutable, isTrue);
      expect(back.toJson()['immutable'], isTrue);
      expect(back.toJson()['visited'], isTrue); // preserved via extra
      expect(back.nextSceneUuids, ['s2']);

      // A fresh (project) scene never writes the flag.
      final mutable = Scene(uuid: 's3', name: 'New');
      expect(mutable.immutable, isFalse);
      expect(mutable.toJson().containsKey('immutable'), isFalse);
    });

    test('Npc: immutable + state + extra (stats) preserved', () {
      final npc = Npc.fromJson({
        'npc_uuid': 'n1',
        'name': 'Guard',
        'state': 'inactive',
        'stats': {'hp': 10}, // unknown key -> extra
        'immutable': true,
      });
      final back = Npc.fromJson(npc.toJson());
      expect(back.immutable, isTrue);
      expect(back.state, 'inactive');
      expect(back.extra['stats'], {'hp': 10});
      expect(back.toJson()['immutable'], isTrue);

      expect(
        Npc(uuid: 'n2', name: 'X').toJson().containsKey('immutable'),
        isFalse,
      );
    });

    test('Note: immutable + seen (runtime) preserved via extra', () {
      final note = Note.fromJson({
        'note_uuid': 'no1',
        'note_name': 'Clue',
        'note_content': 'text',
        'seen': true, // runtime -> extra
        'immutable': true,
      });
      final back = Note.fromJson(note.toJson());
      expect(back.immutable, isTrue);
      expect(back.toJson()['seen'], isTrue);
      expect(back.toJson()['immutable'], isTrue);

      expect(Note(uuid: 'no2').toJson().containsKey('immutable'), isFalse);
    });

    test('AdventureImage: immutable + seen preserved via extra', () {
      final img = AdventureImage.fromJson({
        'image_uuid': 'i1',
        'name': 'Map',
        'seen': true,
        'immutable': true,
      });
      final back = AdventureImage.fromJson(img.toJson());
      expect(back.immutable, isTrue);
      expect(back.toJson()['seen'], isTrue);

      expect(
        AdventureImage(uuid: 'i2').toJson().containsKey('immutable'),
        isFalse,
      );
    });

    test('KeyEvent: immutable + checked state preserved', () {
      final ev = KeyEvent.fromJson({
        'key_event_uuid': 'k1',
        'name': 'Alarm',
        'state': 'checked',
        'immutable': true,
      });
      final back = KeyEvent.fromJson(ev.toJson());
      expect(back.immutable, isTrue);
      expect(back.checked, isTrue);
      expect(back.toJson()['state'], 'checked');

      expect(
        KeyEvent(uuid: 'k2', name: 'B').toJson().containsKey('immutable'),
        isFalse,
      );
    });

    test('Soundtrack: immutable preserved, omitted when false', () {
      final s = Soundtrack.fromJson({
        'audio_uuid': 'a1',
        'name': 'Theme',
        'immutable': true,
      });
      final back = Soundtrack.fromJson(s.toJson());
      expect(back.immutable, isTrue);

      expect(
        Soundtrack(uuid: 'a2', name: 'T').toJson().containsKey('immutable'),
        isFalse,
      );
    });

    test('PathsController: immutable round-trips per colour', () {
      final c = PathsController(['red', 'blue']);
      c.loadFrom({
        'paths': [
          {
            'name': 'Bloody',
            'color': 'red',
            'description': 'd',
            'immutable': true,
          },
          {'name': 'Calm', 'color': 'blue', 'description': 'd2'}, // no flag
        ],
      });
      final json = c.toJson();
      final red = json.firstWhere((p) => p['color'] == 'red');
      final blue = json.firstWhere((p) => p['color'] == 'blue');
      expect(red['immutable'], isTrue);
      expect(blue.containsKey('immutable'), isFalse);

      // Re-load the written form: the flag survives.
      final c2 = PathsController(['red', 'blue']);
      c2.loadFrom({'paths': json});
      final json2 = c2.toJson();
      expect(json2.firstWhere((p) => p['color'] == 'red')['immutable'], isTrue);
    });
  });
}
