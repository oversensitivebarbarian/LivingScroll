import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/paths/path_colors.dart';
import 'package:living_scroll/services/latex/latex_preamble.dart';

/// Unit coverage for the LaTeX preamble / title page.
void main() {
  group('latexPreamble', () {
    final preamble = latexPreamble(langCode: 'en');

    test('book / A4 under XeLaTeX packages (column count is now a body '
        'command, not a \\documentclass option — see latex_exporter.dart)', () {
      expect(preamble, contains(r'\documentclass[11pt,a4paper,openany]{book}'));
      expect(preamble, isNot(contains('twocolumn')));
      expect(preamble, contains(r'\usepackage{fontspec}'));
      expect(preamble, contains(r'\usepackage{polyglossia}'));
      expect(preamble, contains(r'\usepackage{eso-pic}'));
      expect(preamble, contains(r'\usepackage[normalem]{ulem}'));
      expect(preamble, contains(r'\usepackage{fancyhdr}'));
      expect(preamble, contains(r'\usepackage{hyperref}'));
      expect(preamble, contains(r'\newcommand{\pathdot}'));
      expect(preamble, contains(r'\newcommand{\pathcircle}'));
      // XeLaTeX, not pdfLaTeX.
      expect(preamble, isNot(contains('inputenc')));
      expect(preamble, isNot(contains('fontenc')));
    });

    test('sets the main language from the adventure language code', () {
      expect(
        latexPreamble(langCode: 'pl'),
        contains(r'\setmainlanguage{polish}'),
      );
      expect(
        latexPreamble(langCode: 'de'),
        contains(r'\setmainlanguage{german}'),
      );
      // zh/ja have no polyglossia coverage -> english fallback (still compiles).
      expect(
        latexPreamble(langCode: 'zh'),
        contains(r'\setmainlanguage{english}'),
      );
      expect(
        latexPreamble(langCode: ''),
        contains(r'\setmainlanguage{english}'),
      );
    });

    test('defines every path colour from pathColors (source of truth)', () {
      // Exactly one \definecolor per path colour.
      expect(
        RegExp(r'\\definecolor').allMatches(preamble).length,
        pathColors.length,
      );
      for (final p in pathColors) {
        final name = latexColorNameForPathId(p.id);
        final hex = latexHexFor(p.color);
        expect(preamble, contains('\\definecolor{$name}{HTML}{$hex}'));
      }
    });

    test('spot-check the authored hex values (path colors)', () {
      expect(preamble, contains(r'\definecolor{pathYellow}{HTML}{F0C800}'));
      expect(preamble, contains(r'\definecolor{pathRed}{HTML}{D22828}'));
      expect(preamble, contains(r'\definecolor{pathOrange}{HTML}{E66400}'));
    });

    test('\\pathcircle scales the bullet glyph to row height (1em), '
        're-centres it on the baseline, and is PDF-bookmark-safe (it now '
        'lives inside a \\subsection{...} heading)', () {
      expect(preamble, contains(r'\resizebox{!}{1em}{$\bullet$}'));
      expect(preamble, contains(r'\raisebox{-0.15em}'));
      expect(
        preamble,
        contains(r'\newcommand{\pathcircle}[1]{\texorpdfstring{'),
      );
    });

    test('latexFontFallbackBlock: never relies on fontspec\'s implicit '
        'Latin-Modern-OTF default (a real reported compile failure when '
        'those OTF faces are missing) — tries a cascade of common,  '
        'NEVER-vendored system/TeX-Live fonts via \\IfFontExistsTF, braces '
        'balanced', () {
      final block = latexFontFallbackBlock();
      expect(block, contains(r'\IfFontExistsTF{Latin Modern Roman}'));
      expect(block, contains(r'\IfFontExistsTF{TeX Gyre Termes}'));
      expect(block, contains(r'\IfFontExistsTF{Noto Serif}'));
      expect(block, contains(r'\IfFontExistsTF{DejaVu Serif}'));
      expect(block, contains(r'\IfFontExistsTF{Liberation Serif}'));
      expect(block, contains(r'\setmainfont{Latin Modern Roman}'));
      // Every \IfFontExistsTF{...}{...}{ opens exactly one extra brace (the
      // false branch, left open to nest the next candidate); the block must
      // close them all.
      final opens = '{'.allMatches(block).length;
      final closes = '}'.allMatches(block).length;
      expect(opens, closes);
    });

    test('the preamble includes the font fallback block right after loading '
        'fontspec (before \\setmainlanguage/graphicx/etc.)', () {
      final fontspecAt = preamble.indexOf(r'\usepackage{fontspec}');
      final fallbackAt = preamble.indexOf(r'\IfFontExistsTF');
      final polyglossiaAt = preamble.indexOf(r'\usepackage{polyglossia}');
      expect(fontspecAt, greaterThan(-1));
      expect(fallbackAt, greaterThan(fontspecAt));
      expect(fallbackAt, lessThan(polyglossiaAt));
    });

    test('latexPageNumberingBlock: every page number is in the FOOTER at '
        'the OUTER margin (LE/RO, book is twoside), consistently — fixes '
        'numbering that used to jump between the header (book\'s default '
        '\\pagestyle{headings}) and a centered footer (the plain style '
        '\\chapter forces on its own opening page)', () {
      final block = latexPageNumberingBlock();
      expect(block, contains(r'\pagestyle{fancy}'));
      expect(block, contains(r'\fancypagestyle{plain}'));
      // Outer-margin placement, not centered/inner: Left on Even, Right on Odd.
      expect(
        RegExp(r'\\fancyfoot\[LE,RO\]\{\\thepage\}').allMatches(block).length,
        2,
      );
      // No header content (running heads), no rule line under it.
      expect(RegExp(r'\\fancyhf\{\}').allMatches(block).length, 2);
      expect(
        RegExp(
          r'\\renewcommand\{\\headrulewidth\}\{0pt\}',
        ).allMatches(block).length,
        2,
      );
    });

    test(
      'the preamble sets up page numbering after loading fancyhdr/hyperref',
      () {
        final fancyhdrAt = preamble.indexOf(r'\usepackage{fancyhdr}');
        final pagestyleAt = preamble.indexOf(r'\pagestyle{fancy}');
        expect(fancyhdrAt, greaterThan(-1));
        expect(pagestyleAt, greaterThan(fancyhdrAt));
      },
    );
  });

  group('helpers', () {
    test('polyglossiaLanguageFor maps codes and falls back to english', () {
      expect(polyglossiaLanguageFor('fr'), 'french');
      expect(polyglossiaLanguageFor('PT'), 'portuguese'); // case-insensitive
      expect(polyglossiaLanguageFor('ja'), 'english');
      expect(polyglossiaLanguageFor('xx'), 'english');
    });

    test('polyglossiaLanguageFor also tolerates an endonym or a legacy '
        'English exonym (normalizeLanguageCode)', () {
      expect(polyglossiaLanguageFor('Deutsch'), 'german'); // endonym
      expect(polyglossiaLanguageFor('German'), 'german'); // exonym
      expect(polyglossiaLanguageFor('Polski'), 'polish'); // endonym
    });

    test('normalizeLanguageCode: exact code (any case), endonym, and exonym '
        'all resolve to the canonical lowercase ISO code; unrecognized input '
        'is just trimmed/lower-cased, not dropped', () {
      expect(normalizeLanguageCode('pl'), 'pl');
      expect(normalizeLanguageCode('PL'), 'pl');
      expect(normalizeLanguageCode(' Pt '), 'pt');
      expect(normalizeLanguageCode('Polski'), 'pl');
      expect(normalizeLanguageCode('Polish'), 'pl');
      expect(normalizeLanguageCode('xx'), 'xx');
      expect(normalizeLanguageCode(''), '');
    });

    test('latexColorNameForPathId capitalizes the id', () {
      expect(latexColorNameForPathId('violet'), 'pathViolet');
      expect(latexColorNameForPathId('blue'), 'pathBlue');
    });

    test('latexHexFor drops alpha and upper-cases', () {
      expect(latexHexFor(const Color(0xFFF0C800)), 'F0C800');
      expect(
        latexHexFor(const Color(0xFF009E50)),
        '009E50',
      ); // leading zero kept
    });
  });

  group('latexTitlePage', () {
    test(
      'renders provided fields, omits empty ones — TEXT ONLY, no cover '
      '(the cover is its own full-bleed page, latexCoverPage) and no '
      '`metadata.system` line either (an internal identifier, not content)',
      () {
        final page = latexTitlePage(
          name: 'The Pack',
          version: '1.0.0',
          author: '',
        );
        expect(page, contains(r'\begin{titlepage}'));
        expect(page, contains('The Pack'));
        expect(page, contains('1.0.0'));
        expect(page, isNot(contains(r'\includegraphics')));
        // Empty author -> no author line at all.
        expect(page, isNot(contains(r'\vspace{0.5em}{\large }')));
      },
    );

    test('escapes the title', () {
      final page = latexTitlePage(name: 'A & B');
      expect(page, contains(r'A \& B'));
    });

    test('nothing to show -> empty string', () {
      expect(latexTitlePage(name: ''), '');
    });
  });

  group('latexCoverPage', () {
    test('a cover asset -> a full-bleed one-shot background + a blank page', () {
      final page = latexCoverPage('assets/cover.png');
      expect(page, contains(r'\AddToShipoutPictureBG*'));
      expect(
        page,
        contains(
          r'\includegraphics[width=\paperwidth,height=\paperheight]{assets/cover.png}',
        ),
      );
      expect(page, contains(r'\thispagestyle{empty}'));
      expect(page, contains(r'\clearpage'));
    });

    test('null or empty -> no page at all', () {
      expect(latexCoverPage(null), '');
      expect(latexCoverPage(''), '');
    });
  });

  group('latexBlankPage', () {
    test('a genuinely blank page — no header/footer/number, no content', () {
      final page = latexBlankPage();
      expect(page, contains(r'\thispagestyle{empty}'));
      expect(page, contains(r'\mbox{}'));
      expect(page, contains(r'\clearpage'));
      // Nothing else on it — no title text, no graphics.
      expect(page, isNot(contains(r'\includegraphics')));
      expect(page, isNot(contains(r'\begin{titlepage}')));
    });
  });

  group('latexTableOfContentsPage', () {
    test('resets the page counter to 2 BEFORE \\tableofcontents, so it is '
        'the first page to show a number, displayed as page 2', () {
      final page = latexTableOfContentsPage();
      expect(page, contains(r'\setcounter{page}{2}'));
      expect(page, contains(r'\tableofcontents'));
      expect(page, contains(r'\clearpage'));
      expect(
        page.indexOf(r'\setcounter{page}{2}'),
        lessThan(page.indexOf(r'\tableofcontents')),
      );
      expect(
        page.indexOf(r'\tableofcontents'),
        lessThan(page.indexOf(r'\clearpage')),
      );
    });
  });
}
