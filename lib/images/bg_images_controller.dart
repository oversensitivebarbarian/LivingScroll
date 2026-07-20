import 'package:flutter/foundation.dart';

/// The pool of scene BACKGROUND images (`scenes.bg_image`). Unlike the general
/// image pool (`images[]`), background images are FILES ONLY — they live under
/// `images/bg_images/<uuid>.png` and carry no name and no visibility rules. This
/// controller just holds the list of on-disk background-image uuids so the
/// Background image picker can rebuild when a new one is added.
class BgImagesController extends ChangeNotifier {
  final List<String> _uuids = [];

  /// The background-image uuids currently on disk (sorted).
  List<String> get uuids => List.unmodifiable(_uuids);

  /// Replaces the list (e.g. after scanning `images/bg_images/` on load).
  void setAll(Iterable<String> uuids) {
    _uuids
      ..clear()
      ..addAll(uuids);
    notifyListeners();
  }

  /// Records a newly-added background image (its file has just been written).
  void add(String uuid) {
    if (uuid.isEmpty || _uuids.contains(uuid)) return;
    _uuids.add(uuid);
    _uuids.sort();
    notifyListeners();
  }
}
