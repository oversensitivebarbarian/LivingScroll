// Leaving the dirty new-adventure form prompts a two-option dialog (Abandon /
// Cancel) — there is no "Save" here, since Create is the only way to persist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/create_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // STEP 1..3: open the form, dirty it, tap Home -> the prompt appears.
  Future<CreateHarness> dirtyFormThenLeave(WidgetTester tester) async {
    final harness = CreateHarness();
    await harness.setUp();
    addTearDown(harness.tearDown);

    await harness.pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.new')));
    await tester.pumpAndSettle();

    // STEP 2: dirty the form.
    await tester.enterText(
      find.byKey(const ValueKey('create_new.field.title')),
      'TEST',
    );
    await tester.pumpAndSettle();

    // STEP 3: try to leave -> the prompt intercepts.
    await tester.tap(find.byKey(const ValueKey('nav.home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create_new.unsaved.dialog')), findsOne);
    expect(find.byKey(const ValueKey('create_new.field.title')), findsOne);
    expect(harness.projects(), isEmpty);
    return harness;
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;

  testWidgets('BRANCH abandon: discards the form and navigates to Home', (
    tester,
  ) async {
    final harness = await dirtyFormThenLeave(tester);

    await tester.tap(find.byKey(const ValueKey('create_new.unsaved.abandon')));
    await tester.pumpAndSettle();

    // Navigated to Home; the form is gone and nothing was created.
    expect(selectedIndex(tester), 0);
    expect(find.byKey(const ValueKey('create_new.field.title')), findsNothing);
    expect(harness.projects(), isEmpty);
  });

  testWidgets('BRANCH cancel: dismisses the prompt and stays on the form', (
    tester,
  ) async {
    final harness = await dirtyFormThenLeave(tester);

    await tester.tap(find.byKey(const ValueKey('create_new.unsaved.cancel')));
    await tester.pumpAndSettle();

    // Dialog gone, still on the Create form with the input intact.
    expect(
      find.byKey(const ValueKey('create_new.unsaved.dialog')),
      findsNothing,
    );
    expect(selectedIndex(tester), 1);
    final title = tester.widget<TextField>(
      find.byKey(const ValueKey('create_new.field.title')),
    );
    expect(title.controller?.text, 'TEST');
    expect(harness.projects(), isEmpty);
  });

  // Re-tapping the CURRENT destination (Create) while the new-adventure form is
  // open returns to the Create destination's base view (the grid), through the
  // same isDirty guard.
  testWidgets(
    'BRANCH retap_create_abandon: re-tapping Create mid-form -> Abandon returns to the grid',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);

      await harness.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav.create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('create_new.field.title')),
        'TEST',
      );
      await tester.pumpAndSettle();

      // Re-tap the ALREADY-SELECTED Create destination -> the prompt intercepts.
      await tester.tap(find.byKey(const ValueKey('nav.create')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create_new.unsaved.dialog')), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('create_new.unsaved.abandon')),
      );
      await tester.pumpAndSettle();

      // Back on the Create grid (form gone); still on the Create destination.
      expect(
        find.byKey(const ValueKey('create_new.field.title')),
        findsNothing,
      );
      expect(selectedIndex(tester), 1);
      expect(harness.projects(), isEmpty);
    },
  );

  testWidgets(
    'BRANCH retap_create_pristine: re-tapping Create on a pristine form returns to the grid (no prompt)',
    (tester) async {
      final harness = CreateHarness();
      await harness.setUp();
      addTearDown(harness.tearDown);

      await harness.pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav.create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create.new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create_new.field.title')), findsOne);

      // Pristine form -> re-tapping Create closes it with no prompt.
      await tester.tap(find.byKey(const ValueKey('nav.create')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('create_new.unsaved.dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('create_new.field.title')),
        findsNothing,
      );
      expect(selectedIndex(tester), 1);
    },
  );
}
