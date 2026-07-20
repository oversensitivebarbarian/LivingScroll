import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/publish_validator.dart';

void main() {
  const validator = PublishValidator();

  Set<PublishIssueCode> codes(Map<String, dynamic> doc) =>
      {for (final i in validator.validate(doc)) i.code};

  Map<String, dynamic> metadata() => {
        'name': 'Adventure',
        'system': 'basic',
        'version': '1.0.0',
        'author': 'Author',
        'description': 'A tale.',
        'language': 'en',
        'content_warnings': 'none',
        'license': 'CC-BY',
      };

  // A minimal publishable adventure: complete metadata, a start that leads
  // (unconditionally) to an end.
  Map<String, dynamic> validDoc({List<Object>? scenes}) => {
        'metadata': metadata(),
        'images': [],
        'audio': [],
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': scenes ??
            [
              {
                'scene_uuid': 's1',
                'name': 'Start',
                'scene_type': 'start',
                'next_scenes': ['s2'],
              },
              {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
            ],
      };

  test('a complete adventure has no publish issues', () {
    expect(validator.validate(validDoc()), isEmpty);
    expect(validator.isValid(validDoc()), isTrue);
  });

  group('metadata', () {
    // content_warnings is intentionally absent: it is OPTIONAL to publish.
    for (final field in const [
      'name',
      'system',
      'version',
      'author',
      'description',
      'language',
      'license',
    ]) {
      test('missing "$field" is reported', () {
        final doc = validDoc();
        (doc['metadata'] as Map).remove(field);
        final issue = validator
            .validate(doc)
            .firstWhere((i) => i.code == PublishIssueCode.adventureFieldMissing);
        expect(issue.keySubject, field);
      });
    }

    test('content_warnings is optional — its absence is publishable', () {
      final missing = validDoc();
      (missing['metadata'] as Map).remove('content_warnings');
      expect(validator.validate(missing), isEmpty);

      final empty = validDoc();
      (empty['metadata'] as Map)['content_warnings'] = '';
      expect(validator.validate(empty), isEmpty);
    });
  });

  group('entity required fields', () {
    test('an NPC missing a portrait image is incomplete', () {
      final doc = validDoc();
      doc['npcs'] = [
        {
          'npc_uuid': 'p1',
          'name': 'Guard',
          'full_image': 'f1',
          // icon_image missing
          'description': 'd',
        }
      ];
      expect(codes(doc), contains(PublishIssueCode.npcIncomplete));
    });

    test('a complete NPC passes', () {
      final doc = validDoc();
      doc['npcs'] = [
        {
          'npc_uuid': 'p1',
          'name': 'Guard',
          'full_image': 'f1',
          'icon_image': 'i1',
        }
      ];
      expect(codes(doc), isNot(contains(PublishIssueCode.npcIncomplete)));
    });

    test('a note without a name is incomplete', () {
      final doc = validDoc();
      doc['notes'] = [
        {'note_uuid': 'n1', 'note_name': '', 'note_content': 'x'}
      ];
      expect(codes(doc), contains(PublishIssueCode.noteIncomplete));
    });

    test('a note without content is incomplete', () {
      final doc = validDoc();
      doc['notes'] = [
        {'note_uuid': 'n1', 'note_name': 'Clue', 'note_content': ''}
      ];
      expect(codes(doc), contains(PublishIssueCode.noteIncomplete));
    });

    test('a note with a name and content passes', () {
      final doc = validDoc();
      doc['notes'] = [
        {'note_uuid': 'n1', 'note_name': 'Clue', 'note_content': 'A lever.'}
      ];
      expect(codes(doc), isNot(contains(PublishIssueCode.noteIncomplete)));
    });
  });

  group('scene structure', () {
    test('no start scene is reported', () {
      final doc = validDoc(scenes: [
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(codes(doc), contains(PublishIssueCode.noStartScene));
    });

    test('no end scene is reported', () {
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s1'],
        },
      ]);
      expect(codes(doc), contains(PublishIssueCode.noEndScene));
    });

    test('an end scene with a next scene is reported', () {
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s2'],
        },
        {
          'scene_uuid': 's2',
          'name': 'End',
          'scene_type': 'end',
          'next_scenes': ['s1'],
        },
      ]);
      final issue = validator
          .validate(doc)
          .firstWhere((i) => i.code == PublishIssueCode.endSceneHasNext);
      expect(issue.keySubject, 'End');
    });

    test('a non-end scene with no next scene is reported', () {
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3', 's2'],
        },
        {'scene_uuid': 's3', 'name': 'Mid', 'scene_type': 'standard'},
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final issue = validator
          .validate(doc)
          .firstWhere((i) => i.code == PublishIssueCode.nonEndSceneNoNext);
      expect(issue.keySubject, 'Mid');
    });

    test('next-scene links resolve by scene_uuid, surviving a target rename', () {
      // Start -> End by uuid ("s2"); the End scene's NAME is unrelated to the
      // link, so renaming it can never break reachability. The graph validates.
      final renamed = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s2'],
        },
        {
          'scene_uuid': 's2',
          'name': 'A Wholly Renamed Finale',
          'scene_type': 'end',
        },
      ]);
      expect(validator.validate(renamed), isEmpty);

      // Contrast: had the link stored the NAME ("End"), renaming the target to
      // "A Wholly Renamed Finale" would orphan it — the start would have no
      // reachable, unconditional next, breaking the path to the end. This is the
      // exact breakage the uuid storage prevents.
      final byName = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['End'], // stale name -> no matching scene_uuid
        },
        {
          'scene_uuid': 's2',
          'name': 'A Wholly Renamed Finale',
          'scene_type': 'end',
        },
      ]);
      final broken = codes(byName);
      expect(broken, contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
      expect(broken, contains(PublishIssueCode.noUnconditionalPathToEnd));
    });
  });

  group('conditional-scene playability', () {
    // "Cond" carries a visibility gate, so it is a conditional scene.
    Map<String, dynamic> conditional(String uuid, String name,
            {List<String> next = const []}) =>
        {
          'scene_uuid': uuid,
          'name': name,
          'scene_type': 'standard',
          'next_scenes': next,
          'visibility_rules': {
            'op': 'or',
            'key_events': ['k1'],
          },
        };

    test('a non-end scene whose only next scene is conditional is reported', () {
      // Start reaches End unconditionally (no path issue), but "Mid" can only go
      // to a conditional scene.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s2'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Mid',
          'scene_type': 'standard',
          'next_scenes': ['s4'],
        },
        conditional('s4', 'Cond', next: ['s2']),
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
      // The Start->End route keeps the adventure reachable.
      expect(found, isNot(contains(PublishIssueCode.noUnconditionalPathToEnd)));
    });

    test('no always-available path to an end is reported', () {
      // Every non-end scene has an unconditional next, but they cycle and never
      // reach the (disconnected) end without a gate.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Loop',
          'scene_type': 'standard',
          'next_scenes': ['s1'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.noUnconditionalPathToEnd));
      expect(
          found, isNot(contains(PublishIssueCode.nonEndSceneOnlyConditionalNext)));
    });

    test('a conditional scene ON the only path to the end fails reachability', () {
      // Start -> Cond -> End: with Cond hidden there is no way through.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s4'],
        },
        conditional('s4', 'Cond', next: ['s2']),
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.noUnconditionalPathToEnd));
      // Start's only next (Cond) is conditional, too.
      expect(found, contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
    });

    test('an unconditional path to the end passes', () {
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Mid',
          'scene_type': 'standard',
          'next_scenes': ['s2'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(validator.validate(doc), isEmpty);
    });
  });

  group('named story paths (paths[] tagged onto scenes via path_names)', () {
    // A gated (conditional) scene, mirroring the helper in the
    // 'conditional-scene playability' group above.
    Map<String, dynamic> conditional(String uuid, String name,
            {List<String> next = const []}) =>
        {
          'scene_uuid': uuid,
          'name': name,
          'scene_type': 'standard',
          'next_scenes': next,
          'visibility_rules': {
            'op': 'or',
            'key_events': ['k1'],
          },
        };

    // A doc with an adventure-wide start/end (so the adventure-wide checks
    // stay green) plus a named path and its own scenes.
    Map<String, dynamic> pathDoc({
      required List<Map<String, dynamic>> pathScenes,
      List<Object>? extraPaths,
    }) =>
        validDoc(scenes: [
          {
            'scene_uuid': 'gs1',
            'name': 'Global Start',
            'scene_type': 'start',
            'next_scenes': ['gs2'],
          },
          {'scene_uuid': 'gs2', 'name': 'Global End', 'scene_type': 'end'},
          ...pathScenes,
        ])
          ..['paths'] = [
            {'name': 'Red Path', 'color': '#D22828', 'description': 'd'},
            ...?extraPaths,
          ];

    test('a path with no scene tagged onto it at all is reported for both '
        'start and end', () {
      final doc = pathDoc(pathScenes: []);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.pathNoStartScene));
      expect(found, contains(PublishIssueCode.pathNoEndScene));
      expect(found, isNot(contains(PublishIssueCode.pathNoUnconditionalRouteToEnd)));
    });

    test('a path with only a start scene tagged is missing an end', () {
      final doc = pathDoc(pathScenes: [
        {
          'scene_uuid': 'p1',
          'name': 'Path Start',
          'scene_type': 'start',
          'path_names': ['Red Path'],
        },
      ]);
      final found = codes(doc);
      expect(found, isNot(contains(PublishIssueCode.pathNoStartScene)));
      expect(found, contains(PublishIssueCode.pathNoEndScene));
    });

    test('a path with only an end scene tagged is missing a start', () {
      final doc = pathDoc(pathScenes: [
        {
          'scene_uuid': 'p2',
          'name': 'Path End',
          'scene_type': 'end',
          'path_names': ['Red Path'],
        },
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.pathNoStartScene));
      expect(found, isNot(contains(PublishIssueCode.pathNoEndScene)));
    });

    test('a route through the path\'s OWN scenes passes', () {
      final doc = pathDoc(pathScenes: [
        {
          'scene_uuid': 'p1',
          'name': 'Path Start',
          'scene_type': 'start',
          'path_names': ['Red Path'],
          'next_scenes': ['p3'],
        },
        {
          'scene_uuid': 'p3',
          'name': 'Path Mid',
          'scene_type': 'standard',
          'path_names': ['Red Path'],
          'next_scenes': ['p2'],
        },
        {
          'scene_uuid': 'p2',
          'name': 'Path End',
          'scene_type': 'end',
          'path_names': ['Red Path'],
        },
      ]);
      final found = codes(doc);
      expect(found, isNot(contains(PublishIssueCode.pathNoStartScene)));
      expect(found, isNot(contains(PublishIssueCode.pathNoEndScene)));
      expect(
          found, isNot(contains(PublishIssueCode.pathNoUnconditionalRouteToEnd)));
    });

    test('a route that leaves the path\'s own scenes does not count, even '
        'though the adventure-wide graph connects', () {
      // Path Start -> Connector (untagged) -> Path End: the connector is NOT
      // tagged onto Red Path, so the path-scoped route must fail even though
      // the adventure-wide (untagged) reachability would succeed.
      final doc = pathDoc(pathScenes: [
        {
          'scene_uuid': 'p1',
          'name': 'Path Start',
          'scene_type': 'start',
          'path_names': ['Red Path'],
          'next_scenes': ['c1'],
        },
        {
          'scene_uuid': 'c1',
          'name': 'Connector',
          'scene_type': 'standard',
          'next_scenes': ['p2'],
        },
        {
          'scene_uuid': 'p2',
          'name': 'Path End',
          'scene_type': 'end',
          'path_names': ['Red Path'],
        },
      ]);
      final found = codes(doc);
      expect(found, isNot(contains(PublishIssueCode.pathNoStartScene)));
      expect(found, isNot(contains(PublishIssueCode.pathNoEndScene)));
      expect(found, contains(PublishIssueCode.pathNoUnconditionalRouteToEnd));
    });

    test('a path whose only route is conditional fails reachability', () {
      final doc = pathDoc(pathScenes: [
        {
          'scene_uuid': 'p1',
          'name': 'Path Start',
          'scene_type': 'start',
          'path_names': ['Red Path'],
          'next_scenes': ['p4'],
        },
        {
          ...conditional('p4', 'Path Cond', next: ['p2']),
          'path_names': ['Red Path'],
        },
        {
          'scene_uuid': 'p2',
          'name': 'Path End',
          'scene_type': 'end',
          'path_names': ['Red Path'],
        },
      ]);
      expect(codes(doc), contains(PublishIssueCode.pathNoUnconditionalRouteToEnd));
    });

    test('an unnamed path (name absent/empty) is skipped entirely', () {
      final doc = validDoc()
        ..['paths'] = [
          {'name': '', 'color': '#1EA0DC', 'description': 'unused'},
        ];
      expect(validator.validate(doc), isEmpty);
    });
  });

  group('forced conditional (treated as unconditional)', () {
    // Attaches the key_events[] that the gate's uuids resolve to.
    Map<String, dynamic> docWith(List<Object> scenes,
        {List<Object>? keyEvents}) {
      final doc = validDoc(scenes: scenes);
      doc['key_events'] = keyEvents ??
          [
            {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'}
          ];
      return doc;
    }

    // A conditional scene gated on k1 ("Met duke").
    Map<String, dynamic> cond(String uuid, String name,
            {required List<String> next}) =>
        {
          'scene_uuid': uuid,
          'name': name,
          'scene_type': 'standard',
          'next_scenes': next,
          'visibility_rules': {
            'op': 'or',
            'key_events': ['k1'],
          },
        };

    test('a sole next of a key-holding predecessor counts as unconditional', () {
      // Start holds "Met duke" and its ONLY next is the gated Cond -> Cond is
      // guaranteed, so the adventure is valid.
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'key_events': ['Met duke'],
          'next_scenes': ['s3'],
        },
        cond('s3', 'Cond', next: ['s2']),
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(validator.validate(doc), isEmpty);
    });

    test('without the key event in the predecessor it stays conditional', () {
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          // no key_events -> the gate can never be satisfied at the predecessor
          'next_scenes': ['s3'],
        },
        cond('s3', 'Cond', next: ['s2']),
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
      expect(found, contains(PublishIssueCode.noUnconditionalPathToEnd));
    });

    test('with more than one predecessor it is NOT forced', () {
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'StartA',
          'scene_type': 'start',
          'key_events': ['Met duke'],
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's4',
          'name': 'StartB',
          'scene_type': 'start',
          'key_events': ['Met duke'],
          'next_scenes': ['s3'],
        },
        cond('s3', 'Cond', next: ['s2']),
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final found = codes(doc);
      expect(found, contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
      expect(found, contains(PublishIssueCode.noUnconditionalPathToEnd));
    });

    test('when the conditional is not the predecessor\'s ONLY next it is not forced',
        () {
      // Start -> [Cond, Other]; Other is unconditional so the adventure is still
      // valid, but Cond itself was NOT forced (Start has a second next).
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'key_events': ['Met duke'],
          'next_scenes': ['s5', 's4'],
        },
        // A scene whose ONLY next is Cond, but which does NOT hold the key event.
        {
          'scene_uuid': 's5',
          'name': 'Detour',
          'scene_type': 'standard',
          'next_scenes': ['s3'],
        },
        cond('s3', 'Cond', next: ['s2']),
        {
          'scene_uuid': 's4',
          'name': 'Other',
          'scene_type': 'standard',
          'next_scenes': ['s2'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      // Detour's only next is the (unforced) conditional Cond -> Detour is stuck.
      expect(codes(doc),
          contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
    });

    test('an `and` gate needs EVERY event in the predecessor', () {
      // Cond gated on k1 AND k2; Start holds only k1 -> NOT forced.
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'key_events': ['Met duke'],
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Cond',
          'scene_type': 'standard',
          'next_scenes': ['s2'],
          'visibility_rules': {
            'op': 'and',
            'key_events': ['k1', 'k2'],
          },
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ], keyEvents: [
        {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        {'key_event_uuid': 'k2', 'name': 'Found map', 'state': 'unchecked'},
      ]);
      expect(codes(doc),
          contains(PublishIssueCode.nonEndSceneOnlyConditionalNext));
    });

    test('an `and` gate IS forced when the predecessor holds every event', () {
      final doc = docWith([
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'key_events': ['Met duke', 'Found map'],
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Cond',
          'scene_type': 'standard',
          'next_scenes': ['s2'],
          'visibility_rules': {
            'op': 'and',
            'key_events': ['k1', 'k2'],
          },
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ], keyEvents: [
        {'key_event_uuid': 'k1', 'name': 'Met duke', 'state': 'unchecked'},
        {'key_event_uuid': 'k2', 'name': 'Found map', 'state': 'unchecked'},
      ]);
      expect(validator.validate(doc), isEmpty);
    });
  });

  group('blind loops (dead next_scenes cycles)', () {
    Set<String?> blindSubjects(Map<String, dynamic> doc) => {
          for (final i in validator.validate(doc))
            if (i.code == PublishIssueCode.blindLoop) i.keySubject
        };

    test('a cycle through standard scenes is a blind-loop breaker', () {
      // Start -> A -> B -> A: B loops back to the already-visited A.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'A',
          'scene_type': 'standard',
          'next_scenes': ['s4'],
        },
        {
          'scene_uuid': 's4',
          'name': 'B',
          'scene_type': 'standard',
          'next_scenes': ['s3'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(blindSubjects(doc), containsAll(<String>['A', 'B']));
      expect(validator.isValid(doc), isFalse);
    });

    test('a self-loop is a blind loop', () {
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Stuck',
          'scene_type': 'standard',
          'next_scenes': ['s3'], // points to itself
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(blindSubjects(doc), contains('Stuck'));
    });

    test('a RECURRING scene may sit on a cycle (no blind loop)', () {
      // HubA <-> HubB are both recurring (re-enterable); HubA also exits to End.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'HubA',
          'scene_type': 'recurring',
          'next_scenes': ['s4', 's2'],
        },
        {
          'scene_uuid': 's4',
          'name': 'HubB',
          'scene_type': 'recurring',
          'next_scenes': ['s3'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      expect(blindSubjects(doc), isEmpty);
      expect(validator.validate(doc), isEmpty);
    });

    test('a standard scene looping through a recurring hub is still a blind loop',
        () {
      // Side -> Hub(recurring) -> Side: Side (standard) is revisited -> breaker,
      // even though the hub itself is allowed.
      final doc = validDoc(scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Start',
          'scene_type': 'start',
          'next_scenes': ['s4'],
        },
        {
          'scene_uuid': 's4',
          'name': 'Side',
          'scene_type': 'standard',
          'next_scenes': ['s3'],
        },
        {
          'scene_uuid': 's3',
          'name': 'Hub',
          'scene_type': 'recurring',
          'next_scenes': ['s4', 's2'],
        },
        {'scene_uuid': 's2', 'name': 'End', 'scene_type': 'end'},
      ]);
      final blind = blindSubjects(doc);
      expect(blind, contains('Side'));
      expect(blind, isNot(contains('Hub'))); // recurring hub is allowed
    });
  });

  group('PartExportValidator (name + system only)', () {
    const part = PartExportValidator();

    Set<String?> fields(Map<String, dynamic> doc) =>
        {for (final i in part.validate(doc)) i.keySubject};

    test('passes with just a name and a system (no other checks)', () {
      // No scenes at all, incomplete metadata — but name + system are present.
      final doc = {
        'metadata': {'name': 'Demo', 'system': 'basic'},
        'scenes': [],
      };
      expect(part.validate(doc), isEmpty);
      expect(part.isValid(doc), isTrue);
    });

    test('reports a missing name', () {
      final doc = {
        'metadata': {'name': '', 'system': 'basic'},
      };
      expect(fields(doc), contains('name'));
      expect(fields(doc), isNot(contains('system')));
    });

    test('reports a missing system', () {
      final doc = {
        'metadata': {'name': 'Demo'},
      };
      expect(fields(doc), contains('system'));
      expect(fields(doc), isNot(contains('name')));
    });

    test('does NOT enforce the full publish rules (scenes, npcs, …)', () {
      // A doc that the full PublishValidator rejects (no scenes) still passes the
      // partial gate as long as name + system are set.
      final doc = {
        'metadata': {'name': 'Demo', 'system': 'basic'},
      };
      expect(const PublishValidator().validate(doc), isNotEmpty);
      expect(part.validate(doc), isEmpty);
    });
  });
}
