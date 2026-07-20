import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// Packages a published adventure as a STANDARD zip with a `.ls` extension
/// (variant B): the whole project directory is zipped, and a small JSON
/// "header" — title / version / system / author / language — is stored in the
/// zip's COMMENT field (read from the end of the file, so an importer can show those
/// details without unpacking the archive). The authoritative metadata still
/// lives in the archived `LivingScroll.json`; the comment is only a cache of it.
///
/// Pure and testable: [pack] turns a directory + header into zip bytes, and
/// [readHeader] reads the cached header back out of `.ls` bytes.
class AdventurePackager {
  const AdventurePackager();

  /// File extensions whose content is already compressed — stored without
  /// re-compression (DEFLATE would only waste CPU for no size gain).
  static const Set<String> _storeExtensions = {
    'jpg', 'jpeg', 'png', 'mp3', 'aac', 'm4a', 'ogg', 'opus', 'flac',
  };

  /// Builds the header cache (the zip comment) from an adventure's `metadata`.
  static Map<String, String> headerFromMetadata(Object? metadata) {
    String s(String key) {
      final v = metadata is Map ? metadata[key] : null;
      return v is String ? v : '';
    }

    return {
      'title': s('name'),
      'version': s('version'),
      'system': s('system'),
      'author': s('author'),
      'language': s('language'),
    };
  }

  /// Zips every file under [sourceDir] (paths relative to it, `/`-separated) into
  /// a standard zip, storing [header] as the archive comment. Returns the bytes.
  List<int> pack({
    required Directory sourceDir,
    required Map<String, String> header,
  }) {
    final archive = Archive();
    final base = sourceDir.path;
    final entities = sourceDir.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final entity in entities) {
      final relative =
          entity.path.substring(base.length + 1).replaceAll(r'\', '/');
      final bytes = entity.readAsBytesSync();
      final file = ArchiveFile(relative, bytes.length, bytes)
        ..compress = !_isAlreadyCompressed(relative);
      archive.addFile(file);
    }

    archive.comment = jsonEncode(header);
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode the adventure archive.');
    }
    return encoded;
  }

  /// Extracts the archive [bytes] (a `.ls` / `.lse` standard zip) into [dest],
  /// recreating the stored `/`-separated directory tree. [dest] should already
  /// exist; parent directories of each entry are created as needed.
  void unpack({required List<int> bytes, required Directory dest}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final outPath = '${dest.path}/${entry.name}';
      if (entry.isFile) {
        final out = File(outPath);
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
  }

  /// Reads the cached header (title / version / system / author) from `.ls`
  /// [lsBytes] — the zip comment, decoded as JSON. Returns null when absent or
  /// unreadable (never throws to the caller).
  Map<String, String>? readHeader(List<int> lsBytes) {
    try {
      final decoder = ZipDecoder()..decodeBytes(lsBytes);
      final comment = decoder.directory.zipFileComment;
      if (comment.isEmpty) return null;
      final decoded = jsonDecode(comment);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries)
          '${entry.key}': '${entry.value}',
      };
    } catch (_) {
      return null;
    }
  }

  bool _isAlreadyCompressed(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _storeExtensions.contains(path.substring(dot + 1).toLowerCase());
  }
}
