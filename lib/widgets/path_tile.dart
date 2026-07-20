import 'package:flutter/material.dart';

import 'tile_lock.dart';

/// One row of the Paths list. Same shape as the Key events
/// tile: a full-width horizontal row, but the leading glyph is a disc in the
/// path's own colour (instead of an icon), followed by the path name.
///
/// Colour roles match the Key events / Note tile: a filled
/// `colorScheme.secondaryContainer` row with `colorScheme.onSecondaryContainer`
/// content; the disc carries an `onSecondaryContainer` border so a light path
/// colour stays visible. The row is clickable (opens the path edit form); there
/// is no delete (the six path colours are fixed).
///
/// [colorId] is the path's identifier (one of the fixed "Path colors"), used
/// for the stable keys `path.tile.<id>`, `path.tile.<id>.swatch` and
/// `path.tile.<id>.name`.
class PathTile extends StatelessWidget {
  const PathTile({
    super.key,
    required this.colorId,
    required this.color,
    required this.name,
    required this.onTap,
    this.locked = false,
  });

  final String colorId;
  final Color color;

  /// The path's name; the name label is omitted when this is empty.
  final String name;

  final VoidCallback onTap;

  /// Immutable base content in save-content editing: the row
  /// does not open the edit form and shows a trailing lock badge.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('path.tile.$colorId'),
        onTap: locked ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Leading disc in the path's colour (instead of an icon), sized to
              // match a leading glyph; a contrasting border keeps it visible.
              Container(
                key: ValueKey('path.tile.$colorId.swatch'),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    width: 2,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: name.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          name,
                          key: ValueKey('path.tile.$colorId.name'),
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
                TileLockBadge(badgeKey: ValueKey('path.tile.$colorId.locked')),
            ],
          ),
        ),
      ),
    );
  }
}
