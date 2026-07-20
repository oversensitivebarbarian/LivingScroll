import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'settings_overrides.dart';

/// Reads and writes the settings override file under the user-files root:
/// `getApplicationSupportDirectory()/Settings/overrides.json`.
class SettingsStore {
  const SettingsStore();

  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/Settings/overrides.json');
  }

  /// Loads the saved overrides; returns defaults when the file is absent or
  /// unreadable (never throws to the caller).
  Future<SettingsOverrides> load() async {
    final file = await _file();
    if (!await file.exists()) return const SettingsOverrides();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return SettingsOverrides.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt file -> fall back to defaults rather than crashing.
    }
    return const SettingsOverrides();
  }

  /// Persists [overrides]. A fully-default configuration removes the file
  /// rather than writing an empty object.
  Future<void> save(SettingsOverrides overrides) async {
    final file = await _file();
    if (overrides.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(overrides.toJson()),
    );
  }
}
