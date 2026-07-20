import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_model.dart';
import 'package:living_scroll/services/latex/latex_scenes.dart';

/// Unit coverage for the Chapter-1 (scenes) generator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A small adventure exercising every scene block.
  Map<String, dynamic> doc() => {
    'metadata': {'language': 'en'},
    'paths': [
      {'name': 'Red path', 'color': 'red'},
    ],
    'key_events': [
      {'key_event_uuid': 'ke1', 'name': 'Met duke'},
    ],
    'npcs': [
      {
        'npc_uuid': 'n1',
        'name': 'Guard',
        'icon_image': 'ic1',
        'visibility_rules': {
          'op': 'and',
          'key_events': ['ke1'],
        },
      },
    ],
    'notes': [
      {
        'note_uuid': 'nt1',
        'note_name': 'Secret',
        'note_content': 'A & B',
        'visibility_rules': {
          'op': 'or',
          'key_events': ['ke1'],
        },
      },
    ],
    'images': [
      {'image_uuid': 'im1', 'name': 'Map'},
    ],
    'scenes': [
      {
        'scene_uuid': 's1',
        'name': 'Opening',
        'scene_type': 'start',
        'path_names': ['Red path'],
        'bg_image': 'bg1',
        'description': 'It begins & continues.',
        'npcs': ['Guard'],
        'notes': ['nt1'],
        'images': ['im1'],
        'next_scenes': ['s2', 'sX'], // sX does not exist
      },
      {
        'scene_uuid': 's2',
        'name': 'Gate',
        'scene_type': 'standard',
        'description': '',
        'visibility_rules': {
          'op': 'and',
          'key_events': ['ke1'],
        },
      },
    ],
  };

  AssetSink present() => AssetSink((_) => true);

  test('scenes render in roster order, each a labelled section', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'\chapter{Scenes}'));
    expect(out, contains(r'\label{scene:s1}'));
    expect(out, contains(r'\label{scene:s2}'));
    expect(
      out.indexOf(r'\section[{Opening'),
      lessThan(out.indexOf(r'\section[{Gate')),
    );
  });

  test(
    'every scene starts on a new page (\\clearpage BETWEEN scenes only)',
    () {
      final out = latexScenesChapter(doc(), LatexLabels.english, present());
      // Two scenes -> exactly one \clearpage, placed between the two sections.
      // (No \clearpage before the first: the chapter heading already opens its
      // fresh page for it.)
      expect(r'\clearpage'.allMatches(out).length, 1);
      final clear = out.indexOf(r'\clearpage');
      expect(clear, greaterThan(out.indexOf(r'\section[{Opening')));
      expect(clear, lessThan(out.indexOf(r'\section[{Gate')));
      expect(
        out.substring(0, out.indexOf(r'\section[{Opening')),
        isNot(contains(r'\clearpage')),
      );
    },
  );

  test('title carries the localized scene type and a path-colour dot', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, contains('(opening scene)'));
    expect(out, contains(r'\pathdot{pathRed}'));
  });

  test('the short (mark/TOC) title omits \\pathdot so a class whose default '
      '\\sectionmark uppercases its argument never uppercases a \\color '
      'name into an undefined xcolor colour', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(
      out,
      contains(
        r'\section[{Opening (opening scene)}]'
        r'{Opening (opening scene) \pathdot{pathRed}}',
      ),
    );
  });

  test('the background renders in a NON-floating \\begin{center}, never a '
      'floating \\begin{figure}/\\begin{figure*} — a float can drift away '
      'from its declared position to wherever LaTeX\'s placement algorithm '
      'next allows it (a real reported bug when the body was two columns: '
      'the background ended up rendering "at the end" of the scene instead '
      'of right after the title); placed immediately after the \\label, '
      'before Narration', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, isNot(contains(r'\begin{figure')));
    expect(out, contains(r'\begin{center}'));
    expect(
      out,
      contains(r'\includegraphics[width=\textwidth]{assets/bg_bg1.png}'),
    );
    expect(out, contains(r'\end{center}'));
    final label = out.indexOf(r'\label{scene:s1}');
    final bg = out.indexOf(r'\begin{center}');
    final narration = out.indexOf(r'\subsection{Narration}');
    expect(bg, greaterThan(label));
    expect(bg, lessThan(narration));
  });

  test('a subsection appears only when it has content', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    // Only s1 has narration; s2's empty description -> no Narration subsection.
    expect(RegExp(r'\\subsection\{Narration\}').allMatches(out).length, 1);
  });

  test('NPCs render as a borderless left-aligned table: a portrait row then '
      'a name row (below it), each cell linked to Chapter 2 — NOT a manual '
      "\\\\ forced inside one cell (that broke a real XeLaTeX compile: nested "
      "inside \\hyperref{...}, it confused the array package's row scanner)", () {
    final assets = present();
    final out = latexScenesChapter(doc(), LatexLabels.english, assets);
    expect(out, contains(r'\noindent'));
    expect(out, contains(r'\begin{tabular}{'));
    expect(out, isNot(contains('|'))); // borderless: no vertical rules
    expect(out, isNot(contains(r'\hline'))); // no horizontal rules either
    expect(out, contains('assets/npcicon_ic1.png'));
    expect(
      out,
      contains(
        r'\hyperref[npc:n1]{\includegraphics[width='
        '6.293706293706294em]{assets/npcicon_ic1.png}}',
      ),
    );
    expect(out, contains(r'\hyperref[npc:n1]{Guard}'));
    // The icon and the name are on DIFFERENT table rows (no bare \\ between
    // them inside one hyperref argument).
    expect(
      out,
      isNot(
        contains(
          r'\includegraphics[width=6.293706293706294em]{assets/npcicon_ic1.png}\\Guard',
        ),
      ),
    );
    expect(
      assets.assets.map((a) => a.archivePath),
      contains('assets/npcicon_ic1.png'),
    );
  });

  test('the NPC table wraps extra NPCs onto a further row once more than fit '
      'the (one-column) column width, padding the short row so columns '
      'stay aligned', () {
    final many = doc();
    many['npcs'] = [
      for (var i = 0; i < 6; i++) {'npc_uuid': 'n$i', 'name': 'Npc $i'},
    ];
    (many['scenes'] as List)[0]['npcs'] = [
      for (var i = 0; i < 6; i++) 'Npc $i',
    ];
    final out = latexScenesChapter(many, LatexLabels.english, present());
    // The one-column body width (42em) fits 5
    // columns; 6 NPCs -> two table rows, the last padded with 4 empty cells.
    final rows = RegExp(r'\\hyperref\[npc:n\d\]').allMatches(out).length;
    expect(rows, 6);
    expect(out, contains(r'\\'));
    // Every row has the same "&" count (the short last row is padded).
    final tableBody = out.substring(
      out.indexOf(r'\begin{tabular}'),
      out.indexOf(r'\end{tabular}'),
    );
    final dataRows = tableBody
        .split('\n')
        .where((l) => l.contains('&'))
        .toList();
    expect(dataRows.length, 2);
    for (final row in dataRows.skip(1)) {
      expect('&'.allMatches(row).length, '&'.allMatches(dataRows[0]).length);
    }
  });

  test('when NONE of the scene NPCs have an icon, no blank portrait row is '
      'emitted at all — just one label row per row-group', () {
    final noIcons = doc();
    noIcons['npcs'] = [
      {'npc_uuid': 'n1', 'name': 'Guard'}, // no icon_image field
    ];
    final out = latexScenesChapter(noIcons, LatexLabels.english, present());
    final tableBody = out.substring(
      out.indexOf(r'\begin{tabular}'),
      out.indexOf(r'\end{tabular}'),
    );
    expect(tableBody, isNot(contains(r'\includegraphics')));
    expect(
      '&'.allMatches(tableBody).length + r'\\'.allMatches(tableBody).length,
      1,
    ); // a single-NPC, single-column row: no '&', one '\\'.
    expect(out, contains(r'\hyperref[npc:n1]{Guard}'));
  });

  test(
    'a scene NPC with a system/stats "kind" gets its localized type in '
    'parentheses after the name; an NPC with no resolvable type has none',
    () {
      final withKind = doc();
      withKind['metadata'] = {'language': 'en', 'system': '7thsea2e'};
      (withKind['npcs'] as List)[0]['stats'] = {'kind': 'villain'};
      final out = latexScenesChapter(withKind, LatexLabels.english, present());
      expect(out, contains('Guard (Villain)'));
    },
  );

  test('visibility conditions render op and resolved event names', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, contains('Visible when (and): Met duke')); // NPC
    expect(out, contains('Visible when (or): Met duke')); // note
  });

  test('next scenes link to targets; a missing target is skipped; '
      'a gated target shows its condition in parentheses', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'\hyperref[scene:s2]{Gate}'));
    expect(out, contains(r'(\textit{Visible when (and): Met duke})'));
    expect(out, isNot(contains('scene:sX')));
  });

  test('data text is LaTeX-escaped', () {
    final out = latexScenesChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'It begins \& continues.')); // narration
    expect(out, contains(r'A \& B')); // note body
  });

  test('missing image files drop the graphic and register no asset', () {
    final assets = AssetSink((_) => false); // nothing exists on disk
    final out = latexScenesChapter(doc(), LatexLabels.english, assets);
    expect(assets.assets, isEmpty);
    expect(out, isNot(contains(r'\includegraphics')));
    expect(out, isNot(contains(r'\begin{center}')));
    // The scene structure is still there (names, links).
    expect(out, contains(r'\hyperref[npc:n1]{Guard}'));
  });
}
