import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_exporter.dart';
import 'package:living_scroll/services/latex/latex_model.dart';

/// Unit coverage for the document assembly + ZIP packaging.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // An adventure whose image `im1` is used by TWO scenes (dedup check), plus a
  // background and an NPC portrait, plus a cover.
  Map<String, dynamic> doc() => {
    'metadata': {
      'name': 'Pack',
      'version': '1.0.0',
      'author': 'Me',
      'system': 'basic',
      'language': 'en',
    },
    'images': [
      {'image_uuid': 'im1', 'name': 'Map'},
    ],
    'npcs': [
      {
        'npc_uuid': 'n1',
        'name': 'Guard',
        'full_image': 'f1',
        'description': 'd',
        'backstory': 'b',
      },
    ],
    'scenes': [
      {
        'scene_uuid': 's1',
        'name': 'A',
        'scene_type': 'start',
        'bg_image': 'bg1',
        'images': ['im1'],
      },
      {
        'scene_uuid': 's2',
        'name': 'B',
        'scene_type': 'standard',
        'images': ['im1'], // same image again
      },
    ],
  };

  test(
    'mainTex has the preamble, both chapters and the document end, in order',
    () {
      final export = buildLatexExport(
        doc(),
        LatexLabels.english,
        assetExists: (_) => true,
      );
      final tex = export.mainTex;
      expect(tex, contains(r'\documentclass[11pt,a4paper,openany]{book}'));
      expect(tex, contains(r'\begin{document}'));
      final scenes = tex.indexOf(r'\chapter{Scenes}');
      final npcs = tex.indexOf(r'\chapter{NPCs}');
      final end = tex.indexOf(r'\end{document}');
      expect(scenes, greaterThan(0));
      expect(scenes, lessThan(npcs));
      expect(npcs, lessThan(end));
    },
  );

  test('the cover is a full-bleed FIRST page — before the title page, before '
      'the table of contents, before every chapter', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final tex = export.mainTex;
    final beginDoc = tex.indexOf(r'\begin{document}');
    final oneColumn = tex.indexOf(r'\onecolumn');
    final cover = tex.indexOf(r'\AddToShipoutPictureBG*');
    final titlePage = tex.indexOf(r'\begin{titlepage}');
    final toc = tex.indexOf(r'\tableofcontents');
    final scenes = tex.indexOf(r'\chapter{Scenes}');
    expect(
      tex,
      contains(
        r'\includegraphics[width=\paperwidth,height=\paperheight]{assets/cover.png}',
      ),
    );
    expect(beginDoc, lessThan(oneColumn));
    expect(oneColumn, lessThan(cover));
    expect(cover, lessThan(titlePage));
    expect(titlePage, lessThan(toc));
    expect(toc, lessThan(scenes));
  });

  test('no cover on disk -> no full-bleed page, but the title page + table '
      'of contents still render', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (src) => src != 'cover.png' && src != 'cover.jpg',
    );
    final tex = export.mainTex;
    expect(tex, isNot(contains(r'\AddToShipoutPictureBG*')));
    expect(tex, contains(r'\begin{titlepage}'));
    expect(tex, contains(r'\tableofcontents'));
  });

  test('the page right after the cover is BLANK — between the cover and the '
      'title page, before any content', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final tex = export.mainTex;
    final cover = tex.indexOf(r'\AddToShipoutPictureBG*');
    final coverClear = tex.indexOf(r'\clearpage', cover);
    // \mbox{} also appears on the cover page itself (to force it to ship) —
    // search AFTER the cover's own \clearpage for the blank page's copy.
    final blank = tex.indexOf(r'\mbox{}', coverClear);
    final titlePage = tex.indexOf(r'\begin{titlepage}');
    expect(blank, greaterThan(coverClear));
    expect(blank, lessThan(titlePage));
    // Genuinely blank: no title/graphics between the cover's \clearpage and
    // the blank page's own \clearpage.
    final blankClear = tex.indexOf(r'\clearpage', blank);
    final between = tex.substring(coverClear, blankClear);
    expect(between, contains(r'\thispagestyle{empty}'));
    expect(between, isNot(contains(r'\includegraphics')));
    expect(between, isNot(contains('Pack'))); // the adventure name
  });

  test('no cover -> no blank spacer page either (nothing to follow)', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (src) => src != 'cover.png' && src != 'cover.jpg',
    );
    // \mbox{} only ever appears on the blank spacer page, which is
    // cover-conditioned — without a cover there is nothing to space out.
    expect(export.mainTex, isNot(contains(r'\mbox{}')));
  });

  test('the table of contents resets pagination to page 2 '
      '(numbering starts on the table-of-contents page, as page 2)', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final tex = export.mainTex;
    expect(tex, contains(r'\setcounter{page}{2}'));
    expect(
      tex.indexOf(r'\setcounter{page}{2}'),
      lessThan(tex.indexOf(r'\tableofcontents')),
    );
  });

  test('the old post-title cover page is gone; the document stays in ONE '
      'column throughout — no \\twocolumn switch anywhere', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final tex = export.mainTex;
    // The cover graphic appears exactly once (the full-bleed page) — no
    // second "cover after the title page" copy.
    expect(RegExp(r'cover\.png').allMatches(tex).length, 1);
    expect(tex, isNot(contains(r'\twocolumn')));
    // \onecolumn is set once, in the front matter, and never switched away
    // from before Chapter 1 (Scenes) starts.
    expect(r'\onecolumn'.allMatches(tex).length, 1);
    final oneColumn = tex.indexOf(r'\onecolumn');
    final scenes = tex.indexOf(r'\chapter{Scenes}');
    expect(oneColumn, lessThan(scenes));
  });

  test('no paths defined -> no Paths chapter at all', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    expect(export.mainTex, isNot(contains(r'\chapter{Paths}')));
  });

  test('no NPCs defined -> no NPCs chapter at all (it used to appear even '
      'with zero NPCs)', () {
    final noNpcs = doc()..['npcs'] = <dynamic>[];
    final export = buildLatexExport(
      noNpcs,
      LatexLabels.english,
      assetExists: (_) => true,
    );
    expect(export.mainTex, isNot(contains(r'\chapter{NPCs}')));
    // The rest of the document is unaffected.
    expect(export.mainTex, contains(r'\chapter{Scenes}'));
    expect(export.mainTex.trimRight(), endsWith(r'\end{document}'));
  });

  test('paths defined -> the Paths chapter is emitted BEFORE Chapter 1 '
      '(Scenes), with a subsection per path', () {
    final withPaths = doc()
      ..['paths'] = [
        {
          'name': 'Red path',
          'color': 'red',
          'description': 'A dangerous road.',
        },
      ];
    final export = buildLatexExport(
      withPaths,
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final tex = export.mainTex;
    final paths = tex.indexOf(r'\chapter{Paths}');
    final scenes = tex.indexOf(r'\chapter{Scenes}');
    expect(paths, greaterThan(0));
    expect(paths, lessThan(scenes));
    expect(
      tex,
      contains(r'\subsection{\pathcircle{pathRed} \hspace{0.4em} Red path}'),
    );
    expect(tex, contains('A dangerous road.'));
  });

  test('assets are deduplicated (an image used twice is packaged once)', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (_) => true,
    );
    final paths = export.assets.map((a) => a.archivePath).toList();
    // cover + background + one image (deduped) + npc portrait.
    expect(
      paths,
      containsAll(<String>[
        'assets/cover.png',
        'assets/bg_bg1.png',
        'assets/img_im1.png',
        'assets/npcfull_f1.png',
      ]),
    );
    expect(paths.where((p) => p == 'assets/img_im1.png').length, 1);
    // The document still references the shared image in BOTH scenes.
    expect(RegExp(r'assets/img_im1\.png').allMatches(export.mainTex).length, 2);
  });

  test(
    'with no files present, no graphics are emitted and assets is empty',
    () {
      final export = buildLatexExport(
        doc(),
        LatexLabels.english,
        assetExists: (_) => false,
      );
      expect(export.assets, isEmpty);
      expect(export.mainTex, isNot(contains(r'\includegraphics')));
      // Text structure survives (title page metadata, chapters).
      expect(export.mainTex, contains('Pack'));
      expect(export.mainTex, contains(r'\chapter{Scenes}'));
    },
  );

  test('cover falls back to the .jpg source when there is no .png', () {
    final export = buildLatexExport(
      doc(),
      LatexLabels.english,
      assetExists: (src) => src == 'cover.jpg',
    );
    final cover = export.assets.singleWhere(
      (a) => a.archivePath.contains('cover'),
    );
    expect(cover.archivePath, 'assets/cover.jpg');
    expect(cover.sourceRelPath, 'cover.jpg');
  });

  test(
    'zipLatexExport produces a decodable zip with main.tex + all assets',
    () {
      final export = buildLatexExport(
        doc(),
        LatexLabels.english,
        assetExists: (_) => true,
      );
      final bytes = zipLatexExport(export, (_) => utf8.encode('PNGDATA'));

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('main.tex'));
      for (final a in export.assets) {
        expect(names, contains(a.archivePath));
      }
      // main.tex round-trips to the generated source.
      final tex = archive.files.firstWhere((f) => f.name == 'main.tex');
      expect(utf8.decode(tex.content as List<int>), export.mainTex);
      // One main.tex + one file per asset.
      expect(archive.files.length, export.assets.length + 1);
    },
  );

  test('the ZIP NEVER contains TeX build artifacts — the export only formats '
      'the .tex; compiling is the external toolchain\'s job', () {
    // Every system uses the same plain book layout, so the ZIP shape never
    // varies: basic and 7thsea2e both produce the identical allowed set.
    for (final system in const ['basic', '7thsea2e']) {
      final d = doc()..['metadata'] = {...doc()['metadata'], 'system': system};
      final export = buildLatexExport(
        d,
        LatexLabels.english,
        assetExists: (_) => true,
      );
      final bytes = zipLatexExport(export, (_) => utf8.encode('PNGDATA'));
      for (final f in ZipDecoder().decodeBytes(bytes).files) {
        expect(
          f.name,
          isNot(matches(RegExp(r'\.(pdf|aux|log|out|toc|synctex(\.gz)?)$'))),
          reason: '[$system] build artifact "${f.name}" leaked into the ZIP',
        );
        // Every entry is main.tex or a used image — never a theme file.
        final allowed = <String>{
          'main.tex',
          ...export.assets.map((a) => a.archivePath),
        };
        expect(
          allowed,
          contains(f.name),
          reason: '[$system] unexpected ZIP entry "${f.name}"',
        );
      }
    }
  });

  test('the preamble and layout are identical for every system — no '
      'per-system branding/vendored files', () {
    for (final system in const ['basic', '7thsea2e', '']) {
      final d = doc()..['metadata'] = {...doc()['metadata'], 'system': system};
      final export = buildLatexExport(
        d,
        LatexLabels.english,
        assetExists: (_) => true,
      );
      expect(
        export.mainTex,
        contains(r'\documentclass[11pt,a4paper,openany]{book}'),
      );
      expect(export.mainTex, contains(r'\onecolumn'));
      expect(export.mainTex, isNot(contains(r'\twocolumn')));
    }
  });
}
