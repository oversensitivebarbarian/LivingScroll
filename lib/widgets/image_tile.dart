import 'dart:io';

import 'package:flutter/material.dart';

import 'tile_lock.dart';

/// One cell of the Images grid. A SQUARE photo with
/// rounded corners (BoxFit.cover), and a delete button in the top-right corner —
/// the same treatment as the Key events / Location tile delete button: a round
/// `colorScheme.onSecondaryContainer` backdrop behind a `colorScheme.secondaryContainer`
/// (close) glyph.
///
/// Keyed by the image's uuid: `image.tile.<uuid>` (the photo, tap opens the edit
/// form) and `image.tile.<uuid>.delete`.
class ImageTile extends StatelessWidget {
  const ImageTile({
    super.key,
    required this.uuid,
    required this.file,
    required this.onTap,
    required this.onDelete,
    this.locked = false,
  });

  final String uuid;
  final File file;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Immutable base content in save-content editing: the cell
  /// does not open the edit form and shows a lock badge instead of delete.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The photo, clipped to rounded corners — separate from the delete
          // button so its circle is never cropped. Wrapped in an InkWell so
          // tapping opens the edit form.
          Positioned.fill(
            child: Material(
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('image.tile.$uuid'),
                onTap: locked ? null : onTap,
                child: Image.file(file, fit: BoxFit.cover),
              ),
            ),
          ),
          // Delete button — top-right, identical to the Key events / Location
          // tile delete treatment. A frozen (immutable) image shows a lock badge
          // instead.
          Positioned(
            top: 8,
            right: 8,
            child: locked
                ? TileLockBadge(badgeKey: ValueKey('image.tile.$uuid.locked'))
                : SizedBox(
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.onSecondaryContainer,
                      ),
                      child: IconButton(
                        key: ValueKey('image.tile.$uuid.delete'),
                        icon: Icon(
                          Icons.close,
                          color: scheme.secondaryContainer,
                        ),
                        onPressed: onDelete,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
