import 'package:flutter/foundation.dart';

import 'cover_crop.dart';
import 'projects_store.dart' show StagedImport;

/// Holds the new-adventure form state and its [isDirty] flag.
///
/// Owned by the shell so the navigation guard can consult [isDirty] when the
/// user leaves the form, and driven by [CreateNewScreen] as the user types /
/// picks. On Create the shell reads [metadata], [coverSourcePath] and
/// [importData] to write the project, then calls [reset].
class CreateNewController extends ChangeNotifier {
  String title = '';
  String version = '';
  String? system; // null until a system is chosen (required)
  String author = '';
  String description = '';
  String language = '';
  String contentWarnings = '';
  String license = '';

  /// Path of the picked cover image (staged; written as cover.jpg on Create).
  String? coverSourcePath;

  /// Crop region selected for the cover (locked to 1:1.43), normalized to the
  /// source image. Set together with [coverSourcePath].
  CoverCrop? coverCrop;

  /// Imports staged from the form's Import button (each: an unpacked archive +
  /// the per-element selection), applied to the new adventure on Create.
  final List<StagedImport> imports = [];

  /// True once the user has provided any input worth guarding on exit.
  bool get isDirty =>
      title.isNotEmpty ||
      version.isNotEmpty ||
      system != null ||
      author.isNotEmpty ||
      description.isNotEmpty ||
      language.isNotEmpty ||
      contentWarnings.isNotEmpty ||
      license.isNotEmpty ||
      coverSourcePath != null ||
      imports.isNotEmpty;

  /// Create is allowed only when the required fields are present.
  bool get canCreate => title.trim().isNotEmpty && system != null;

  /// The `metadata` object written to LivingScroll.json.
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

  void setField(void Function() mutate) {
    mutate();
    notifyListeners();
  }

  /// Clears all input back to a pristine form.
  void reset() {
    title = '';
    version = '';
    system = null;
    author = '';
    description = '';
    language = '';
    contentWarnings = '';
    license = '';
    coverSourcePath = null;
    coverCrop = null;
    imports.clear();
    notifyListeners();
  }
}
