import 'package:flutter/material.dart';

/// A non-interactive lock badge shown IN PLACE of a tile's delete button when
/// the object is immutable — frozen against edit/delete in save-content editing.
/// It reuses the delete button's inverted 48×48 disc (a
/// `colorScheme.onSecondaryContainer` circle) with a `secondaryContainer` lock
/// glyph, so it reads as "locked" in the same slot. Keyed by the caller
/// (`<prefix>.tile.<id>.locked`).
class TileLockBadge extends StatelessWidget {
  const TileLockBadge({super.key, required this.badgeKey, this.tooltip});

  /// The ValueKey placed on the disc (`<prefix>.tile.<id>.locked`).
  final Key badgeKey;

  /// Optional hover tooltip (localized "base content is locked"); null = none.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disc = SizedBox(
      width: 48,
      height: 48,
      child: Container(
        key: badgeKey,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.onSecondaryContainer,
        ),
        child: Icon(Icons.lock, size: 20, color: scheme.secondaryContainer),
      ),
    );
    return tooltip == null ? disc : Tooltip(message: tooltip!, child: disc);
  }
}
