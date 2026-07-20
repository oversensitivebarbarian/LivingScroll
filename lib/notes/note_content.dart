// Serialization helpers for a note's rich body (`note_content`).
//
// A note's content is authored with `flutter_quill`, so on disk `note_content`
// holds a Quill Delta (a JSON list of ops) encoded as a JSON string — the
// schema field stays a plain string.
//
// Backward compatibility: a note written before rich text (or imported as plain
// text) stores its body as a bare string. `documentFromStored` therefore loads
// a value that is NOT a Delta JSON list as a single plain-text insert, so old
// notes open unchanged.

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Decodes a stored `note_content` into a Quill [Document].
///
/// * an empty value -> an empty document;
/// * a JSON-encoded Delta (a list of ops) -> that document;
/// * anything else (legacy plain text) -> a one-line document with that text.
Document documentFromStored(String stored) {
  if (stored.isEmpty) return Document();
  Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } catch (_) {
    decoded = null;
  }
  if (decoded is List) {
    try {
      return Document.fromJson(decoded);
    } catch (_) {
      // Malformed Delta -> fall back to treating it as plain text.
    }
  }
  return Document()..insert(0, stored);
}

/// Encodes a Quill [doc] back to the stored `note_content` string (Delta JSON).
String storedFromDocument(Document doc) => jsonEncode(doc.toDelta().toJson());

/// The searchable plain text of a stored `note_content` (embeds excluded).
/// Used by the Notes list's search filter, which matches on visible text.
String plainTextFromStored(String stored) {
  if (stored.isEmpty) return '';
  // toPlainText() renders each embed as the object-replacement char (U+FFFC);
  // drop those so search matches only real text.
  return documentFromStored(stored).toPlainText().replaceAll('￼', '').trim();
}
