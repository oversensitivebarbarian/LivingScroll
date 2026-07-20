import 'package:flutter/foundation.dart';

import 'cover_crop.dart';

/// Holds the Adventure settings form state and its [isDirty] flag.
///
/// Unlike the new-adventure form (where any input makes the form dirty), this
/// edits an EXISTING adventure: it is loaded from `LivingScroll.json` via
/// [loadFrom], and [isDirty] compares the current values against that loaded
/// baseline. The game shell owns it so its navigation guard can consult
/// [isDirty] when the user leaves the Adventure settings section.
class AdventureSettingsController extends ChangeNotifier {
  String title = '';
  String version = '';
  String? system; // null until a system is chosen (required)
  String author = '';
  String description = '';
  String language = '';
  String contentWarnings = '';
  String license = '';

  /// Path of a newly picked cover image (staged; overwrites cover.jpg on Save).
  String? coverSourcePath;

  /// Crop region selected for [coverSourcePath] (locked to 1:1.43).
  CoverCrop? coverCrop;

  Map<String, String> _baseline = const {};
  bool _loaded = false;

  /// True once an adventure document has been loaded into the form.
  bool get isLoaded => _loaded;

  /// Populates the form from a decoded `LivingScroll.json` and snapshots the
  /// metadata as the dirty baseline.
  void loadFrom(Map<String, dynamic> document) {
    final m = document['metadata'];
    final meta = (m is Map) ? m : const {};
    String s(Object? v) => v is String ? v : '';
    title = s(meta['name']);
    final sys = s(meta['system']);
    system = sys.isEmpty ? null : sys;
    version = s(meta['version']);
    author = s(meta['author']);
    description = s(meta['description']);
    language = s(meta['language']);
    contentWarnings = s(meta['content_warnings']);
    license = s(meta['license']);
    coverSourcePath = null;
    coverCrop = null;
    _baseline = Map<String, String>.from(metadata);
    _loaded = true;
    notifyListeners();
  }

  /// The `metadata` object written back to LivingScroll.json.
  Map<String, String> get metadata => {
        'name': title.trim(),
        'system': system ?? '',
        'version': version.trim(),
        'author': author.trim(),
        'description': description.trim(),
        'language': language.trim(),
        'content_warnings': contentWarnings.trim(),
        'license': license.trim(),
      };

  /// Dirty when the metadata diverges from the loaded baseline, or a new cover
  /// has been staged. (Import data is applied immediately, not staged — see
  /// [ProjectsStore.importInto] — so it never makes the form dirty.)
  bool get isDirty =>
      _loaded &&
      (!mapEquals(metadata, _baseline) || coverSourcePath != null);

  /// Save is allowed only when the required fields are present.
  bool get canSave => title.trim().isNotEmpty && system != null;

  void setField(void Function() mutate) {
    mutate();
    notifyListeners();
  }

  /// Adopts the current values as the new baseline (called after a successful
  /// Save) and clears the staged cover so the form is pristine again.
  void markSaved() {
    _baseline = Map<String, String>.from(metadata);
    coverSourcePath = null;
    coverCrop = null;
    notifyListeners();
  }

  /// Restores the form to the loaded baseline, dropping all edits (Abandon).
  void discard() {
    title = _baseline['name'] ?? '';
    final sys = _baseline['system'] ?? '';
    system = sys.isEmpty ? null : sys;
    version = _baseline['version'] ?? '';
    author = _baseline['author'] ?? '';
    description = _baseline['description'] ?? '';
    language = _baseline['language'] ?? '';
    contentWarnings = _baseline['content_warnings'] ?? '';
    license = _baseline['license'] ?? '';
    coverSourcePath = null;
    coverCrop = null;
    notifyListeners();
  }
}
