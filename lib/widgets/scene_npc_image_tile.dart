import 'dart:io';

import 'package:flutter/material.dart';

import 'npc_tile.dart';

/// The NPC image tile shared by the scene editor's NPC carousel and the NPC
/// picker, so both render the
/// SAME tile. Same proportions as a `game.npc` grid tile (portrait
/// [NpcTile.aspectRatio], 1:1.43): a `secondaryContainer` card showing the NPC's
/// icon image (or a person placeholder), with one inset top-right control —
/// a delete button in the carousel, a select toggle in the picker.
class SceneNpcImageTile extends StatelessWidget {
  const SceneNpcImageTile({
    super.key,
    required this.image,
    this.onTap,
    this.trailing,
  });

  /// The NPC's icon image, or null/absent to show the placeholder.
  final File? image;

  /// Tapping the tile body (used by the picker to toggle selection).
  final VoidCallback? onTap;

  /// The inset top-right control (delete button or selection toggle).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: NpcTile.aspectRatio,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image!.existsSync())
                Image.file(image!, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(Icons.person, color: scheme.onSecondaryContainer),
                ),
              if (trailing != null)
                Positioned(top: 2, right: 2, child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}
