import 'package:flutter/material.dart';

import 'tile_lock.dart';

/// One row of the Notes list. Same shape as the Key events
/// tile: a full-width horizontal row with a leading Note glyph, the note name,
/// and a trailing delete button. Colour roles match the Key events / soundtrack
/// tile — a filled `colorScheme.secondaryContainer` row with
/// `colorScheme.onSecondaryContainer` content, and a delete button using a round
/// `colorScheme.onSecondaryContainer` backdrop behind a `colorScheme.secondaryContainer`
/// (close) glyph.
///
/// Keyed by the note's uuid: `note.tile.<uuid>` (open), `note.tile.<uuid>.label`
/// and `note.tile.<uuid>.delete`. Tapping the row opens the note editor.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.uuid,
    required this.name,
    required this.onTap,
    required this.onDelete,
    this.locked = false,
  });

  final String uuid;
  final String name;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// When true the note is immutable base content in save-content editing:
  /// the row does not open the editor and shows a lock badge instead of the
  /// delete button.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('note.tile.$uuid'),
        onTap: locked ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.note_outlined, color: scheme.onSecondaryContainer),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    name,
                    key: ValueKey('note.tile.$uuid.label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (locked)
                TileLockBadge(badgeKey: ValueKey('note.tile.$uuid.locked'))
              else
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.onSecondaryContainer,
                    ),
                    child: IconButton(
                      key: ValueKey('note.tile.$uuid.delete'),
                      icon: Icon(Icons.close, color: scheme.secondaryContainer),
                      onPressed: onDelete,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
