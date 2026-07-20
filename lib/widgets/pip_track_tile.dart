import 'dart:io';

import 'package:flutter/material.dart';

/// A picture-in-picture thumbnail for one UN-focused party track: the track's
/// scene background (`bg_image`, or a flat colour when absent) under a scrim,
/// with the track's player-character names. Tapping it switches focus to that
/// track.
class PipTrackTile extends StatelessWidget {
  const PipTrackTile({
    super.key,
    required this.backgroundImage,
    required this.pcLabel,
    required this.onTap,
    this.tooltip,
  });

  /// The track's current scene `bg_image` file, or null for a flat colour.
  final File? backgroundImage;

  /// The track's PC names, already joined (e.g. "Alice, Bob").
  final String pcLabel;

  /// Switch focus to this track.
  final VoidCallback onTap;

  /// Optional hover tooltip (localized "Switch focus").
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = Container(
      width: 140,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundImage != null && backgroundImage!.existsSync())
                Image.file(backgroundImage!, fit: BoxFit.cover)
              else
                ColoredBox(color: scheme.surfaceContainerHighest),
              // Scrim band + PC names along the bottom, legible over any image.
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    pcLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}
