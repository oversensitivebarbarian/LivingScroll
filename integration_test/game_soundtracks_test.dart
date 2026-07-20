// PATH: open adventure -> Soundtracks section (search + "Add soundtrack" + tiles)
// -> Add picks an audio file, copies it into audio/ and appends to audio[] with a
// minted audio_uuid and a DERIVED, unique display name (track title (+ artist),
// else file name without extension). Branches: load, filename fallback, duplicate
// name rejection, search filter, delete (confirm / cancel).
//
// NOTE: the Soundtracks section is not implemented yet (the rail destination is a
// placeholder), so these tests are RED until the section is built — they are the
// executable spec that drives that implementation. The play/stop tests assert the
// BUTTON STATE only (Play <-> Stop glyph); driving real audio deterministically
// will need an audio-player seam (analogous to FilePickerService) added with the
// implementation.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

/// Builds a temp mp3: the real (license-free) Test_Assets audio prefixed with a
/// synthesized ID3v2.3 tag (TIT2/TPE1), so the "tagged" fixture is genuine
/// playable audio without depending on a second checked-in binary asset.
String _buildTaggedMp3Fixture({required String title, required String artist}) {
  List<int> frame(String id, String text) {
    final body = [0, ...latin1.encode(text)]; // encoding byte 0 = ISO-8859-1
    final size = body.length;
    return [
      ...ascii.encode(id),
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
      0, 0, // flags
      ...body,
    ];
  }

  final frames = [...frame('TIT2', title), ...frame('TPE1', artist)];
  final tagSize = frames.length;
  final sizeBytes = [
    (tagSize >> 21) & 0x7F,
    (tagSize >> 14) & 0x7F,
    (tagSize >> 7) & 0x7F,
    tagSize & 0x7F,
  ];
  final audioBytes = File(
    CreateHarness.asset(
      'audiopapkin-dark-atmosphere-background-007-312379.mp3',
    ),
  ).readAsBytesSync();
  final tagged = [
    ...ascii.encode('ID3'),
    3, 0, 0, // version 2.3.0, flags
    ...sizeBytes,
    ...frames,
    ...audioBytes,
  ];
  final dir = Directory.systemTemp.createTempSync('soundtrack_tagged_fixture');
  final path = '${dir.path}/tagged.mp3';
  File(path).writeAsBytesSync(tagged);
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const soundtracksIndex = 7;

  // "Tagged" fixture: the real Test_Assets audio + a synthesized ID3 tag (built
  // once, at load time). "Untagged" fixture: that same real audio, untouched —
  // it carries no ID3 tag of its own, so its display name falls back to its
  // file name.
  const taggedTitle = 'Twilight Requiem';
  const taggedArtist = 'Sample Artist';
  const taggedName = '$taggedTitle ($taggedArtist)';
  final taggedMp3 = _buildTaggedMp3Fixture(
    title: taggedTitle,
    artist: taggedArtist,
  );
  final untaggedAudio = CreateHarness.asset(
    'audiopapkin-dark-atmosphere-background-007-312379.mp3',
  );
  const untaggedName = 'audiopapkin-dark-atmosphere-background-007-312379';

  Directory demoDir(CreateHarness harness) =>
      Directory('${harness.projectsDir.path}/Demo');
  Directory audioDir(CreateHarness harness) =>
      Directory('${demoDir(harness).path}/audio');

  Future<void> seedDemo(
    CreateHarness harness, {
    List<Object> audio = const [],
    List<String> audioFiles = const [], // relative names created under audio/
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
        'audio': audio,
        'paths': [],
        'key_events': [],
        'notes': [],
        'gm_notes': [],
        'npcs': [],
        'scenes': [],
      }),
    );
    if (audioFiles.isNotEmpty) {
      await audioDir(harness).create(recursive: true);
      for (final name in audioFiles) {
        await File('${audioDir(harness).path}/$name').writeAsString('x');
      }
    }
  }

  Future<void> openSoundtracks(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adventure.tile.Demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game.root')), findsOne);
    await tester.tap(find.byKey(const ValueKey('nav.game.soundtracks')));
    await tester.pumpAndSettle();
  }

  int? selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

  List<Map<String, dynamic>> readAudio(CreateHarness harness) =>
      (jsonDecode(
                File(
                  '${demoDir(harness).path}/LivingScroll.json',
                ).readAsStringSync(),
              )['audio']
              as List)
          .cast<Map<String, dynamic>>();

  testWidgets(
    'game_soundtracks: add a tagged track -> copied to audio/ + written to audio[]',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      harness.audioPath = taggedMp3;

      await harness.pumpApp(tester);
      await openSoundtracks(tester);
      expect(selectedIndex(tester), soundtracksIndex);
      expect(find.byKey(const ValueKey('sound.search')), findsOne);
      expect(find.byKey(const ValueKey('sound.list')), findsOne);

      // STEP 2: Add soundtrack -> picker returns the tagged mp3.
      await tester.tap(find.byKey(const ValueKey('sound.new')));
      await tester.pumpAndSettle();

      final audio = readAudio(harness);
      expect(audio.length, 1);
      expect(audio.single['name'], taggedName); // "<title> (<artist>)"
      final uuid = audio.single['audio_uuid'] as String;
      expect(uuid.isNotEmpty, isTrue);

      // The picked file is copied into audio/, named by its audio_uuid.
      expect(File('${audioDir(harness).path}/$uuid.mp3').existsSync(), isTrue);

      expect(find.byKey(ValueKey('sound.tile.$taggedName')), findsOne);
      expect(find.text(taggedName), findsOne);
    },
  );

  testWidgets('BRANCH existing_loaded: a seeded track shows on its tile', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      audio: const [
        {'audio_uuid': 'a1', 'name': 'Intro Theme'},
      ],
      audioFiles: const ['a1.mp3'],
    );

    await harness.pumpApp(tester);
    await openSoundtracks(tester);

    expect(find.byKey(const ValueKey('sound.tile.Intro Theme')), findsOne);
    expect(find.text('Intro Theme'), findsOne);
  });

  testWidgets(
    'BRANCH filename_fallback: a tagless file derives its name from the file name',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(harness);
      harness.audioPath = untaggedAudio;

      await harness.pumpApp(tester);
      await openSoundtracks(tester);

      await tester.tap(find.byKey(const ValueKey('sound.new')));
      await tester.pumpAndSettle();

      final audio = readAudio(harness);
      expect(audio.length, 1);
      expect(audio.single['name'], untaggedName); // file name without ".mp3"
      final uuid = audio.single['audio_uuid'] as String;
      expect(File('${audioDir(harness).path}/$uuid.mp3').existsSync(), isTrue);
      expect(find.byKey(ValueKey('sound.tile.$untaggedName')), findsOne);
    },
  );

  testWidgets(
    'BRANCH duplicate_name: a track whose derived name already exists is rejected',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        audio: const [
          {'audio_uuid': 'a1', 'name': taggedName},
        ],
      );
      harness.audioPath = taggedMp3; // same derived name as the seeded track

      await harness.pumpApp(tester);
      await openSoundtracks(tester);

      await tester.tap(find.byKey(const ValueKey('sound.new')));
      await tester.pumpAndSettle();

      // Rejected: the not-unique dialog shows and nothing is added / copied.
      expect(
        find.byKey(const ValueKey('sound.name.not.unique.dialog')),
        findsOne,
      );
      expect(readAudio(harness).length, 1);
      final names = audioDir(harness).existsSync()
          ? audioDir(harness).listSync().length
          : 0;
      expect(names, 0); // nothing copied in

      await tester.tap(find.byKey(const ValueKey('sound.name.not.unique.ok')));
      await tester.pumpAndSettle();
      expect(readAudio(harness).length, 1);
    },
  );

  testWidgets('BRANCH search_filter: search filters the list by name', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      audio: const [
        {'audio_uuid': 'a1', 'name': 'Moonlit Sonata (Sample Artist)'},
        {'audio_uuid': 'a2', 'name': 'Battle March (Sample Artist)'},
      ],
    );

    await harness.pumpApp(tester);
    await openSoundtracks(tester);

    // Both tiles visible with an empty query.
    expect(
      find.byKey(const ValueKey('sound.tile.Moonlit Sonata (Sample Artist)')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('sound.tile.Battle March (Sample Artist)')),
      findsOne,
    );

    // Match by NAME -> only the first; the add row stays.
    await tester.enterText(
      find.byKey(const ValueKey('sound.search')),
      'moonlit',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sound.tile.Moonlit Sonata (Sample Artist)')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('sound.tile.Battle March (Sample Artist)')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('sound.new')), findsOne);

    // Clear restores both.
    await tester.tap(find.byKey(const ValueKey('sound.search.clear')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sound.tile.Moonlit Sonata (Sample Artist)')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('sound.tile.Battle March (Sample Artist)')),
      findsOne,
    );
  });

  testWidgets('BRANCH delete: confirming removes the track and its file', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      audio: const [
        {'audio_uuid': 'a1', 'name': 'Intro Theme'},
      ],
      audioFiles: const ['a1.mp3'],
    );

    await harness.pumpApp(tester);
    await openSoundtracks(tester);

    await tester.tap(
      find.byKey(const ValueKey('sound.tile.Intro Theme.delete')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sound.delete.dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('sound.delete.confirm')));
    await tester.pumpAndSettle();

    expect(readAudio(harness), isEmpty);
    expect(File('${audioDir(harness).path}/a1.mp3').existsSync(), isFalse);
    expect(find.byKey(const ValueKey('sound.tile.Intro Theme')), findsNothing);
  });

  testWidgets('BRANCH delete_cancel: cancelling keeps the track and its file', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      audio: const [
        {'audio_uuid': 'a1', 'name': 'Intro Theme'},
      ],
      audioFiles: const ['a1.mp3'],
    );

    await harness.pumpApp(tester);
    await openSoundtracks(tester);

    await tester.tap(
      find.byKey(const ValueKey('sound.tile.Intro Theme.delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sound.delete.cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sound.tile.Intro Theme')), findsOne);
    expect(readAudio(harness).length, 1);
    expect(File('${audioDir(harness).path}/a1.mp3').existsSync(), isTrue);
  });

  // The play button's current glyph (Play when stopped, Stop when playing).
  IconData playGlyph(WidgetTester tester) => tester
      .widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('sound.tile.Intro Theme.play')),
          matching: find.byType(Icon),
        ),
      )
      .icon!;

  testWidgets('BRANCH play_stop: Play -> Stop glyph, Stop -> Play glyph', (
    tester,
  ) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    await seedDemo(
      harness,
      audio: const [
        {'audio_uuid': 'a1', 'name': 'Intro Theme'},
      ],
      audioFiles: const ['a1.mp3'],
    );

    await harness.pumpApp(tester);
    await openSoundtracks(tester);

    // Stopped initially -> Play glyph.
    expect(playGlyph(tester), Icons.play_arrow);

    // Tap Play -> starts from the beginning, glyph flips to Stop.
    await tester.tap(find.byKey(const ValueKey('sound.tile.Intro Theme.play')));
    await tester.pumpAndSettle();
    expect(playGlyph(tester), Icons.stop);

    // Tap Stop -> halts, glyph flips back to Play.
    await tester.tap(find.byKey(const ValueKey('sound.tile.Intro Theme.play')));
    await tester.pumpAndSettle();
    expect(playGlyph(tester), Icons.play_arrow);

    expect(readAudio(harness).length, 1); // playback never writes
  });

  testWidgets(
    'BRANCH play_then_navigate: leaving the section auto-stops playback',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      await seedDemo(
        harness,
        audio: const [
          {'audio_uuid': 'a1', 'name': 'Intro Theme'},
        ],
        audioFiles: const ['a1.mp3'],
      );

      await harness.pumpApp(tester);
      await openSoundtracks(tester);

      // Start playback -> Stop glyph.
      await tester.tap(
        find.byKey(const ValueKey('sound.tile.Intro Theme.play')),
      );
      await tester.pumpAndSettle();
      expect(playGlyph(tester), Icons.stop);

      // Navigate to another section, then back to Soundtracks.
      await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.game.soundtracks')));
      await tester.pumpAndSettle();

      // Playback was auto-stopped on leaving -> glyph is Play again.
      expect(playGlyph(tester), Icons.play_arrow);
    },
  );
}
