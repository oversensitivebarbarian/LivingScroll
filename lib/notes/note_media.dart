import 'dart:io';

/// One image the note editor can embed: an adventure image (`images/other/`) or
/// an NPC portrait (`images/npcs/`). The game shell builds these from the
/// adventure's `images[]` and `npcs[]` and hands them to the [NotesController].
///
/// An embedded image is stored in the Delta as a `flutter_quill` image embed
/// whose source is the [reference] (`<scope>:<uuid>`), so a note never bakes in
/// an absolute path — the file is resolved back from the adventure on display.
class NoteMediaRef {
  const NoteMediaRef({
    required this.scope,
    required this.uuid,
    required this.label,
    required this.file,
  });

  /// `other` for an adventure image, `npc` for an NPC portrait.
  final String scope;

  /// The image's id (`image_uuid`) or the NPC's `full_image` id.
  final String uuid;

  /// A human label for the picker (the image name or the NPC name).
  final String label;

  /// The image file on disk (used for the picker thumbnail and the embed).
  final File file;

  /// The stable reference stored in the Delta image embed: `<scope>:<uuid>`.
  String get reference => '$scope:$uuid';

  /// Parses a `<scope>:<uuid>` [reference] back into its parts.
  static (String scope, String uuid)? parse(String reference) {
    final i = reference.indexOf(':');
    if (i <= 0 || i == reference.length - 1) return null;
    return (reference.substring(0, i), reference.substring(i + 1));
  }
}
