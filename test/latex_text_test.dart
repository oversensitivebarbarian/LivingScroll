import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_text.dart';

/// Unit coverage for the LaTeX text utilities:
/// escaping, paragraph handling, and Quill-Delta -> LaTeX with formatting.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A note stored as a Delta (JSON string). Quill requires the delta to end in a
  /// newline, so callers pass ops whose last insert ends with '\n'.
  String delta(List<Map<String, dynamic>> ops) => jsonEncode(ops);

  group('latexEscape', () {
    test('escapes the LaTeX specials', () {
      expect(latexEscape('a & b_c 50%'), r'a \& b\_c 50\%');
      expect(latexEscape(r'$#{}'), r'\$\#\{\}');
      expect(latexEscape('a~b^c'), r'a\textasciitilde{}b\textasciicircum{}c');
    });

    test('escapes a backslash without re-escaping inserted sequences', () {
      expect(latexEscape(r'a\b'), r'a\textbackslash{}b');
      // A lone backslash then an ampersand must not merge.
      expect(latexEscape(r'\&'), r'\textbackslash{}\&');
    });

    test('passes non-ASCII (CJK) text through unchanged', () {
      expect(latexEscape('日本語 & x'), r'日本語 \& x');
    });

    test('empty -> empty', () => expect(latexEscape(''), ''));
  });

  group('latexParagraphs', () {
    test('blank line -> paragraph break, single newline -> line break', () {
      expect(latexParagraphs('a\nb\n\nc'), 'a\\\\\nb\n\nc');
    });

    test('drops empty paragraphs and trims', () {
      expect(latexParagraphs('\n\nHello\n\n\n'), 'Hello');
    });

    test('empty -> empty', () => expect(latexParagraphs(''), ''));
  });

  group('latexFromNoteContent — inline formatting', () {
    test('bold run, with escaping inside and outside the wrap', () {
      final out = latexFromNoteContent(
        delta([
          {'insert': 'Hi '},
          {
            'insert': 'bold',
            'attributes': {'bold': true},
          },
          {'insert': ' & x\n'},
        ]),
      );
      expect(out, contains(r'\textbf{bold}'));
      expect(out, contains(r'\&')); // the ' & x' run is escaped
      expect(out, 'Hi \\textbf{bold} \\& x');
    });

    test('italic / underline / strike / code / link', () {
      expect(
        latexFromNoteContent(
          delta([
            {
              'insert': 'i',
              'attributes': {'italic': true},
            },
            {'insert': '\n'},
          ]),
        ),
        contains(r'\textit{i}'),
      );
      expect(
        latexFromNoteContent(
          delta([
            {
              'insert': 'u',
              'attributes': {'underline': true},
            },
            {'insert': '\n'},
          ]),
        ),
        contains(r'\underline{u}'),
      );
      expect(
        latexFromNoteContent(
          delta([
            {
              'insert': 's',
              'attributes': {'strike': true},
            },
            {'insert': '\n'},
          ]),
        ),
        contains(r'\sout{s}'),
      );
      expect(
        latexFromNoteContent(
          delta([
            {
              'insert': 'c',
              'attributes': {'code': true},
            },
            {'insert': '\n'},
          ]),
        ),
        contains(r'\texttt{c}'),
      );
      expect(
        latexFromNoteContent(
          delta([
            {
              'insert': 'site',
              'attributes': {'link': 'https://x.test/a#b'},
            },
            {'insert': '\n'},
          ]),
        ),
        contains(r'\href{https://x.test/a\#b}{site}'),
      );
    });

    test('nested attributes wrap deterministically (bold outside italic)', () {
      final out = latexFromNoteContent(
        delta([
          {
            'insert': 'x',
            'attributes': {'bold': true, 'italic': true},
          },
          {'insert': '\n'},
        ]),
      );
      expect(out, r'\textbf{\textit{x}}');
    });
  });

  group('latexFromNoteContent — blocks', () {
    test('bullet list of two items', () {
      final out = latexFromNoteContent(
        delta([
          {'insert': 'first'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'second'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
        ]),
      );
      expect(out, contains(r'\begin{itemize}'));
      expect(out, contains(r'\end{itemize}'));
      expect(RegExp(r'\\item').allMatches(out).length, 2);
      expect(out, contains(r'\item first'));
      expect(out, contains(r'\item second'));
    });

    test('ordered list -> enumerate', () {
      final out = latexFromNoteContent(
        delta([
          {'insert': 'one'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
        ]),
      );
      expect(out, contains(r'\begin{enumerate}'));
    });

    test('two paragraphs separated by a blank line', () {
      final out = latexFromNoteContent(
        delta([
          {'insert': 'para one\n\npara two\n'},
        ]),
      );
      expect(out, 'para one\n\npara two');
    });
  });

  group('latexFromNoteContent — edge cases', () {
    test('legacy plain text is escaped', () {
      expect(latexFromNoteContent('100\$'), r'100\$');
    });

    test('empty -> empty', () {
      expect(latexFromNoteContent(''), '');
    });
  });
}
