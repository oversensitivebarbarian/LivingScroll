import 'package:flutter/widgets.dart';

import 'settings_overrides.dart';

/// Exposes the live [SettingsOverrides] and a callback to apply (and persist)
/// new ones, so the Settings screen can update app-wide locale and theme.
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.overrides,
    required this.onChanged,
    required super.child,
  });

  final SettingsOverrides overrides;

  /// Applies new overrides app-wide and persists them to overrides.json.
  final Future<void> Function(SettingsOverrides) onChanged;

  static SettingsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) =>
      oldWidget.overrides != overrides;
}
