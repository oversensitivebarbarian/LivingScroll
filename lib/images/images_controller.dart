import 'package:flutter/foundation.dart';

import '../visibility/visibility_rules.dart';
import 'adventure_image.dart';

/// In-memory state for the Images section: the adventure's image pool, the
/// adventure's key_events (for the add form's visibility editor), and the
/// currently open add form.
///
/// Adding an image opens a form (a required image + a visibility gate); the image
/// is STAGED ([editImageSource], written to disk by the game shell on Add).
/// Deleting is immediate. The game shell consults [isDirty] when the user leaves
/// the section mid-add, and persists [toJson] to LivingScroll.json.
class ImagesController extends ChangeNotifier {
  final List<AdventureImage> _images = [];
  List<KeyEventRef> _keyEvents = const [];

  List<AdventureImage> get images => List.unmodifiable(_images);

  /// The adventure's key_events (uuid + name), for the visibility editor.
  List<KeyEventRef> get keyEvents => _keyEvents;

  /// Replaces the available key_events shown by the visibility editor (the game
  /// shell calls this when the Key events section changes).
  void setKeyEvents(List<KeyEventRef> events) {
    _keyEvents = List.unmodifiable(events);
    notifyListeners();
  }

  /// Loads images and key_events from a decoded LivingScroll.json.
  void loadFrom(Map<String, dynamic> document) {
    _images.clear();
    final list = document['images'];
    if (list is List) {
      for (final i in list) {
        if (i is Map) _images.add(AdventureImage.fromJson(i));
      }
    }
    _keyEvents = _parseKeyEvents(document);
    _editing = null;
    notifyListeners();
  }

  static List<KeyEventRef> _parseKeyEvents(Map document) {
    final out = <KeyEventRef>[];
    final ke = document['key_events'];
    if (ke is List) {
      for (final e in ke) {
        if (e is Map && e['name'] is String) {
          out.add((
            uuid: e['key_event_uuid'] is String
                ? e['key_event_uuid'] as String
                : '',
            name: e['name'] as String,
          ));
        }
      }
    }
    return List.unmodifiable(out);
  }

  // --- add/edit form state ------------------------------------------------

  _Edit? _editing;

  bool get isEditing => _editing != null;

  /// True for the ADD form (a new image), false for the EDIT form (an existing
  /// image whose only editable field is its visibility gate).
  bool get isNew => _editing?.uuid == null;

  /// The image_uuid being edited (EDIT mode), or `null` (ADD mode).
  String? get editingUuid => _editing?.uuid;

  /// The path of the staged (picked) image (ADD mode), or `null`.
  String? get editImageSource => _editing?.imageSource;

  VisibilityRules get editVisibility =>
      _editing?.visibility ?? const VisibilityRules();

  set editVisibility(VisibilityRules value) {
    final e = _editing;
    if (e == null) return;
    e.visibility = value;
    notifyListeners();
  }

  /// Stages the picked image file (ADD mode only).
  void pickImage(String sourcePath) {
    final e = _editing;
    if (e == null) return;
    e.imageSource = sourcePath;
    notifyListeners();
  }

  /// Opens the ADD form for a brand-new image.
  void beginNew() {
    _editing = _Edit();
    notifyListeners();
  }

  /// Opens the EDIT form for the existing image [uuid] (visibility only).
  void beginEdit(String uuid) {
    final image = _images.firstWhere((i) => i.uuid == uuid);
    _editing = _Edit(uuid: image.uuid, visibility: image.visibility);
    notifyListeners();
  }

  /// Closes the form without committing (Cancel / Abandon).
  void cancelEdit() {
    _editing = null;
    notifyListeners();
  }

  /// Dirty when there is something to commit: ADD -> an image staged or a
  /// non-empty rule; EDIT -> the visibility gate diverges from the saved one.
  bool get isDirty {
    final e = _editing;
    if (e == null) return false;
    if (e.uuid == null) {
      return e.imageSource != null || e.visibility != const VisibilityRules();
    }
    return e.visibility != e.baseVisibility;
  }

  /// ADD requires a picked image; EDIT can always save (the image already exists).
  bool get canSave {
    final e = _editing;
    if (e == null) return false;
    return e.uuid != null || e.imageSource != null;
  }

  /// Commits the staged image (its file is written by the game shell first, named
  /// by [uuid]) as a new images[] entry and closes the ADD form.
  void commitNew(String uuid, String name) {
    final e = _editing;
    if (e == null) return;
    _images.add(AdventureImage(uuid: uuid, name: name, visibility: e.visibility));
    _editing = null;
    notifyListeners();
  }

  /// Writes the edited visibility gate back to the existing image and closes the
  /// EDIT form (the image file is unchanged).
  void commitEdit() {
    final e = _editing;
    if (e == null || e.uuid == null) return;
    final image = _images.firstWhere((i) => i.uuid == e.uuid);
    image.visibility = e.visibility;
    _editing = null;
    notifyListeners();
  }

  /// Removes the image [uuid] (and closes the form if it was the one open).
  void delete(String uuid) {
    _images.removeWhere((i) => i.uuid == uuid);
    if (_editing?.uuid == uuid) _editing = null;
    notifyListeners();
  }

  /// The `images` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final i in _images) i.toJson()];
}

/// The working copy of the add/edit form. A null [uuid] means ADD (a staged
/// [imageSource]); a set [uuid] means EDIT (only [visibility] changes).
class _Edit {
  _Edit({this.uuid, VisibilityRules visibility = const VisibilityRules()})
      : visibility = visibility,
        baseVisibility = visibility;

  final String? uuid;
  String? imageSource;
  VisibilityRules visibility;
  final VisibilityRules baseVisibility;
}
