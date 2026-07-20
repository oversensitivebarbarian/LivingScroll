import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_model.dart';
import 'package:living_scroll/services/latex/latex_paths.dart';

/// Unit coverage for the Paths chapter generator: a `\chapter` emitted only
/// when the adventure defines any paths, with one `\subsection` per path —
/// `\subsection{\pathcircle{colour} \hspace{0.4em} name}` — the row-height
/// coloured circle INSIDE the heading, tied to the name by a fixed gap; the
/// description follows as an ordinary body paragraph; then, when any scene
/// references the path, a linked list of those scenes with a localized
/// page-number parenthetical.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no paths -> empty output (no chapter at all)', () {
    final out = latexPathsChapter({'paths': <dynamic>[]}, LatexLabels.english);
    expect(out, isEmpty);
  });

  test('an absent paths[] key also produces empty output', () {
    final out = latexPathsChapter({}, LatexLabels.english);
    expect(out, isEmpty);
  });

  test(
      'emits the chapter heading and a subsection per path (circle + gap + '
      'name in the heading, description as a plain paragraph below), in '
      'roster order', () {
    final doc = {
      'paths': [
        {
          'name': 'Red path',
          'color': 'red',
          'description': 'The road of blood & fire.'
        },
        {'name': 'Blue path', 'color': 'blue', 'description': 'Calm waters.'},
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(out, contains(r'\chapter{Paths}'));
    expect(out,
        contains(r'\subsection{\pathcircle{pathRed} \hspace{0.4em} Red path}'));
    expect(out, contains(r'The road of blood \& fire.'));
    expect(
        out,
        contains(
            r'\subsection{\pathcircle{pathBlue} \hspace{0.4em} Blue path}'));
    expect(out, contains('Calm waters.'));
    expect(
        out.indexOf(r'\subsection{\pathcircle{pathRed} \hspace{0.4em} Red path}'),
        lessThan(out.indexOf(
            r'\subsection{\pathcircle{pathBlue} \hspace{0.4em} Blue path}')));
    // The description is a plain paragraph BELOW the heading — no leading
    // circle tied to it any more (the circle moved into the heading).
    expect(
        out.indexOf(
            r'\subsection{\pathcircle{pathRed} \hspace{0.4em} Red path}'),
        lessThan(out.indexOf(r'The road of blood \& fire.')));
    expect(out, isNot(contains(r'~The road')));
  });

  test('a path with an empty description still shows its heading circle',
      () {
    final doc = {
      'paths': [
        {'name': 'Green path', 'color': 'green', 'description': ''}
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(
        out,
        contains(
            r'\subsection{\pathcircle{pathGreen} \hspace{0.4em} Green path}'));
  });

  test('an unresolvable/empty color -> plain \\subsection{name}, no crash',
      () {
    final doc = {
      'paths': [
        {'name': 'Mystery path', 'color': 'plaid', 'description': 'Huh.'},
        {'name': 'Colorless path', 'description': 'No color at all.'},
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(out, contains(r'\subsection{Mystery path}'));
    expect(out, contains('Huh.'));
    expect(out, contains(r'\subsection{Colorless path}'));
    expect(out, contains('No color at all.'));
    expect(out, isNot(contains(r'\pathcircle')));
  });

  test('a path without a name is skipped (no title to give it)', () {
    final doc = {
      'paths': [
        {'color': 'yellow', 'description': 'Nameless.'},
        {'name': 'Named', 'color': 'orange', 'description': 'Has a name.'},
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(out, isNot(contains('Nameless.')));
    expect(
        out,
        contains(
            r'\subsection{\pathcircle{pathOrange} \hspace{0.4em} Named}'));
  });

  test('the chapter heading localizes to the adventure language', () {
    final doc = {
      'paths': [
        {'name': 'Red path', 'color': 'red', 'description': 'x'}
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.forLanguage('pl'));
    expect(out, contains(r'\chapter{Ścieżki}'));
  });

  test('lists the path\'s scenes, in roster order, linked with a localized '
      'page-number parenthetical, right after the description', () {
    final doc = {
      'paths': [
        {'name': 'Red path', 'color': 'red', 'description': 'A dangerous road.'}
      ],
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'start',
          'path_names': ['Red path'],
        },
        {
          'scene_uuid': 's2',
          'name': 'Gate',
          'scene_type': 'standard',
          'path_names': ['Blue path'], // different path -> excluded
        },
        {
          'scene_uuid': 's3',
          'name': 'Keep',
          'scene_type': 'end',
          'path_names': ['Red path'],
        },
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(
        out,
        contains(
            r'\item \hyperref[scene:s1]{Cave} (page \pageref{scene:s1})'));
    expect(
        out,
        contains(
            r'\item \hyperref[scene:s3]{Keep} (page \pageref{scene:s3})'));
    expect(out, isNot(contains('scene:s2')));
    expect(out, contains(r'\begin{itemize}'));
    expect(out, contains(r'\end{itemize}'));
    // The list follows the description, in scene roster order.
    final desc = out.indexOf('A dangerous road.');
    final cave = out.indexOf(r'\item \hyperref[scene:s1]');
    final keep = out.indexOf(r'\item \hyperref[scene:s3]');
    expect(desc, lessThan(cave));
    expect(cave, lessThan(keep));
  });

  test('the page-number word localizes to the adventure language (Polish '
      '"strona")', () {
    final doc = {
      'paths': [
        {'name': 'Red path', 'color': 'red', 'description': 'x'}
      ],
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'start',
          'path_names': ['Red path'],
        },
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.forLanguage('pl'));
    expect(
        out,
        contains(
            r'\item \hyperref[scene:s1]{Cave} (strona \pageref{scene:s1})'));
  });

  test('a path with no scenes on it gets no list at all', () {
    final doc = {
      'paths': [
        {'name': 'Lonely path', 'color': 'violet', 'description': 'Unused.'}
      ],
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'start',
          'path_names': ['Other path'],
        },
      ],
    };
    final out = latexPathsChapter(doc, LatexLabels.english);
    expect(out, isNot(contains(r'\begin{itemize}')));
    expect(out, isNot(contains(r'\item')));
  });
}
