// Document assembly + ZIP packaging for the Export-to-LaTeX feature.
// [buildLatexExport] is pure
// (decoded doc -> main.tex + asset list); [zipLatexExport] turns that into
// archive bytes. The document uses ONE plain, unbranded `book` layout for
// every game system — no vendored classes/fonts/art, only standard LaTeX
// packages any TeX Live/MiKTeX install ships (see [latexPreamble]).

import 'dart:convert';

import 'package:archive/archive.dart';

import 'latex_model.dart';
import 'latex_npcs.dart';
import 'latex_paths.dart';
import 'latex_preamble.dart';
import 'latex_scenes.dart';

/// The generated document: the full `main.tex` and the adventure images it
/// references (already deduplicated, in first-seen order).
class LatexExport {
  const LatexExport(this.mainTex, this.assets);

  final String mainTex;
  final List<LatexAsset> assets;
}

/// Builds the whole document from a decoded adventure [doc]: the shared
/// preamble (with the language from `metadata.language`), the front matter —
/// a full-bleed COVER PAGE (the document's FIRST page, when there is a cover)
/// followed by a single BLANK page (no numbering, no header/footer), the
/// TEXT-ONLY title page, and an automatic `\tableofcontents` page (which
/// resets the page counter so IT is the first page to show a number, as
/// page 2) — then the Paths chapter (only when the adventure defines any
/// paths — a `\subsection` per path, name + description), Chapter 1 (scenes)
/// and Chapter 2 (NPCs, only when the adventure defines any NPCs — same
/// optionality as the Paths chapter). The WHOLE document renders in ONE
/// column (`\onecolumn`), front matter AND body
/// alike — the SAME layout for every `metadata.system`; the look never
/// varies by game system. [assetExists] reports whether a source image file
/// is present, so
/// `\includegraphics` and the [LatexExport.assets] list only ever include
/// images that can actually be packaged. Pure:
/// [doc] is not mutated.
LatexExport buildLatexExport(
  Map doc,
  LatexLabels labels, {
  required bool Function(String sourceRelPath) assetExists,
}) {
  final metadata = doc['metadata'];
  String meta(String key) => (metadata is Map && metadata[key] is String)
      ? metadata[key] as String
      : '';

  final assets = AssetSink(assetExists);

  // Cover asset for the title page — keep the real extension (cover.png/.jpg).
  String? coverAsset;
  for (final ext in const ['png', 'jpg']) {
    if (assets.add('assets/cover.$ext', 'cover.$ext')) {
      coverAsset = 'assets/cover.$ext';
      break;
    }
  }

  final buf = StringBuffer();
  buf.write(latexPreamble(langCode: meta('language')));
  buf.writeln(r'\begin{document}');
  buf.writeln();

  // Front matter — ALWAYS one column: the full-bleed cover (the document's
  // FIRST page, when there is a cover) followed by a single BLANK page (no
  // numbering, no header/footer), the text-only title page, then an automatic
  // table of contents (replacing the old post-title cover page) — which
  // resets the page counter so IT is the first page to show a number, as
  // page 2.
  buf.writeln(r'\onecolumn');
  final coverPage = latexCoverPage(coverAsset);
  if (coverPage.isNotEmpty) {
    buf.write(coverPage);
    buf.writeln();
    buf.write(latexBlankPage());
    buf.writeln();
  }

  final title = latexTitlePage(
    name: meta('name'),
    version: meta('version'),
    author: meta('author'),
  );
  if (title.isNotEmpty) {
    buf.writeln(title);
    buf.writeln();
  }

  buf.write(latexTableOfContentsPage());
  buf.writeln();

  // The body stays in the SAME one column the front matter already set —
  // no column switch, for every system.
  final pathsChapter = latexPathsChapter(doc, labels);
  if (pathsChapter.isNotEmpty) {
    buf.write(pathsChapter);
    buf.writeln();
  }

  buf.write(latexScenesChapter(doc, labels, assets));
  buf.writeln();

  final npcsChapter = latexNpcsChapter(doc, labels, assets);
  if (npcsChapter.isNotEmpty) {
    buf.write(npcsChapter);
    buf.writeln();
  }
  buf.writeln(r'\end{document}');

  return LatexExport(buf.toString(), assets.assets);
}

/// Packages a [LatexExport] as ZIP bytes: `main.tex` at the archive root, plus
/// each adventure image under its `archivePath` (bytes via [readAsset] from
/// the source path). `main.tex` is DEFLATEd; images (already-compressed
/// PNG/JPEG) are STOREd, matching AdventurePackager.
List<int> zipLatexExport(
  LatexExport export,
  List<int> Function(String sourceRelPath) readAsset,
) {
  final archive = Archive();

  final texBytes = utf8.encode(export.mainTex);
  archive.addFile(
    ArchiveFile('main.tex', texBytes.length, texBytes)..compress = true,
  );

  for (final asset in export.assets) {
    final bytes = readAsset(asset.sourceRelPath);
    archive.addFile(
      ArchiveFile(asset.archivePath, bytes.length, bytes)..compress = false,
    );
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Failed to encode the LaTeX export archive.');
  }
  return encoded;
}
