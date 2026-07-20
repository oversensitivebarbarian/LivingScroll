import 'package:flutter/foundation.dart';

import 'settings_overrides.dart';

/// Holds the Settings screen's pending (unsaved) edits and exposes [isDirty].
///
/// The controller is owned by the shell (so navigation can consult [isDirty]
/// and resolve the unsaved-changes prompt) and driven by the Settings screen
/// (which mutates the pending values as the user edits). A screen that can
/// save data implements `isDirty()`; here that lives on the controller so
/// both the screen and the navigation guard share one source of truth.
class SettingsEditController extends ChangeNotifier {
  /// The last saved overrides — the baseline [isDirty] compares against.
  SettingsOverrides _saved = const SettingsOverrides();

  // Pending selections; `null` means the application default.
  String? _lang;
  String? _mode;

  /// Pending autoplay override (`null` == default ON, `false` == off). The ON
  /// choice normalizes back to `null` so the default never writes a stub.
  bool? _autoplay;

  /// Once the user touches a control we stop tracking the saved baseline, so a
  /// later [syncSaved] (e.g. the app's async initial load) can't clobber edits.
  bool _touched = false;

  String? get lang => _lang;
  String? get mode => _mode;

  /// The resolved autoplay toggle value shown by the Music switch (default on).
  bool get autoplayOn => _autoplay ?? true;

  /// Pending overrides as a value object (what Save would persist).
  SettingsOverrides get pending =>
      SettingsOverrides(lang: _lang, mode: _mode, autoplay: _autoplay);

  bool get isDirty =>
      _lang != _saved.lang ||
      _mode != _saved.mode ||
      _autoplay != _saved.autoplay;

  /// Adopt the saved baseline. While untouched, pending values mirror it so the
  /// screen reflects the app's loaded overrides; after the first edit only the
  /// baseline updates (used to recompute [isDirty]). Does not notify: it is
  /// called from the owner's build.
  void syncSaved(SettingsOverrides saved) {
    _saved = saved;
    if (!_touched) {
      _lang = saved.lang;
      _mode = saved.mode;
      _autoplay = saved.autoplay;
    }
  }

  void setLang(String? value) {
    _touched = true;
    _lang = value;
    notifyListeners();
  }

  void setMode(String? value) {
    _touched = true;
    _mode = value;
    notifyListeners();
  }

  /// Toggle music autoplay. ON normalizes to `null` (the default, so no stub is
  /// written); OFF stores `false`.
  void setAutoplay(bool value) {
    _touched = true;
    _autoplay = value ? null : false;
    notifyListeners();
  }

  /// After a successful save, the pending values become the new baseline.
  void markSaved() {
    _saved = pending;
    _touched = false;
    notifyListeners();
  }

  /// Drop pending edits back to the saved baseline (the Abandon choice).
  void discard() {
    _lang = _saved.lang;
    _mode = _saved.mode;
    _autoplay = _saved.autoplay;
    _touched = false;
    notifyListeners();
  }
}
