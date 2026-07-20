import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/settings/settings_overrides.dart';

/// The `railExtended` stub persists the navigation rail's open/collapsed state
/// in overrides.json. Collapsed is the application default, so only the
/// expanded value (`true`) is ever serialized.
void main() {
  group('railExtended stub', () {
    test('defaults to collapsed and resolves via railExtendedOn', () {
      const o = SettingsOverrides();
      expect(o.railExtended, isNull);
      expect(o.railExtendedOn, isFalse);
      expect(const SettingsOverrides(railExtended: true).railExtendedOn, isTrue);
    });

    test('writes the stub ONLY when expanded', () {
      expect(const SettingsOverrides(railExtended: true).toJson(),
          containsPair('railExtended', true));
      // Collapsed / absent drops the stub entirely.
      expect(const SettingsOverrides(railExtended: false).toJson(),
          isNot(contains('railExtended')));
      expect(const SettingsOverrides().toJson(),
          isNot(contains('railExtended')));
    });

    test('round-trips through JSON', () {
      const o = SettingsOverrides(railExtended: true);
      final back = SettingsOverrides.fromJson(o.toJson());
      expect(back.railExtendedOn, isTrue);
      expect(back, o);
    });

    test('counts toward isEmpty only when expanded', () {
      expect(const SettingsOverrides().isEmpty, isTrue);
      expect(const SettingsOverrides(railExtended: false).isEmpty, isTrue);
      expect(const SettingsOverrides(railExtended: true).isEmpty, isFalse);
    });

    test('is part of equality / hashCode', () {
      expect(const SettingsOverrides(railExtended: true),
          isNot(const SettingsOverrides()));
      expect(const SettingsOverrides(railExtended: true).hashCode,
          const SettingsOverrides(railExtended: true).hashCode);
    });

    test('coexists with the other stubs', () {
      const o = SettingsOverrides(
        lang: 'pl',
        mode: 'dark',
        autoplay: false,
        railExtended: true,
      );
      expect(SettingsOverrides.fromJson(o.toJson()), o);
      expect(
          o.toJson(),
          allOf(
            containsPair('lang', 'pl'),
            containsPair('mode', 'dark'),
            containsPair('autoplay', false),
            containsPair('railExtended', true),
          ));
    });
  });
}
