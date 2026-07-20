// PATH: Home -> Settings -> Music > Autoplay = off -> Save
// EFFECT: {Settings}/overrides.json gains `autoplay` == false. Toggling it back
// on and saving drops the stub (default ON is never stored).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/settings_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('nav.settings')));
    await tester.pumpAndSettle();
  }

  bool autoplayValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.byKey(const ValueKey('settings.music.autoplay')),
      )
      .value;

  testWidgets('settings_toggle_autoplay: Autoplay off is persisted as a stub', (
    tester,
  ) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // FIXTURES: overrides.json absent; app default autoplay == on.
    await harness.absentOverrides();
    await harness.pumpApp(tester);

    // STEP 1 — open Settings.
    await openSettings(tester);

    // STEP 2 — the Autoplay switch is on by default; turn it off.
    expect(autoplayValue(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('settings.music.autoplay')));
    await tester.pumpAndSettle();
    expect(autoplayValue(tester), isFalse);
    // Not persisted before Save.
    expect(harness.snapshot(), isNull);

    // STEP 3 — Save writes the autoplay stub (off).
    await tester.tap(find.byKey(const ValueKey('settings.save')));
    await tester.pumpAndSettle();
    expect(harness.readOverrides()?['autoplay'], isFalse);
  });

  testWidgets(
    'BRANCH toggle_back_on_drops_stub: turning Autoplay back on drops the stub',
    (tester) async {
      final harness = SettingsHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);

      // Start from autoplay off already saved.
      await harness.overridesFile.writeAsString('{"autoplay": false}');
      await harness.pumpApp(tester);
      await openSettings(tester);

      // The switch reflects the saved-off state, then turn it back on.
      expect(autoplayValue(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('settings.music.autoplay')));
      await tester.pumpAndSettle();
      expect(autoplayValue(tester), isTrue);

      // Save: the autoplay stub is removed; with no other stubs the file is dropped.
      await tester.tap(find.byKey(const ValueKey('settings.save')));
      await tester.pumpAndSettle();
      final overrides = harness.readOverrides();
      expect(overrides == null || !overrides.containsKey('autoplay'), isTrue);
    },
  );
}
