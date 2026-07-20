/// A crop rectangle expressed in normalized coordinates (fractions 0..1 of the
/// source image). Stored instead of pixels so it is independent of the source
/// resolution and of the on-screen preview size; [ProjectsStore] turns it into
/// a pixel crop when writing `cover.jpg`.
///
/// The crop is locked to the cover aspect ratio (1:1.43) when selected, so
/// `width / height` (in source pixels) always matches the cover IMAGE PROFILE.
class CoverCrop {
  const CoverCrop({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}
