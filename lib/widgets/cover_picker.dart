import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../create/cover_crop.dart';

/// A full-height cover tile (1:1.43) used by both the new-adventure form and the
/// Adventure settings form.
///
/// What it shows, in priority order:
///   * a newly picked + cropped image — the exact 1:1.43 [crop] region of
///     [source], painted faithfully (a preview of what `cover.jpg` will hold);
///   * a newly picked image without a crop — [source] at `BoxFit.cover`;
///   * an already-saved [existingCover] file — at `BoxFit.cover`;
///   * otherwise a centered add-photo affordance with [label].
class CoverPickerField extends StatelessWidget {
  const CoverPickerField({
    super.key,
    required this.source,
    required this.crop,
    required this.label,
    required this.onTap,
    this.existingCover,
    this.showPlaceholder = true,
  });

  /// Path of a freshly picked image (staged, not yet written), or `null`.
  final String? source;

  /// Crop region selected for [source] (locked to 1:1.43), or `null`.
  final CoverCrop? crop;

  /// An already-saved cover shown when nothing new is staged (edit mode).
  final File? existingCover;

  final String label;

  /// Tap handler. When `null` the field is a NON-interactive preview (no ripple,
  /// not tappable) — used by the NPC icon, which is derived from the full image
  /// and never picked on its own.
  final VoidCallback? onTap;

  /// Whether the empty state shows the add-photo affordance (icon + [label]).
  /// When `false` the empty state is a blank box — so a non-interactive preview
  /// does not look like a picker.
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget content;
    if (source != null && crop != null) {
      content = _CroppedImage(path: source!, crop: crop!);
    } else if (source != null) {
      content = Image.file(File(source!), fit: BoxFit.cover);
    } else if (existingCover != null) {
      content = Image.file(existingCover!, fit: BoxFit.cover);
    } else if (showPlaceholder) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    } else {
      content = const SizedBox.expand();
    }
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Paints just the normalized [crop] region of an image, filling its box.
/// Because the crop is 1:1.43 and the tile is 1:1.43, the region fills exactly
/// without distortion — a faithful preview of what `cover.jpg` will contain.
class _CroppedImage extends StatefulWidget {
  const _CroppedImage({required this.path, required this.crop});

  final String path;
  final CoverCrop crop;

  @override
  State<_CroppedImage> createState() => _CroppedImageState();
}

class _CroppedImageState extends State<_CroppedImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _CroppedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _image = null;
      _subscribe();
    }
  }

  void _subscribe() {
    final provider = FileImage(File(widget.path));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    });
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(painter: _CropPainter(_image!, widget.crop)),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop);

  final ui.Image image;
  final CoverCrop crop;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      crop.left * image.width,
      crop.top * image.height,
      crop.width * image.width,
      crop.height * image.height,
    );
    canvas.drawImageRect(image, src, Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.crop != crop;
}
