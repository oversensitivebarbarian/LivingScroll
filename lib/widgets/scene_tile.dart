import 'package:flutter/material.dart';

import 'scene_type_icon.dart';
import 'tile_lock.dart';

/// One resolved path-colour disc on a scene tile: the path's stable [colorId]
/// (used in the disc key) and the literal [color] it is filled with.
typedef SceneTileDisc = ({String colorId, Color color});

/// One row of the Scenes list. A full-width horizontal
/// row: a leading scene-type + Preview glyph group, the scene name, a row of
/// path-colour discs (one per selected path), and a trailing delete button.
/// Colour roles match the Note / Key events tile — a filled
/// `colorScheme.secondaryContainer` row with `colorScheme.onSecondaryContainer`
/// content; the delete button inverts the pair.
///
/// Keyed by the scene's uuid: `scene.tile.<uuid>` (open), `.name`, `.paths` (the
/// disc row) with each disc `.path.<colorId>`, and `.delete`.
class SceneTile extends StatelessWidget {
  const SceneTile({
    super.key,
    required this.uuid,
    required this.name,
    required this.sceneType,
    required this.discs,
    required this.onTap,
    required this.onDelete,
    required this.onPreview,
    this.locked = false,
    this.dragIndex,
  });

  final String uuid;
  final String name;

  /// The scene's type (`scenes[].scene_type`): drives the leading glyph via
  /// [sceneTypeIcon] (start/standard/recurring/end), so the tile reads as its
  /// type — the SAME icon the new_scene form's type radio shows.
  final String sceneType;

  /// The resolved path-colour discs, in the fixed colour order. Empty => no discs.
  final List<SceneTileDisc> discs;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Opens the scene in the Play view (preview mode). Bound to the Preview glyph.
  final VoidCallback onPreview;

  /// When true the scene is immutable base content in save-content editing:
  /// it shows a lock badge instead of the delete button
  /// (the scene is not deletable) but STILL opens — the editor restricts it to
  /// its `next_scenes` list.
  final bool locked;

  /// When non-null the tile is an item of a `ReorderableListView` at this index:
  /// a `swap_vert` drag HANDLE is shown as the FIRST (leftmost) element, wrapped
  /// in a `ReorderableDragStartListener` so grabbing it (mouse on desktop, touch
  /// on Android — the same interaction) reorders the scene up/down. Null => no
  /// handle (e.g. while the search filter is active). Reorder is allowed even in
  /// save-edit — it changes only the `scenes[]` order, not the `next_scenes`
  /// graph.
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('scene.tile.$uuid'),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEADING — reorder handle (first from the left, only when the list
              // is reorderable) + scene-type glyph + Preview action.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dragIndex != null) ...[
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      // Same round disc as the delete button, with a swap_vert
                      // glyph; grabbing it drags the scene up/down. No tooltip —
                      // consistent with the tile's other action buttons.
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: SizedBox(
                          key: ValueKey('scene.tile.$uuid.reorder'),
                          width: 48,
                          height: 48,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.onSecondaryContainer,
                            ),
                            child: Icon(
                              Icons.swap_vert,
                              color: scheme.secondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    sceneTypeIcon(sceneType),
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey('scene.tile.$uuid.preview'),
                    icon: Icon(
                      Icons.preview,
                      color: scheme.onSecondaryContainer,
                    ),
                    onPressed: onPreview,
                  ),
                ],
              ),
              // MIDDLE — the scene name.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    name,
                    key: ValueKey('scene.tile.$uuid.name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // PATH — one disc per resolved path (hidden entirely when none).
              if (discs.isNotEmpty) ...[
                Row(
                  key: ValueKey('scene.tile.$uuid.paths'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final disc in discs)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: DecoratedBox(
                            key: ValueKey(
                              'scene.tile.$uuid.path.${disc.colorId}',
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: disc.color,
                              border: Border.all(
                                color: scheme.onSecondaryContainer,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              // TRAILING — delete, or a lock badge when the scene is frozen
              // (immutable base content — not deletable, but still openable).
              if (locked)
                TileLockBadge(badgeKey: ValueKey('scene.tile.$uuid.locked'))
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
                      key: ValueKey('scene.tile.$uuid.delete'),
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
