import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Renders a note's embedded images inside the Quill editor.
///
/// An image embed's source is a `<scope>:<uuid>` reference (see [NoteMediaRef]);
/// [resolve] maps it back to the file on disk. An unresolved reference (the
/// image was deleted from the adventure) renders a broken-image placeholder
/// rather than throwing.
class NoteImageEmbedBuilder extends EmbedBuilder {
  const NoteImageEmbedBuilder(this.resolve);

  /// Resolves a `<scope>:<uuid>` reference to its image file (or null).
  final File? Function(String reference) resolve;

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  // An embedded image carries no searchable text.
  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final reference = embedContext.node.value.data.toString();
    final file = resolve(reference);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 220),
        child: file != null && file.existsSync()
            ? Image.file(file,
                key: ValueKey('game.notes.edit.content.image.$reference'),
                fit: BoxFit.contain)
            : Icon(Icons.broken_image_outlined,
                key: ValueKey('game.notes.edit.content.image.$reference'),
                color: scheme.onSurfaceVariant),
      ),
    );
  }
}
