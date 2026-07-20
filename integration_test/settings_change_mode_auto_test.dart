// PATH: Home -> Settings -> Display Mode = Auto (application default) -> Save
// EFFECT: the `mode` stub is ABSENT afterwards. An existing stub is removed
//         (other stubs preserved); a missing overrides.json is acceptable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/settings_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // STEPS — start from an existing override (mode == dark) and reset to Auto.
  testWidgets('settings_change_mode_auto: Auto removes the mode stub', (
    tester,
  ) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // FIXTURES: overrides.json = { "lang": "en", "mode": "dark" }.
    await harness.copyOverridesFixture(
      'test/fixtures/settings/overrides_lang_mode.json',
    );
    await harness.pumpApp(tester);

    // STEP 1 | LAYOUT: main — open Settings.
    await tester.tap(find.byKey(const ValueKey('nav.settings')));
    await tester.pumpAndSettle();

    // STEP 2 | LAYOUT: settings — choose Auto (the default).
    await tester.tap(find.byKey(const ValueKey('settings.mode.auto')));
    await tester.pumpAndSettle();

    // STEP 3 — Save.
    await tester.tap(find.byKey(const ValueKey('settings.save')));
    await tester.pumpAndSettle();

    // EFFECT WRITE  CONTAINS mode == ABSENT, lang preserved.
    final overrides = harness.readOverrides();
    expect(overrides, isNotNull);
    expect(overrides!.containsKey('mode'), isFalse);
    expect(overrides['lang'], 'en');

    // App follows the system brightness.
    final app = tester.widget<MaterialApp>(
      find.byKey(const ValueKey('app.root')),
    );
    expect(app.themeMode, ThemeMode.system);
  });

  // BRANCH no_overrides_file — Auto with no pre-existing overrides.json.
  testWidgets('settings_change_mode_auto[no_overrides_file]: no mode stub', (
    tester,
  ) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // FIXTURES: overrides.json absent; app default mode == auto.
    await harness.absentOverrides();
    await harness.pumpApp(tester);

    // STEP 1 | LAYOUT: main — open Settings.
    await tester.tap(find.byKey(const ValueKey('nav.settings')));
    await tester.pumpAndSettle();

    // STEP 2 | LAYOUT: settings — (re)select the default Auto.
    await tester.tap(find.byKey(const ValueKey('settings.mode.auto')));
    await tester.pumpAndSettle();

    // STEP 3 — Save.
    await tester.tap(find.byKey(const ValueKey('settings.save')));
    await tester.pumpAndSettle();

    // Acceptable outcome A: file stays absent.
    // Acceptable outcome B: file exists but carries NO `mode` stub.
    final overrides = harness.readOverrides();
    if (overrides != null) {
      expect(overrides.containsKey('mode'), isFalse);
    }
  });
}
