// MINIMUM-WINDOW-SIZE integration guard (app shell + game editor).
//
// Boots the whole app at the minimum window footprint (640×480 dp) in BOTH
// orientations — landscape 640×480 and portrait 480×640 — and walks every main
// destination (Home / Create / Library tabs / Settings) plus the game editor and
// each of its sections, asserting NO layout exception (overflow) at any step.
// Complements test/window_min_size_test.dart (which covers editors/dialogs
// standalone); this exercises the nav-rail + section chrome the widget tests do
// not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory demoDir(CreateHarness h) => Directory('${h.projectsDir.path}/Demo');

  Future<void> seedDemo(CreateHarness harness) async {
    final dir = demoDir(harness);
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(jsonEncode({
      'metadata': {
        'name': 'Demo',
        'system': 'basic',
        'version': '1.0.0',
        'author': 'A',
        'description': 'A demo adventure with enough content to fill sections.',
        'language': 'en',
        'content_warnings': 'none',
        'license': 'x',
      },
      'images': [],
      'audio': [],
      'paths': [
        {'name': 'Main', 'color': 'yellow', 'description': ''},
      ],
      'key_events': [
        {'key_event_uuid': 'k1', 'name': 'Met the duke', 'state': 'unchecked'},
      ],
      'notes': [
        {'note_uuid': 'n1', 'note_name': 'A clue', 'note_content': 'Look here.'},
      ],
      'gm_notes': [],
      'npcs': [
        {'npc_uuid': 'p1', 'name': 'The Guard', 'description': 'A stern guard.'},
      ],
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'The gate',
          'description': 'A tall iron gate blocks the road.',
          'scene_type': 'start',
        },
      ],
    }));
  }

  const orientations = <(String, Size)>[
    ('landscape 640x480', Size(640, 480)),
    ('portrait 480x640', Size(480, 640)),
  ];

  for (final (label, size) in orientations) {
    testWidgets('window_min_size: shell + game editor has no overflow @ $label',
        (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<void> tap(String key, {String? then}) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${then ?? key} @ $label');
      }

      await harness.pumpApp(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'home @ $label');

      // --- App shell destinations ---
      await tap('nav.create');
      await tap('create.new', then: 'new-adventure form');
      await tap('nav.library', then: 'library');
      for (final t in ['adventures', 'projects', 'saves', 'finished']) {
        await tap('library.tab.$t', then: 'library tab $t');
      }
      await tap('nav.settings');
      await tap('nav.home');

      // --- Game editor + every section (exercises the game rail + sections) ---
      await tap('nav.create');
      await tap('adventure.tile.Demo', then: 'open game editor');
      expect(find.byKey(const ValueKey('game.root')), findsOneWidget);
      for (final s in [
        'settings',
        'scenes',
        'npcs',
        'notes',
        'keyevents',
        'images',
        'paths',
        'soundtracks',
      ]) {
        await tap('nav.game.$s', then: 'game section $s');
      }
    });
  }
}
