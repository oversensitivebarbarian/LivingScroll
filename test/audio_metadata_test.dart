import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/audio_metadata.dart';

/// Builds a minimal ID3v2.3 tag (TIT2/TPE1 text frames, ISO-8859-1 encoded)
/// followed by [audioBytes], entirely in memory — no real audio asset needed,
/// since [readAudioTags] only ever parses the leading tag bytes.
List<int> _taggedMp3Bytes({
  required String title,
  String? artist,
  List<int> audioBytes = const [],
}) {
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

  final frames = [
    ...frame('TIT2', title),
    if (artist != null) ...frame('TPE1', artist),
  ];
  final tagSize = frames.length;
  final sizeBytes = [
    (tagSize >> 21) & 0x7F,
    (tagSize >> 14) & 0x7F,
    (tagSize >> 7) & 0x7F,
    tagSize & 0x7F,
  ];
  return [
    ...ascii.encode('ID3'),
    3, 0, 0, // version 2.3.0, flags
    ...sizeBytes,
    ...frames,
    ...audioBytes,
  ];
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('audio_metadata'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final path = '${tmp.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  test('tagged mp3 -> "<title> (<artist>)"', () {
    final path = write(
      'tagged.mp3',
      _taggedMp3Bytes(title: 'Café Nocturne', artist: 'Sample Artist'),
    );
    expect(deriveSoundtrackName(path), 'Café Nocturne (Sample Artist)');
  });

  test('tagged mp3 without an artist frame -> title only', () {
    final path = write('titled.mp3', _taggedMp3Bytes(title: 'Solo Theme'));
    expect(deriveSoundtrackName(path), 'Solo Theme');
  });

  test('tagless file -> file name without extension', () {
    final path = write('sample_track.wav', const [1, 2, 3, 4]);
    expect(deriveSoundtrackName(path), 'sample_track');
  });

  test('readAudioTags on a tagless file yields empty tags', () {
    final path = write('sample_track.wav', const [1, 2, 3, 4]);
    final tags = readAudioTags(path);
    expect(tags.title, isNull);
    expect(tags.artist, isNull);
  });
}
