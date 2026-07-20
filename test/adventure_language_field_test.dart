import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/adventure_settings_controller.dart';
import 'package:living_scroll/create/create_new_controller.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_settings_screen.dart';
import 'package:living_scroll/screens/create_new_screen.dart';

/// The adventure Language field (new-adventure + Adventure settings forms) is a
/// DROPDOWN over the app's supported languages, stored as an ISO code in
/// `metadata.language`, and OPTIONAL (a "not specified" entry keeps it clearable;
/// a legacy free-text value that maps to no known language is preserved).
Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  // A tall surface so every metadata field is laid out on-screen (the forms
  // scroll otherwise and off-screen fields aren't hit-testable).
  Future<void> tallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('new-adventure form', () {
    testWidgets('language is a dropdown, defaults to unset, stores ISO code',
        (tester) async {
      final controller = CreateNewController();
      addTearDown(controller.dispose);
      await tallSurface(tester);

      await tester.pumpWidget(
          _app(CreateNewScreen(controller: controller, onCreated: (_) {})));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('create_new.field.language'));
      expect(field, findsOneWidget);
      // It is a dropdown, NOT a plain text field.
      expect(tester.widget(field), isA<DropdownButtonFormField<String>>());

      // Default: no language chosen (optional field).
      expect(controller.language, '');
      expect(controller.metadata['language'], '');

      // Pick Polish -> the ISO code is stored.
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('create_new.field.language.item.pl')).last);
      await tester.pumpAndSettle();
      expect(controller.language, 'pl');
      expect(controller.metadata['language'], 'pl');

      // Pick "not specified" -> clears back to empty.
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('create_new.field.language.item.unset')).last);
      await tester.pumpAndSettle();
      expect(controller.language, '');
    });
  });

  group('Adventure settings form', () {
    AdventureSettingsController loaded(String language) {
      final c = AdventureSettingsController();
      c.loadFrom({
        'metadata': {'name': 'Demo', 'system': 'basic', 'language': language},
      });
      return c;
    }

    Future<void> pump(WidgetTester tester,
        AdventureSettingsController controller) async {
      await tallSurface(tester);
      await tester.pumpWidget(_app(AdventureSettingsScreen(
          controller: controller, onSave: () async {})));
      await tester.pumpAndSettle();
    }

    testWidgets('preselects the stored ISO code as its endonym', (tester) async {
      final controller = loaded('de');
      addTearDown(controller.dispose);
      await pump(tester, controller);

      expect(find.byKey(const ValueKey('game.settings.field.language')),
          findsOneWidget);
      // German shows as its endonym; loading a value alone is not dirty.
      expect(find.text('Deutsch'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('normalizes a legacy exonym to a supported code', (tester) async {
      final controller = loaded('English'); // legacy free text
      addTearDown(controller.dispose);
      await pump(tester, controller);

      // "English" is the endonym for the normalized 'en'.
      expect(find.text('English'), findsOneWidget);
      // No legacy escape-hatch item is needed (it maps to a known code).
      expect(find.byKey(const ValueKey('game.settings.field.language.item.legacy')),
          findsNothing);
    });

    testWidgets('preserves an unrecognized legacy value', (tester) async {
      final controller = loaded('Klingon');
      addTearDown(controller.dispose);
      await pump(tester, controller);

      // Shown verbatim and kept — a legacy item exists for it.
      expect(find.text('Klingon'), findsOneWidget);
      expect(find.byKey(const ValueKey('game.settings.field.language.item.legacy')),
          findsOneWidget);
      expect(controller.language, 'Klingon');
      expect(controller.isDirty, isFalse);
    });

    testWidgets('selecting a language marks the form dirty and stores the code',
        (tester) async {
      final controller = loaded('de');
      addTearDown(controller.dispose);
      await pump(tester, controller);

      final field = find.byKey(const ValueKey('game.settings.field.language'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('game.settings.field.language.item.fr')).last);
      await tester.pumpAndSettle();

      expect(controller.language, 'fr');
      expect(controller.metadata['language'], 'fr');
      expect(controller.isDirty, isTrue);
    });
  });
}
