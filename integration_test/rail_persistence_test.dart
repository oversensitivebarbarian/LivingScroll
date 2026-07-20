// PATH: Home -> toggle the Side Navigation rail -> {Settings}/overrides.json gains
//       a `railExtended` stub (persisted IMMEDIATELY, no Save button) -> relaunching
//       the app restores the rail in that state. Collapsing back to the default
//       drops the stub and a relaunch comes up collapsed.
//
// Runs under a real binding (`flutter test -d linux integration_test/
// rail_persistence_test.dart`): it pumps the whole LivingScrollApp, which needs
// the desktop plugins headless `flutter test` cannot provide.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:living_scroll/widgets/rail_state.dart';

import 'support/settings_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  bool railExtended(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended;

  Future<void> toggleRail(WidgetTester tester) async {
    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();
  }

  /// Simulates a fresh app launch: fully unmount the app (disposing its state),
  /// reset the in-memory rail flag to its process default (collapsed) so the
  /// restore can only come from disk, then pump a brand-new app instance whose
  /// startup `_load` reads overrides.json.
  Future<void> relaunch(SettingsHarness harness, WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    RailState.extended.value = false;
    await harness.pumpApp(tester);
  }

  testWidgets('rail_persistence: expanding the rail persists across a relaunch', (
    tester,
  ) async {
    final harness = SettingsHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);
    addTearDown(() => RailState.extended.value = false);

    // FIXTURES: overrides.json absent; the rail starts collapsed (app default).
    await harness.absentOverrides();
    await harness.pumpApp(tester);

    // STEP 1 — the rail is collapsed and nothing is persisted yet.
    expect(railExtended(tester), isFalse);
    expect(harness.snapshot(), isNull);

    // STEP 2 — toggle the Side Navigation button: the rail expands AND the state
    // is written to overrides.json immediately (no Save button on this path).
    await toggleRail(tester);
    expect(railExtended(tester), isTrue);
    expect(harness.readOverrides()?['railExtended'], isTrue);

    // STEP 3 — relaunch the app: the rail comes up ALREADY expanded, restored
    // from overrides.json (not the collapsed default).
    await relaunch(harness, tester);
    expect(RailState.extended.value, isTrue);
    expect(railExtended(tester), isTrue);
  });

  testWidgets(
    'BRANCH collapse_back_drops_stub: collapsing to the default drops the stub '
    'and a relaunch comes up collapsed',
    (tester) async {
      final harness = SettingsHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      addTearDown(() => RailState.extended.value = false);

      // Start from an expanded rail already saved on disk.
      await harness.overridesFile.writeAsString('{"railExtended": true}');
      await harness.pumpApp(tester);

      // The rail is restored expanded from disk.
      expect(railExtended(tester), isTrue);

      // Collapse it: collapsed is the default, so the stub is removed. With no
      // other stubs, overrides.json is dropped entirely.
      await toggleRail(tester);
      expect(railExtended(tester), isFalse);
      final overrides = harness.readOverrides();
      expect(
        overrides == null || !overrides.containsKey('railExtended'),
        isTrue,
      );

      // A relaunch comes up collapsed.
      await relaunch(harness, tester);
      expect(RailState.extended.value, isFalse);
      expect(railExtended(tester), isFalse);
    },
  );

  testWidgets(
    'BRANCH preserves_other_stubs: a rail toggle keeps the language stub',
    (tester) async {
      final harness = SettingsHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);
      addTearDown(() => RailState.extended.value = false);

      // A pre-existing language override must survive a rail write.
      await harness.overridesFile.writeAsString('{"lang": "pl"}');
      await harness.pumpApp(tester);

      await toggleRail(tester); // expand
      final overrides = harness.readOverrides();
      expect(overrides?['lang'], 'pl'); // not dropped by the rail write
      expect(overrides?['railExtended'], isTrue);
    },
  );
}
