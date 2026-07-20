import 'dart:convert';
import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/notes/note_content.dart';
import 'package:living_scroll/notes/note_media.dart';

void main() {
  group('note content (Quill Delta) serialization', () {
    test('empty stored value -> empty document', () {
      final doc = documentFromStored('');
      expect(doc.toPlainText().trim(), '');
    });

    test('round-trips a rich document through stored Delta JSON', () {
      final doc = Document()..insert(0, 'hello world');
      final stored = storedFromDocument(doc);

      // Stored form is a JSON list of Delta ops, not bare text.
      expect(jsonDecode(stored), isA<List<dynamic>>());

      final back = documentFromStored(stored);
      expect(back.toPlainText().trim(), 'hello world');
    });

    test('legacy plain text loads as a single text run (backward compatible)',
        () {
      final doc = documentFromStored('an old plain note');
      expect(doc.toPlainText().trim(), 'an old plain note');
    });

    test('plainTextFromStored extracts visible text from a Delta', () {
      final stored = storedFromDocument(Document()..insert(0, 'dragons here'));
      expect(plainTextFromStored(stored), 'dragons here');
    });

    test('plainTextFromStored passes legacy plain text through', () {
      expect(plainTextFromStored('castles'), 'castles');
    });

    test('an image embed survives the round-trip as a scope:uuid reference', () {
      final doc = Document()
        ..insert(0, 'see ')
        ..insert(4, BlockEmbed.image('other:img-1'));
      final stored = storedFromDocument(doc);
      final ops = jsonDecode(stored) as List<dynamic>;

      final hasEmbed = ops.any((op) =>
          op is Map &&
          op['insert'] is Map &&
          (op['insert'] as Map)['image'] == 'other:img-1');
      expect(hasEmbed, isTrue);

      // The embed contributes no searchable plain text.
      expect(plainTextFromStored(stored), 'see');
    });
  });

  group('NoteMediaRef', () {
    test('reference is <scope>:<uuid> and parses back', () {
      final ref = NoteMediaRef(
          scope: 'npc', uuid: 'full-1', label: 'Duke', file: File('x.png'));
      expect(ref.reference, 'npc:full-1');
      expect(NoteMediaRef.parse('npc:full-1'), ('npc', 'full-1'));
    });

    test('parse rejects malformed references', () {
      expect(NoteMediaRef.parse('nocolon'), isNull);
      expect(NoteMediaRef.parse(':leading'), isNull);
      expect(NoteMediaRef.parse('trailing:'), isNull);
    });
  });
}
