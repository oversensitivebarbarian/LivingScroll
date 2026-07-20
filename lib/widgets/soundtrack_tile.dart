import 'package:flutter/material.dart';

import 'tile_lock.dart';

/// One row of the Soundtracks list. Bound to a single
/// track; keyed by its unique display name: `sound.tile.<name>` (the row),
/// `sound.tile.<name>.play` (Play/Stop toggle), `sound.tile.<name>.label` and
/// `sound.tile.<name>.delete`.
///
/// Left to right: the Audio File glyph, the Play/Stop button, the label (which
/// expands), and a trailing delete button. Colour roles mirror the Key events
/// tile: a filled `secondaryContainer` row with `onSecondaryContainer` content;
/// BOTH round buttons (Play/Stop and Delete) use a round `onSecondaryContainer`
/// backdrop behind a `secondaryContainer` glyph. The row body is not clickable —
/// only the two buttons are interactive.
class SoundtrackTile extends StatelessWidget {
  const SoundtrackTile({
    super.key,
    required this.name,
    required this.isPlaying,
    required this.onPlayStop,
    required this.onDelete,
    this.locked = false,
  });

  final String name;

  /// Whether THIS track is currently playing (drives the Play/Stop glyph).
  final bool isPlaying;

  final VoidCallback onPlayStop;
  final VoidCallback onDelete;

  /// Immutable base content in save-content editing: shows a
  /// lock badge instead of the delete button (the row is already not clickable).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget circleButton(String keyId, IconData icon, VoidCallback onPressed) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.onSecondaryContainer,
          ),
          child: IconButton(
            key: ValueKey(keyId),
            icon: Icon(icon, color: scheme.secondaryContainer),
            onPressed: onPressed,
          ),
        ),
      );
    }

    return Material(
      key: ValueKey('sound.tile.$name'),
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.audio_file, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            circleButton(
              'sound.tile.$name.play',
              isPlaying ? Icons.stop : Icons.play_arrow,
              onPlayStop,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                key: ValueKey('sound.tile.$name.label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (locked)
              TileLockBadge(badgeKey: ValueKey('sound.tile.$name.locked'))
            else
              circleButton('sound.tile.$name.delete', Icons.close, onDelete),
          ],
        ),
      ),
    );
  }
}
