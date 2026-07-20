import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/adventure_importer.dart';

void main() {
  const importer = AdventureImporter();

  // `notes` is used as the representative plain collection (append + dedup by
  // note_uuid); the scene's background is a single `bg_image` FILE reference
  // (images/bg_images/<uuid>.png) — not a collection member, so it is kept verbatim.
  Map<String, dynamic> target({String system = 'basic'}) => {
        'metadata': {'name': 'Target', 'system': system},
        'npcs': [],
        'key_events': [],
        'notes': [
          {'note_uuid': 'N0', 'note_name': 'Home', 'note_content': ''}
        ],
        'gm_notes': [],
        'images': [],
        'audio': [],
        'paths': [],
        'scenes': [],
      };

  Map<String, dynamic> importDoc({String system = 'basic'}) => {
        'metadata': {'name': 'Pack', 'system': system},
        'npcs': [
          {'npc_uuid': 'P1', 'name': 'Guard'}
        ],
        'key_events': [
          {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'}
        ],
        'notes': [
          {'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': 'x'}
        ],
        'images': [
          {'image_uuid': 'i1', 'name': 'Map'}
        ],
        'audio': [
          {'audio_uuid': 'a1', 'name': 'Theme'}
        ],
        'paths': [
          {'name': 'Main', 'color': 'yellow', 'description': ''}
        ],
        'scenes': [
          {
            'scene_uuid': 's1',
            'name': 'Cave scene',
            'scene_type': 'standard',
            'bg_image': 'bg1',
            'npcs': ['Guard'],
            'key_events': ['Met duke'],
            'path_names': ['Main'],
            'notes': ['N1'],
            'images': ['i1'],
            'audio': ['a1'],
            'next_scenes': ['tower-uuid'],
            'visibility_rules': {
              'op': 'or',
              'key_events': ['k1']
            },
          }
        ],
      };

  List<Map> coll(Map<String, dynamic> doc, String key) =>
      (doc[key] as List).cast<Map>();

  group('analyze', () {
    test('lists present categories with counts and same-system flag', () {
      final a = importer.analyze(importDoc(), target());
      expect(a.sameSystem, isTrue);
      expect(a.present, [
        'npcs',
        'key_events',
        'notes',
        'images',
        'audio',
        'paths',
        'scenes',
      ]);
      expect(a.counts['notes'], 1);
      expect(a.counts['scenes'], 1);
      // gm_notes empty -> absent.
      expect(a.present.contains('gm_notes'), isFalse);
      // Per-element items carry a stable id + a display label.
      expect(a.items['notes']!.single.id, 'N1');
      expect(a.items['notes']!.single.label, 'Cave'); // note_name
      expect(a.items['paths']!.single.id, 'yellow'); // path identity = colour
    });

    test('different system => npcs skipped entirely (not listed)', () {
      final a = importer.analyze(importDoc(system: '7thsea2e'), target());
      expect(a.sameSystem, isFalse);
      expect(a.present.contains('npcs'), isFalse); // not shown at all
      expect(a.items.containsKey('npcs'), isFalse);
      expect(a.present.contains('notes'), isTrue); // others still shown
      expect(a.defaultSelection.containsKey('npcs'), isFalse);
    });

    test('skips an element whose uuid already exists in the target', () {
      final tgt = target();
      // The import's note N1 is already in the target.
      (tgt['notes'] as List)
          .add({'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': ''});
      final a = importer.analyze(importDoc(), tgt);
      // notes fully covered -> category dropped; others still present.
      expect(a.present.contains('notes'), isFalse);
      expect(a.items.containsKey('notes'), isFalse);
      expect(a.present.contains('npcs'), isTrue);
    });

    test('lists only the NEW elements within a partially-overlapping category',
        () {
      final imp = importDoc();
      (imp['notes'] as List)
          .add({'note_uuid': 'N2', 'note_name': 'Tower', 'note_content': ''});
      final tgt = target(); // already has N0; import has N1 (new) + N2 (new)
      (tgt['notes'] as List)
          .add({'note_uuid': 'N1', 'note_name': 'Cave', 'note_content': ''});
      final a = importer.analyze(imp, tgt);
      // N1 already exists -> only N2 is offered.
      expect(a.items['notes']!.map((it) => it.id), ['N2']);
      expect(a.counts['notes'], 1);
    });

    test('isEmpty when every element already exists or is incompatible', () {
      final imp = importDoc();
      // Target already carries everything the import does (same identities).
      final tgt = <String, dynamic>{
        'metadata': {'name': 'T', 'system': 'basic'},
        for (final c in const [
          'npcs',
          'key_events',
          'notes',
          'images',
          'audio',
          'paths',
          'scenes',
        ])
          c: List<dynamic>.of(imp[c] as List),
      };
      final a = importer.analyze(imp, tgt);
      expect(a.isEmpty, isTrue);
      expect(a.present, isEmpty);
      expect(a.defaultSelection, isEmpty);
    });
  });

  group('merge — plain collections', () {
    test('appends selected collections preserving uuids; leaves target intact',
        () {
      final tgt = target();
      final merged = importer.merge(
        tgt,
        importDoc(),
        {
          'notes': {'N1'},
          'npcs': {'P1'},
          'key_events': {'k1'},
        },
        sameSystem: true,
      );
      // Target not mutated.
      expect((tgt['notes'] as List).length, 1);
      // Notes: original + imported, uuid preserved.
      final notes = coll(merged, 'notes');
      expect(notes.map((e) => e['note_uuid']), ['N0', 'N1']);
      expect(coll(merged, 'npcs').single['npc_uuid'], 'P1');
      expect(coll(merged, 'key_events').single['key_event_uuid'], 'k1');
      // Not selected -> not merged.
      expect(coll(merged, 'images'), isEmpty);
      expect(coll(merged, 'paths'), isEmpty);
    });

    test('imports only the individually selected elements', () {
      // The import carries several categories, but the user selected a SINGLE
      // element (one note). Only that one is merged; nothing else.
      final merged = importer.merge(
        target(),
        importDoc(),
        {
          'notes': {'N1'}
        },
        sameSystem: true,
      );
      expect(coll(merged, 'notes').map((e) => e['note_uuid']),
          ['N0', 'N1']); // pre-existing + the one selected
      expect(coll(merged, 'npcs'), isEmpty);
      expect(coll(merged, 'key_events'), isEmpty);
      expect(coll(merged, 'paths'), isEmpty);
      expect(coll(merged, 'scenes'), isEmpty);
    });

    test('imports one of several elements within a category', () {
      // A notes collection with two entries; only one id is selected.
      final imp = importDoc();
      (imp['notes'] as List)
          .add({'note_uuid': 'N2', 'note_name': 'Tower', 'note_content': ''});
      final merged = importer.merge(
        target(),
        imp,
        {
          'notes': {'N2'}
        },
        sameSystem: true,
      );
      // Only N2 is brought in (N1 was not selected); N0 pre-exists.
      expect(coll(merged, 'notes').map((e) => e['note_uuid']), ['N0', 'N2']);
    });

    test('skips an imported element whose uuid already exists in the target', () {
      // Target already carries note "N0"; the import also carries an "N0"
      // (plus a fresh "N1"). Only the new one is appended; "N0" is not doubled.
      final tgt = target();
      final imp = importDoc();
      (imp['notes'] as List).insert(
          0, {'note_uuid': 'N0', 'note_name': 'Home (copy)', 'note_content': ''});
      final merged = importer.merge(
        tgt,
        imp,
        {
          'notes': {'N0', 'N1'}
        },
        sameSystem: true,
      );
      final notes = coll(merged, 'notes');
      expect(notes.map((e) => e['note_uuid']), ['N0', 'N1']); // no second N0
      // The existing target entry wins (the imported "N0" copy is dropped).
      expect(notes.first['note_name'], 'Home');
    });

    test('re-merging the same import is idempotent (no duplication)', () {
      const sel = {
        'notes': {'N1'},
        'npcs': {'P1'},
        'paths': {'yellow'},
      };
      final once = importer.merge(target(), importDoc(), sel, sameSystem: true);
      final twice = importer.merge(once, importDoc(), sel, sameSystem: true);
      expect(coll(twice, 'notes').map((e) => e['note_uuid']), ['N0', 'N1']);
      expect(coll(twice, 'npcs').length, 1);
      expect(coll(twice, 'paths').length, 1); // paths dedup by colour
    });

    test('npcs are excluded across systems even if selected', () {
      final merged = importer.merge(
        target(),
        importDoc(system: '7thsea2e'),
        {
          'npcs': {'P1'},
          'notes': {'N1'},
        },
        sameSystem: false,
      );
      expect(coll(merged, 'npcs'), isEmpty);
      expect(coll(merged, 'notes').length, 2); // notes still imported
    });
  });

  group('merge — scenes', () {
    test('strips next_scenes and keeps links present in the merged target', () {
      // Select everything the scene links to, so all links survive.
      final merged = importer.merge(
        target(),
        importDoc(),
        {
          'notes': {'N1'},
          'npcs': {'P1'},
          'key_events': {'k1'},
          'images': {'i1'},
          'audio': {'a1'},
          'paths': {'yellow'},
          'scenes': {'s1'},
        },
        sameSystem: true,
      );
      final scene = coll(merged, 'scenes').single;
      expect(scene.containsKey('next_scenes'), isFalse); // always dropped
      expect(scene['scene_uuid'], 's1'); // uuid preserved
      expect(scene['bg_image'], 'bg1'); // bg_image is a file ref -> kept verbatim
      expect(scene['npcs'], ['Guard']);
      expect(scene['key_events'], ['Met duke']);
      expect(scene['path_names'], ['Main']);
      expect(scene['notes'], ['N1']);
      expect(scene['images'], ['i1']);
      expect(scene['audio'], ['a1']);
      expect((scene['visibility_rules'] as Map)['key_events'], ['k1']);
    });

    test('drops links whose targets were not imported', () {
      // Import ONLY scenes: none of the linked elements exist in the target.
      final merged = importer.merge(
        target(),
        importDoc(),
        {'scenes': {'s1'}},
        sameSystem: true,
      );
      final scene = coll(merged, 'scenes').single;
      expect(scene.containsKey('next_scenes'), isFalse);
      expect(scene['bg_image'], 'bg1'); // bg_image is a file ref -> kept verbatim
      expect(scene['npcs'], isEmpty);
      expect(scene['key_events'], isEmpty);
      expect(scene['path_names'], isEmpty);
      expect(scene['notes'], isEmpty);
      expect(scene['images'], isEmpty);
      expect(scene['audio'], isEmpty);
      // Whole gate dropped (its only key event is absent).
      expect(scene.containsKey('visibility_rules'), isFalse);
    });

    test('bg_image is a file reference, kept verbatim regardless of collections',
        () {
      // bg_image is NOT a collection member (it names a file in
      // images/bg_images/), so the merge never blanks it — its file is copied
      // alongside the scene by ProjectsStore, not by the JSON merge.
      final imp = importDoc();
      (imp['scenes'] as List)[0]['bg_image'] = 'someBg';
      final merged = importer.merge(
        target(),
        imp,
        {'scenes': {'s1'}},
        sameSystem: true,
      );
      expect(coll(merged, 'scenes').single['bg_image'], 'someBg');
    });

    test('a scene whose scene_uuid already exists is not duplicated', () {
      const sel = {
        'scenes': {'s1'}
      };
      final once = importer.merge(target(), importDoc(), sel, sameSystem: true);
      final twice = importer.merge(once, importDoc(), sel, sameSystem: true);
      expect(coll(twice, 'scenes').map((e) => e['scene_uuid']), ['s1']);
    });

    test('partial: keeps only the subset of links whose elements are present',
        () {
      // Import notes + key_events + scenes, but NOT npcs/images/audio/...
      final merged = importer.merge(
        target(),
        importDoc(),
        {
          'notes': {'N1'},
          'key_events': {'k1'},
          'scenes': {'s1'},
        },
        sameSystem: true,
      );
      final scene = coll(merged, 'scenes').single;
      expect(scene['notes'], ['N1']); // imported
      expect(scene['key_events'], ['Met duke']); // imported
      expect(scene['bg_image'], 'bg1'); // bg_image is a file ref -> kept verbatim
      expect(scene['npcs'], isEmpty); // not imported
      expect(scene['path_names'], isEmpty);
      expect((scene['visibility_rules'] as Map)['key_events'], ['k1']); // k1 imported
    });
  });
}
