// PATH: Home -> Settings -> Display Mode = Light -> navigate to Home (no Save)
//       -> unsaved-changes prompt (Save / Abandon / Cancel).
// Baseline overrides.json == { "lang": "en", "mode": "dark" }; the Abandon and
// Cancel branches must leave that file untouched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/settings_harness.dart';

const _fixture = 'test/fixtures/settings/overrides_lang_mode.json';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Drives STEP 1..3: open Settings, switch mode to Light, tap Home -> prompt.
  // Returns the harness so each branch can assert disk effects against it.
  Future<SettingsHarness> openPromptOnNavigate(WidgetTester tester) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    // FIXTURES: overrides.json == { lang: en, mode: dark }.
    await harness.copyOverridesFixture(_fixture);
    final baseline = harness.snapshot();
    await harness.pumpApp(tester);

    // STEP 1 — open Settings.
    await tester.tap(find.byKey(const ValueKey('nav.settings')));
    await tester.pumpAndSettle();

    // STEP 2 — switch Dark -> Light; isDirty, but nothing persisted yet.
    await tester.tap(find.byKey(const ValueKey('settings.mode.light')));
    await tester.pumpAndSettle();
    expect(harness.snapshot(), baseline);

    // STEP 3 — navigate to Home; the guard intercepts with the prompt.
    await tester.tap(find.byKey(const ValueKey('nav.home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOne);
    // Navigation suspended, still on Settings, nothing written.
    expect(find.byKey(const ValueKey('settings.language')), findsOne);
    expect(harness.snapshot(), baseline);
    return harness;
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;

  ThemeMode themeMode(WidgetTester tester) => tester
      .widget<MaterialApp>(find.byKey(const ValueKey('app.root')))
      .themeMode!;

  testWidgets(
    'BRANCH save: persists the pending change, then navigates to Home',
    (tester) async {
      final harness = await openPromptOnNavigate(tester);

      // STEP 4 — Save.
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
      await tester.pumpAndSettle();

      // EFFECT WRITE: mode == "light", lang preserved.
      final overrides = harness.readOverrides();
      expect(overrides?['mode'], 'light');
      expect(overrides?['lang'], 'en');

      // Navigated to Home and the new theme is applied.
      expect(selectedIndex(tester), 0);
      expect(find.byKey(const ValueKey('settings.language')), findsNothing);
      expect(themeMode(tester), ThemeMode.light);
    },
  );

  testWidgets(
    'BRANCH abandon: drops the pending change, then navigates to Home',
    (tester) async {
      final harness = await openPromptOnNavigate(tester);

      // STEP 4 — Abandon.
      await tester.tap(find.byKey(const ValueKey('settings.unsaved.abandon')));
      await tester.pumpAndSettle();

      // EFFECT NO WRITE: file stays at the pre-change baseline.
      final overrides = harness.readOverrides();
      expect(overrides?['mode'], 'dark');
      expect(overrides?['lang'], 'en');

      // Navigated to Home; theme unchanged (still dark).
      expect(selectedIndex(tester), 0);
      expect(find.byKey(const ValueKey('settings.language')), findsNothing);
      expect(themeMode(tester), ThemeMode.dark);
    },
  );

  testWidgets('BRANCH cancel: dismisses the prompt and stays on Settings', (
    tester,
  ) async {
    final harness = await openPromptOnNavigate(tester);
    final baseline = harness.snapshot();

    // STEP 4 — Cancel.
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.cancel')));
    await tester.pumpAndSettle();

    // Dialog gone, still on Settings with the pending change intact.
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsNothing);
    expect(selectedIndex(tester), 3);
    expect(find.byKey(const ValueKey('settings.language')), findsOne);

    // isDirty still true -> Save button enabled.
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('settings.save')),
    );
    expect(save.enabled, isTrue);

    // Nothing persisted.
    expect(harness.snapshot(), baseline);
  });
}
