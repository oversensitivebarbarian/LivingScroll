// PATH: Home -> Settings -> Display Mode = Light -> Save
// EFFECT: {Settings}/overrides.json gains `mode` == "light"; app renders light.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/settings_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings_change_mode_light: Light is persisted and applied', (
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

    // STEP 2 | LAYOUT: settings — choose Light.
    await tester.tap(find.byKey(const ValueKey('settings.mode.light')));
    await tester.pumpAndSettle();
    // Nothing on disk before Save.
    expect(harness.snapshot(), isNull);

    // STEP 3 — Save.
    await tester.tap(find.byKey(const ValueKey('settings.save')));
    await tester.pumpAndSettle();

    // EFFECT WRITE  CONTAINS mode == "light".
    expect(harness.readOverrides()?['mode'], 'light');

    // App renders in light theme.
    final app = tester.widget<MaterialApp>(
      find.byKey(const ValueKey('app.root')),
    );
    expect(app.themeMode, ThemeMode.light);
  });
}
