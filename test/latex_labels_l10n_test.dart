import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_model.dart';
import 'package:living_scroll/services/latex/latex_preamble.dart';
import 'package:living_scroll/services/latex/latex_scenes.dart';

/// Coverage for LatexLabels.forLanguage: document headings
/// localize to the ADVENTURE's language, with an English fallback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Polish headings for a pl adventure', () {
    final labels = LatexLabels.forLanguage('pl');
    expect(labels.scenes, 'Sceny');
    expect(labels.nextScenes, 'Kolejne sceny');
    expect(labels.backstory, 'Historia');
    expect(labels.sceneTypeStart, 'scena początkowa');
    expect(labels.paths, 'Ścieżki');
  });

  test('German headings for a de adventure', () {
    final labels = LatexLabels.forLanguage('de');
    expect(labels.scenes, 'Szenen');
    expect(labels.narration, 'Erzählung');
    expect(labels.paths, 'Pfade');
    expect(labels.sceneTypeStart, 'Startszene');
    expect(labels.sceneTypeEnd, 'Endszene');
  });

  test('an unsupported or empty code falls back to English', () {
    expect(LatexLabels.forLanguage('xx').scenes, 'Scenes');
    expect(LatexLabels.forLanguage('').nextScenes, 'Next scenes');
    expect(LatexLabels.forLanguage('xx').paths, 'Paths');
    expect(LatexLabels.forLanguage('xx').sceneTypeStart, 'opening scene');
  });

  test('the generator emits the localized headings', () {
    final doc = {
      'scenes': [
        {'scene_uuid': 's1', 'name': 'Start', 'scene_type': 'start'},
      ],
    };
    final out = latexScenesChapter(
      doc,
      LatexLabels.forLanguage('pl'),
      AssetSink((_) => true),
    );
    expect(out, contains(r'\chapter{Sceny}'));
    expect(out, contains('(scena początkowa)'));
  });

  group('pageReference — localized "page <ref>" word order', () {
    test('English: word BEFORE the ref', () {
      expect(
        LatexLabels.english.pageReference(r'\pageref{scene:s1}'),
        r'page \pageref{scene:s1}',
      );
    });

    test('Polish: "strona" before the ref', () {
      expect(
        LatexLabels.forLanguage('pl').pageReference(r'\pageref{scene:s1}'),
        r'strona \pageref{scene:s1}',
      );
    });

    test('German: "Seite" before the ref', () {
      expect(
        LatexLabels.forLanguage('de').pageReference(r'\pageref{scene:s1}'),
        r'Seite \pageref{scene:s1}',
      );
    });

    test('Chinese: 第/页 wrap the ref (no leading/trailing space)', () {
      expect(
        LatexLabels.forLanguage('zh').pageReference(r'\pageref{scene:s1}'),
        '第\\pageref{scene:s1}页',
      );
    });

    test('Japanese: the ref comes BEFORE ページ', () {
      expect(
        LatexLabels.forLanguage('ja').pageReference(r'\pageref{scene:s1}'),
        '\\pageref{scene:s1}ページ',
      );
    });

    test('French: "page" before the ref', () {
      expect(
        LatexLabels.forLanguage('fr').pageReference(r'\pageref{scene:s1}'),
        r'page \pageref{scene:s1}',
      );
    });

    test('Spanish: "página" before the ref', () {
      expect(
        LatexLabels.forLanguage('es').pageReference(r'\pageref{scene:s1}'),
        r'página \pageref{scene:s1}',
      );
    });

    test('Portuguese: "página" before the ref', () {
      expect(
        LatexLabels.forLanguage('pt').pageReference(r'\pageref{scene:s1}'),
        r'página \pageref{scene:s1}',
      );
    });

    test('an unsupported/empty code falls back to English word order', () {
      expect(
        LatexLabels.forLanguage('xx').pageReference(r'\pageref{x}'),
        r'page \pageref{x}',
      );
    });

    test('AUDIT: every supported language (en/de/fr/pt/es/pl/zh/ja) '
        'resolves to its own distinct, non-English (except en/fr, which share '
        '"page") localized word — none silently falls back to the English '
        'template', () {
      const expected = {
        'en': r'page \pageref{x}',
        'de': r'Seite \pageref{x}',
        'fr': r'page \pageref{x}',
        'es': r'página \pageref{x}',
        'pt': r'página \pageref{x}',
        'pl': r'strona \pageref{x}',
        'zh': '第\\pageref{x}页',
        'ja': '\\pageref{x}ページ',
      };
      for (final entry in expected.entries) {
        expect(
          LatexLabels.forLanguage(entry.key).pageReference(r'\pageref{x}'),
          entry.value,
          reason: 'language "${entry.key}"',
        );
      }
    });
  });

  group('npcType — localized NPC "type" parenthetical, per system', () {
    test('7thsea2e: kind resolves via seaKindLabel, localized to Polish', () {
      final labels = LatexLabels.forLanguage('pl');
      expect(labels.npcType('7thsea2e', {'kind': 'villain'}), 'Złoczyńca');
    });

    test('7thsea2e: an unrecognized/missing kind resolves to null', () {
      final labels = LatexLabels.english;
      expect(labels.npcType('7thsea2e', {'kind': 'nonsense'}), isNull);
      expect(labels.npcType('7thsea2e', <String, dynamic>{}), isNull);
    });

    test('basic: no "type" concept at all -> always null', () {
      final labels = LatexLabels.english;
      expect(labels.npcType('basic', {'kind': 'villain'}), isNull);
    });

    test('stats that are not a Map (or absent) resolve to null', () {
      final labels = LatexLabels.english;
      expect(labels.npcType('7thsea2e', null), isNull);
      expect(labels.npcType('7thsea2e', 'not a map'), isNull);
    });

    test('the English default (LatexLabels.english) mirrors forLanguage', () {
      expect(
        LatexLabels.english.npcType('7thsea2e', {'kind': 'monster'}),
        LatexLabels.forLanguage('en').npcType('7thsea2e', {'kind': 'monster'}),
      );
    });
  });

  group('a case-varied / endonym / exonym language code still localizes '
      'correctly (regression: a stored "PL" made the preamble correctly say '
      '\\setmainlanguage{polish} — polyglossiaLanguageFor already lower-cases '
      '— while LatexLabels silently fell back to English, since its locale '
      'lookup compared case-sensitively)', () {
    test('an UPPERCASE ISO code ("PL") still selects Polish labels', () {
      final labels = LatexLabels.forLanguage('PL');
      expect(labels.scenes, 'Sceny');
      expect(labels.paths, 'Ścieżki');
      expect(
        labels.pageReference(r'\pageref{scene:s1}'),
        r'strona \pageref{scene:s1}',
      );
    });

    test('mixed-case ("De") still selects German labels', () {
      expect(LatexLabels.forLanguage('De').scenes, 'Szenen');
      expect(
        LatexLabels.forLanguage('De').pageReference(r'\pageref{x}'),
        r'Seite \pageref{x}',
      );
    });

    test('the endonym ("Polski") still selects Polish labels', () {
      expect(LatexLabels.forLanguage('Polski').scenes, 'Sceny');
      expect(
        LatexLabels.forLanguage('Polski').pageReference(r'\pageref{x}'),
        r'strona \pageref{x}',
      );
    });

    test('a legacy English exonym ("Polish") still selects Polish labels', () {
      expect(LatexLabels.forLanguage('Polish').scenes, 'Sceny');
      expect(
        LatexLabels.forLanguage('Polish').pageReference(r'\pageref{x}'),
        r'strona \pageref{x}',
      );
    });

    test('this case-varied code ALSO still drives the preamble\'s '
        '\\setmainlanguage correctly (unaffected by this bug, but verified '
        'so both halves stay in sync)', () {
      expect(polyglossiaLanguageFor('PL'), 'polish');
      expect(polyglossiaLanguageFor('De'), 'german');
      expect(polyglossiaLanguageFor('Polski'), 'polish');
      expect(polyglossiaLanguageFor('Polish'), 'polish');
    });

    test('normalizeLanguageCode: exact match, case-insensitive, endonym and '
        'exonym all resolve to the canonical lowercase code', () {
      expect(normalizeLanguageCode('pl'), 'pl');
      expect(normalizeLanguageCode('PL'), 'pl');
      expect(normalizeLanguageCode('Pl'), 'pl');
      expect(normalizeLanguageCode('Polski'), 'pl');
      expect(normalizeLanguageCode('Polish'), 'pl');
      expect(normalizeLanguageCode('ZH'), 'zh');
      expect(normalizeLanguageCode('日本語'), 'ja');
      // Truly unrecognized -> just trimmed/lower-cased, not silently dropped.
      expect(normalizeLanguageCode('xx'), 'xx');
    });
  });
}
