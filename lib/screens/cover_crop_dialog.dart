import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../create/cover_crop.dart';
import '../l10n/app_localizations.dart';

/// Cover aspect ratio (width / height), per the cover IMAGE PROFILE (1:1.43).
const double _coverAspect = 1000 / 1430;

/// The draggable corner of the crop window; the opposite corner stays anchored.
enum _Corner { tl, tr, bl, br }

/// Shows the cover-crop step: the picked image with a
/// crop window locked to 1:1.43 that the user can move and resize. Returns the
/// selected [CoverCrop] (normalized to the source), or `null` if cancelled.
///
/// Reused for every 1:1.43 role image: [keyPrefix] namespaces the dialog's keys
/// (so the NPC full / icon crops are distinct from the cover crop) and [title]
/// overrides the header (defaults to the cover-crop title).
Future<CoverCrop?> showCoverCropDialog(
  BuildContext context,
  String sourcePath, {
  String keyPrefix = 'create_new.cover.crop',
  String? title,
}) {
  return showDialog<CoverCrop>(
    context: context,
    builder: (context) => _CoverCropDialog(
      sourcePath: sourcePath,
      keyPrefix: keyPrefix,
      title: title,
    ),
  );
}

class _CoverCropDialog extends StatefulWidget {
  const _CoverCropDialog({
    required this.sourcePath,
    required this.keyPrefix,
    this.title,
  });

  final String sourcePath;
  final String keyPrefix;
  final String? title;

  @override
  State<_CoverCropDialog> createState() => _CoverCropDialogState();
}

class _CoverCropDialogState extends State<_CoverCropDialog> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  /// The displayed image rect and the crop window, both in crop-area coords.
  Rect? _dispRect;
  Rect? _crop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    final provider = FileImage(File(widget.sourcePath));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(
        () => _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
      );
    });
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

  /// Largest 1:1.43 rectangle centered within [r].
  Rect _largestCentered(Rect r) {
    double w = r.width;
    double h = w / _coverAspect;
    if (h > r.height) {
      h = r.height;
      w = h * _coverAspect;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  void _move(Offset delta) {
    final r = _dispRect!, c = _crop!;
    final double nl = (c.left + delta.dx)
        .clamp(r.left, r.right - c.width)
        .toDouble();
    final double nt = (c.top + delta.dy)
        .clamp(r.top, r.bottom - c.height)
        .toDouble();
    setState(() => _crop = Rect.fromLTWH(nl, nt, c.width, c.height));
  }

  /// Resize from [corner] keeping the locked 1:1.43 ratio, with the opposite
  /// corner anchored. Width follows the horizontal drag; height derives from it.
  /// Clamped to the image bounds (both axes) and a minimum size.
  void _resizeCorner(_Corner corner, Offset delta) {
    final r = _dispRect!, c = _crop!;
    const minW = 48.0;
    final isLeft = corner == _Corner.tl || corner == _Corner.bl;
    final isTop = corner == _Corner.tl || corner == _Corner.tr;

    // Dragging a left corner grows the window as it moves left (-dx).
    double newW = isLeft ? c.width - delta.dx : c.width + delta.dx;
    // Horizontal headroom from the anchored (opposite) vertical edge.
    final maxWh = isLeft ? c.right - r.left : r.right - c.left;
    // Vertical headroom from the anchored (opposite) horizontal edge, as width.
    final maxHv = isTop ? c.bottom - r.top : r.bottom - c.top;
    final maxW = math.min(maxWh, maxHv * _coverAspect);
    newW = newW.clamp(minW, math.max(minW, maxW)).toDouble();
    final double newH = newW / _coverAspect;

    final Rect rect;
    switch (corner) {
      case _Corner.tl:
        rect = Rect.fromLTWH(c.right - newW, c.bottom - newH, newW, newH);
      case _Corner.tr:
        rect = Rect.fromLTWH(c.left, c.bottom - newH, newW, newH);
      case _Corner.bl:
        rect = Rect.fromLTWH(c.right - newW, c.top, newW, newH);
      case _Corner.br:
        rect = Rect.fromLTWH(c.left, c.top, newW, newH);
    }
    setState(() => _crop = rect);
  }

  /// A circular drag handle centered on [pos], resizing from [corner].
  Widget _handle(_Corner corner, Offset pos) {
    return Positioned(
      left: pos.dx - 14,
      top: pos.dy - 14,
      child: GestureDetector(
        key: ValueKey('${widget.keyPrefix}.handle.${corner.name}'),
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => _resizeCorner(corner, d.delta),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      ),
    );
  }

  CoverCrop _toNormalized() {
    final r = _dispRect!, c = _crop!;
    return CoverCrop(
      left: ((c.left - r.left) / r.width).clamp(0.0, 1.0),
      top: ((c.top - r.top) / r.height).clamp(0.0, 1.0),
      width: (c.width / r.width).clamp(0.0, 1.0),
      height: (c.height / r.height).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context).size;

    return Dialog(
      key: ValueKey(widget.keyPrefix),
      child: SizedBox(
        width: media.width * 0.8,
        height: media.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title ?? l10n.coverCropTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(child: _buildCropArea()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: ValueKey('${widget.keyPrefix}.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.coverCropCancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: ValueKey('${widget.keyPrefix}.confirm'),
                    onPressed: _imageSize == null
                        ? null
                        : () => Navigator.of(context).pop(_toNormalized()),
                    child: Text(l10n.coverCropConfirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropArea() {
    if (_imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final area = constraints.biggest;
          final fitted = applyBoxFit(BoxFit.contain, _imageSize!, area);
          final dispRect = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & area,
          );
          _dispRect = dispRect;
          // Initialize / re-clamp the crop window to the current layout.
          _crop ??= _largestCentered(dispRect);
          final crop = _crop!;

          return Container(
            key: ValueKey('${widget.keyPrefix}.area'),
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: dispRect,
                  child: Image.file(File(widget.sourcePath), fit: BoxFit.fill),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _CropOverlayPainter(crop)),
                  ),
                ),
                // Drag inside the window to move it.
                Positioned.fromRect(
                  rect: crop,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (d) => _move(d.delta),
                  ),
                ),
                // A resize handle at each corner (keeps the locked ratio).
                _handle(_Corner.tl, crop.topLeft),
                _handle(_Corner.tr, crop.topRight),
                _handle(_Corner.bl, crop.bottomLeft),
                _handle(_Corner.br, crop.bottomRight),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter(this.crop);

  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black54;
    // Dim everything outside the crop window.
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, crop.top), dim);
    canvas.drawRect(
      Rect.fromLTRB(0, crop.bottom, size.width, size.height),
      dim,
    );
    canvas.drawRect(Rect.fromLTRB(0, crop.top, crop.left, crop.bottom), dim);
    canvas.drawRect(
      Rect.fromLTRB(crop.right, crop.top, size.width, crop.bottom),
      dim,
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawRect(crop, border);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.crop != crop;
}
