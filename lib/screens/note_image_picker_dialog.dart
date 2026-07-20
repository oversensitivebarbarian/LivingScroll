import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../notes/note_media.dart';

/// Picks one image to embed in a note, from BOTH the adventure's images
/// (`images/other/`) and its NPC portraits (`images/npcs/`). Returns the chosen
/// [NoteMediaRef], or null on Cancel / no selection.
///
/// The grid is grouped: an "Images" header over the adventure images, then an
/// "NPCs" header over the NPC portraits. Each thumbnail is a tappable tile
/// keyed `game.notes.edit.image.pick.tile.<scope>.<uuid>`. When neither group
/// has anything, an empty-state note is shown instead.
Future<NoteMediaRef?> showNoteImagePicker(
  BuildContext context,
  List<NoteMediaRef> media,
) {
  return showDialog<NoteMediaRef>(
    context: context,
    builder: (context) => _NoteImagePickerDialog(media: media),
  );
}

class _NoteImagePickerDialog extends StatelessWidget {
  const _NoteImagePickerDialog({required this.media});

  final List<NoteMediaRef> media;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final images = [for (final m in media) if (m.scope == 'other') m];
    final npcs = [for (final m in media) if (m.scope == 'npc') m];

    return AlertDialog(
      key: const ValueKey('game.notes.edit.image.pick'),
      title: Text(l10n.notesImagePickTitle),
      content: SizedBox(
        width: 420,
        height: 460,
        child: media.isEmpty
            ? Center(
                child: Text(
                  l10n.notesImagePickEmpty,
                  key: const ValueKey('game.notes.edit.image.pick.empty'),
                ),
              )
            : ListView(
                children: [
                  if (images.isNotEmpty) ...[
                    _GroupHeader(
                      keyId: 'game.notes.edit.image.pick.group.other',
                      label: l10n.notesImagePickGroupImages,
                    ),
                    _Grid(media: images),
                  ],
                  if (npcs.isNotEmpty) ...[
                    _GroupHeader(
                      keyId: 'game.notes.edit.image.pick.group.npc',
                      label: l10n.notesImagePickGroupNpcs,
                    ),
                    _Grid(media: npcs),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('game.notes.edit.image.pick.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.unsavedCancel),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.keyId, required this.label});

  final String keyId;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(keyId),
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.media});

  final List<NoteMediaRef> media;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final m = media[index];
        return Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey(
                'game.notes.edit.image.pick.tile.${m.scope}.${m.uuid}'),
            onTap: () => Navigator.of(context).pop(m),
            child: m.file.existsSync()
                ? Image.file(m.file, fit: BoxFit.cover)
                : Center(
                    child: Icon(Icons.image_outlined,
                        color: scheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }
}
