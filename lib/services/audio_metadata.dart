import 'dart:convert';
import 'dart:io';

/// Track tags read from an audio file's embedded metadata.
class AudioTags {
  const AudioTags({this.title, this.artist});

  final String? title;
  final String? artist;
}

/// Derives a soundtrack's DISPLAY NAME from the file at [path]: the embedded
/// track title — with " (artist)"
/// appended when an artist tag is present — or, when no usable title metadata is
/// found, the file name without its extension.
String deriveSoundtrackName(String path) {
  final tags = readAudioTags(path);
  final title = tags.title?.trim();
  if (title != null && title.isNotEmpty) {
    final artist = tags.artist?.trim();
    if (artist != null && artist.isNotEmpty) return '$title ($artist)';
    return title;
  }
  return _fileNameWithoutExtension(path);
}

String _fileNameWithoutExtension(String path) {
  var name = path;
  for (final sep in const ['/', '\\']) {
    final i = name.lastIndexOf(sep);
    if (i >= 0) name = name.substring(i + 1);
  }
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Reads the title/artist from an ID3v2 (2.2/2.3/2.4) tag at the start of the
/// file. Files without an ID3 tag (e.g. WAV) yield empty tags. Reads only the
/// tag region, never the whole audio file.
AudioTags readAudioTags(String path) {
  RandomAccessFile? raf;
  try {
    raf = File(path).openSync();
    final header = raf.readSync(10);
    if (header.length < 10 ||
        header[0] != 0x49 || // 'I'
        header[1] != 0x44 || // 'D'
        header[2] != 0x33) {
      // ' 3'
      return const AudioTags();
    }
    final major = header[3];
    final size = _synchsafe(header, 6);
    final body = raf.readSync(size);
    return _parseFrames(body, major);
  } catch (_) {
    return const AudioTags();
  } finally {
    raf?.closeSync();
  }
}

int _synchsafe(List<int> b, int o) =>
    (b[o] << 21) | (b[o + 1] << 14) | (b[o + 2] << 7) | b[o + 3];

AudioTags _parseFrames(List<int> body, int major) {
  // ID3v2.2 uses 3-char frame ids + 3-byte sizes; v2.3/v2.4 use 4 + 4.
  final idLen = major <= 2 ? 3 : 4;
  final headerLen = major <= 2 ? 6 : 10;
  final titleId = major <= 2 ? 'TT2' : 'TIT2';
  final artistId = major <= 2 ? 'TP1' : 'TPE1';

  String? title, artist;
  var pos = 0;
  while (pos + headerLen <= body.length) {
    if (body[pos] == 0) break; // padding
    final id = String.fromCharCodes(body, pos, pos + idLen);
    final int size;
    if (major <= 2) {
      size = (body[pos + 3] << 16) | (body[pos + 4] << 8) | body[pos + 5];
    } else if (major >= 4) {
      size = _synchsafe(body, pos + 4); // v2.4 frame sizes are synchsafe
    } else {
      size =
          (body[pos + 4] << 24) |
          (body[pos + 5] << 16) |
          (body[pos + 6] << 8) |
          body[pos + 7];
    }
    final start = pos + headerLen;
    if (size <= 0 || start + size > body.length) break;
    if (id == titleId) {
      title = _decodeText(body.sublist(start, start + size));
    } else if (id == artistId) {
      artist = _decodeText(body.sublist(start, start + size));
    }
    if (title != null && artist != null) break;
    pos = start + size;
  }
  return AudioTags(title: title, artist: artist);
}

/// Decodes an ID3 text frame: a leading encoding byte then the text. Strips the
/// trailing null terminator(s).
String _decodeText(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final encoding = bytes[0];
  final data = bytes.sublist(1);
  String s;
  switch (encoding) {
    case 1: // UTF-16 with BOM
      s = _decodeUtf16(data, hasBom: true);
      break;
    case 2: // UTF-16BE, no BOM
      s = _decodeUtf16(data, hasBom: false);
      break;
    case 3: // UTF-8
      s = utf8.decode(data, allowMalformed: true);
      break;
    default: // 0: ISO-8859-1 (Latin-1)
      s = latin1.decode(data);
  }
  return s.replaceAll('\u0000', '').trim();
}

String _decodeUtf16(List<int> data, {required bool hasBom}) {
  var d = data;
  var littleEndian = false;
  if (hasBom && d.length >= 2) {
    if (d[0] == 0xFF && d[1] == 0xFE) {
      littleEndian = true;
      d = d.sublist(2);
    } else if (d[0] == 0xFE && d[1] == 0xFF) {
      d = d.sublist(2);
    }
  }
  final units = <int>[];
  for (var i = 0; i + 1 < d.length; i += 2) {
    units.add(
      littleEndian ? (d[i] | (d[i + 1] << 8)) : ((d[i] << 8) | d[i + 1]),
    );
  }
  return String.fromCharCodes(units);
}
