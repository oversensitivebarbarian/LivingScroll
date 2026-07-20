import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/supported_languages.dart';

void main() {
  test('the catalogue is the 8 supported languages, shown as endonyms', () {
    expect(SupportedLanguages.names.keys,
        containsAll(<String>['en', 'de', 'fr', 'pt', 'es', 'pl', 'zh', 'ja']));
    expect(SupportedLanguages.names.length, 8);
    expect(SupportedLanguages.names['pl'], 'Polski');
    expect(SupportedLanguages.names['de'], 'Deutsch');
  });

  group('codeFor', () {
    test('empty / whitespace -> null (unspecified)', () {
      expect(SupportedLanguages.codeFor(''), isNull);
      expect(SupportedLanguages.codeFor('   '), isNull);
    });

    test('a known ISO code passes through', () {
      expect(SupportedLanguages.codeFor('en'), 'en');
      expect(SupportedLanguages.codeFor('ja'), 'ja');
    });

    test('an endonym maps to its code (case-insensitive)', () {
      expect(SupportedLanguages.codeFor('Polski'), 'pl');
      expect(SupportedLanguages.codeFor('deutsch'), 'de');
      expect(SupportedLanguages.codeFor('中文'), 'zh');
    });

    test('an English exonym maps to its code', () {
      expect(SupportedLanguages.codeFor('English'), 'en');
      expect(SupportedLanguages.codeFor('german'), 'de');
      expect(SupportedLanguages.codeFor('Japanese'), 'ja');
    });

    test('an unrecognized value -> null (preserved verbatim by callers)', () {
      expect(SupportedLanguages.codeFor('Klingon'), isNull);
      expect(SupportedLanguages.codeFor('xx'), isNull);
    });

    test('isKnown reflects the catalogue', () {
      expect(SupportedLanguages.isKnown('pl'), isTrue);
      expect(SupportedLanguages.isKnown('xx'), isFalse);
    });
  });
}
