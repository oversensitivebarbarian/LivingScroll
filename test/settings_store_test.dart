import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/settings/settings_overrides.dart';
import 'package:living_scroll/settings/settings_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Round-trips the settings overrides through the REAL `{Settings}/overrides.json`
/// file (over a faked support dir), focusing on the `railExtended` stub that
/// persists the navigation rail's open/collapsed state between app launches —
/// exactly what `main.dart` writes on a rail toggle and reads back on startup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SettingsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_settings_store_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  File overridesFile() => File('${support.path}/Settings/overrides.json');

  test('saving an expanded rail writes railExtended:true and loads it back',
      () async {
    await store.save(const SettingsOverrides(railExtended: true));

    // The stub landed on disk...
    final json =
        jsonDecode(overridesFile().readAsStringSync()) as Map<String, dynamic>;
    expect(json['railExtended'], isTrue);

    // ...and a fresh load (a new launch) restores it.
    final loaded = await store.load();
    expect(loaded.railExtendedOn, isTrue);
  });

  test('saving a collapsed rail removes the file (collapsed is the default)',
      () async {
    // Pre-existing expanded stub on disk.
    await store.save(const SettingsOverrides(railExtended: true));
    expect(overridesFile().existsSync(), isTrue);

    // Collapsing back to the default drops the stub; the file (now empty) goes.
    await store.save(const SettingsOverrides(railExtended: false));
    expect(overridesFile().existsSync(), isFalse);

    // A load with no file falls back to collapsed.
    final loaded = await store.load();
    expect(loaded.railExtendedOn, isFalse);
  });

  test('the rail stub coexists with other stubs without dropping them',
      () async {
    await store.save(const SettingsOverrides(lang: 'pl', railExtended: true));

    final loaded = await store.load();
    expect(loaded.lang, 'pl');
    expect(loaded.railExtendedOn, isTrue);

    // Collapsing the rail keeps the language stub and its file.
    await store.save(SettingsOverrides(lang: loaded.lang));
    final after = await store.load();
    expect(after.lang, 'pl');
    expect(after.railExtendedOn, isFalse);
    expect(overridesFile().existsSync(), isTrue);
  });

  test('an absent file loads as collapsed (fresh install default)', () async {
    expect(overridesFile().existsSync(), isFalse);
    final loaded = await store.load();
    expect(loaded.railExtendedOn, isFalse);
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
