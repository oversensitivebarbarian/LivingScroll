import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/main.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Shared harness for the `settings_*` navigation specs.
///
/// Resolves the user-files `{Settings}` root against an overridden
/// `path_provider` temp dir (never the real user directory), materializes
/// FIXTURES, and reads back the `overrides.json` side effect.
///
/// The override replaces [PathProviderPlatform.instance] (not a method-channel
/// mock): on desktop, path_provider ships a pure-Dart implementation that never
/// touches the channel, so only swapping the platform instance redirects it.
///
/// Contract with the app under test:
///   * the user-files root comes from `getApplicationSupportDirectory()`;
///   * `{Settings}` == `<support>/Settings`;
///   * the Settings screen carries stable ValueKeys, and
///     Save persists `overrides.json`.
class SettingsHarness {
  late final Directory _supportDir;
  PathProviderPlatform? _previousPlatform;

  /// {Settings} root: `<support>/Settings`.
  Directory get settingsDir => Directory('${_supportDir.path}/Settings');

  File get overridesFile => File('${settingsDir.path}/overrides.json');

  Future<void> setUp() async {
    _supportDir = await Directory.systemTemp.createTemp(
      'living_scroll_settings_',
    );
    await settingsDir.create(recursive: true);
    _previousPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(_supportDir.path);
  }

  Future<void> tearDown() async {
    if (_previousPlatform != null) {
      PathProviderPlatform.instance = _previousPlatform!;
    }
    if (await _supportDir.exists()) {
      await _supportDir.delete(recursive: true);
    }
  }

  // --- FIXTURES -----------------------------------------------------------

  /// `state: absent` — overrides.json must not exist at start.
  Future<void> absentOverrides() async {
    if (await overridesFile.exists()) await overridesFile.delete();
  }

  /// `from: test/fixtures/...` — copy a ready artifact into {Settings}.
  Future<void> copyOverridesFixture(String repoRelativePath) async {
    await overridesFile.writeAsString(
      File(repoRelativePath).readAsStringSync(),
    );
  }

  // --- EFFECTS ------------------------------------------------------------

  /// Decoded overrides.json, or `null` when the file is absent.
  Map<String, dynamic>? readOverrides() {
    if (!overridesFile.existsSync()) return null;
    return jsonDecode(overridesFile.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Baseline for `EFFECT NO WRITE`: raw content, or `null` when absent.
  String? snapshot() =>
      overridesFile.existsSync() ? overridesFile.readAsStringSync() : null;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();
  }
}

/// Fake [PathProviderPlatform] that points the application-support root at a
/// test temp dir; every other root is left unimplemented (unused by these specs).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
