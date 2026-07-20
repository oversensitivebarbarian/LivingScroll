// PATH: Home -> Settings -> Language = English -> Save
// EFFECT: {Settings}/overrides.json gains a `lang` stub == "en".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/settings_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings_change_language: English is persisted as lang stub', (
    tester,
  ) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // FIXTURES: overrides.json absent (created from zero).
    await harness.absentOverrides();
    final baseline = harness.snapshot();
    expect(baseline, isNull);

    await harness.pumpApp(tester);

    // STEP 1 | LAYOUT: main — open Settings.
    await tester.tap(find.byKey(const ValueKey('nav.settings')));
    await tester.pumpAndSettle();
    // EFFECT NO WRITE — nothing persisted by navigating.
    expect(harness.snapshot(), baseline);

    // STEP 2 | LAYOUT: settings — pick English. isDirty -> true, but the
    // observable contract is "still nothing on disk until Save".
    await tester.tap(find.byKey(const ValueKey('settings.language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings.language.item.en')));
    await tester.pumpAndSettle();
    expect(harness.snapshot(), baseline);

    // STEP 3 — Save.
    await tester.tap(find.byKey(const ValueKey('settings.save')));
    await tester.pumpAndSettle();

    // EFFECT WRITE {Settings}/overrides.json  CONTAINS lang == "en".
    final overrides = harness.readOverrides();
    expect(overrides, isNotNull);
    expect(overrides!['lang'], 'en');
  });
}
