import 'package:flutter/material.dart';

import 'tile_lock.dart';

/// One row of the Key events list. Bound to a single
/// key_event; keyed by its name: `event.tile.<name>` (open),
/// `event.tile.<name>.label` and `event.tile.<name>.delete`.
///
/// Colour roles mirror the Note Tile for a consistent interface: a filled
/// `colorScheme.secondaryContainer` row with `colorScheme.onSecondaryContainer`
/// content, and a delete button reusing the Note Tile's treatment — a round
/// `colorScheme.onSecondaryContainer` backdrop behind a
/// `colorScheme.secondaryContainer` (close) glyph.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.name,
    required this.onTap,
    required this.onDelete,
    this.locked = false,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Immutable base content in save-content editing: the row
  /// does not open the editor and shows a lock badge instead of delete.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('event.tile.$name'),
        onTap: locked ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.check_circle, color: scheme.onSecondaryContainer),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    name,
                    key: ValueKey('event.tile.$name.label'),
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
                TileLockBadge(badgeKey: ValueKey('event.tile.$name.locked'))
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
                      key: ValueKey('event.tile.$name.delete'),
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
