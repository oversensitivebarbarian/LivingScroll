// LaTeX preamble + title page for the Export-to-LaTeX feature. Pure String
// builders, no I/O. Engine: XeLaTeX (fontspec + polyglossia).

import 'package:flutter/painting.dart' show Color;

import '../../l10n/supported_languages.dart';
import '../../paths/path_colors.dart';
import 'latex_text.dart';

/// The document preamble (everything up to, but excluding, `\begin{document}`):
/// `book` / A4 under XeLaTeX, the six path colours from [pathColors], and the
/// `\pathdot` macro. [langCode] is the ADVENTURE's language
/// (`metadata.language`); it selects the `polyglossia` main language.
///
/// The class is loaded WITHOUT a fixed `onecolumn`/`twocolumn` option: column
/// count is instead an explicit `\onecolumn` command in the BODY
/// (`latex_exporter.dart`), so switching the whole document's column count
/// is a one-line edit in `main.tex` rather than a `\documentclass` option.
/// The document renders in ONE column throughout — front matter and body
/// alike (fixed 2026-07-19: no `\twocolumn` switch left).
/// `eso-pic` is loaded here for the full-bleed cover page ([latexCoverPage]).
///
/// `openany` (fixed 2026-07-19): `book`'s DEFAULT is `openright` — every
/// `\chapter` (including the one `\tableofcontents` emits internally) is
/// forced onto the next ODD page, silently inserting a blank, still-numbered
/// page whenever the preceding content didn't already end on an even one. In
/// this document's short front matter that produced confusing extra blank
/// pages (each showing a page number, e.g. a lone "2" or "4") — a real
/// symptom of the reported "inconsistent numbering". `openany` starts a
/// chapter on the very next page instead, odd or even, matching how the
/// scene/NPC generators already manage their own `\clearpage`s.
String latexPreamble({required String langCode}) {
  final buf = StringBuffer();
  buf.writeln(
    r'% Compile with XeLaTeX (Unicode via fontspec). For zh/ja set a CJK main',
  );
  buf.writeln(r'% font, e.g. \setmainfont{Noto Serif CJK SC}.');
  buf.writeln(r'\documentclass[11pt,a4paper,openany]{book}');
  buf.writeln(r'\usepackage{fontspec}');
  buf.write(latexFontFallbackBlock());
  buf.writeln(r'\usepackage{polyglossia}');
  buf.writeln('\\setmainlanguage{${polyglossiaLanguageFor(langCode)}}');
  buf.writeln(r'\usepackage{graphicx}');
  buf.writeln(r'\usepackage{eso-pic}');
  buf.writeln(r'\usepackage{xcolor}');
  buf.writeln(r'\usepackage[normalem]{ulem}');
  buf.writeln(r'\usepackage{fancyhdr}');
  buf.writeln(r'\usepackage{hyperref}');
  buf.write(latexPageNumberingBlock());
  buf.write(latexPathColorBlock());
  return buf.toString();
}

/// Every numbered page shows its number in the FOOTER, at the OUTER margin
/// (bottom-left on even pages, bottom-right on odd pages — `book` is
/// `twoside` by default, so LE/RO is the outer edge) — fixed 2026-07-19: the
/// class's own default (`\pagestyle{headings}`, page number in the HEADER at
/// the outer corner) was inconsistent with `\chapter`'s automatic
/// `\thispagestyle{plain}` on its own opening page (footer, CENTERED) — so
/// numbering visibly jumped between header/footer and centered/outer
/// depending on whether a page happened to open a chapter (Scenes/NPCs/Paths
/// all do). `fancyhdr` (a public, no-extra-file package) redefines BOTH the
/// normal page style AND the `plain` style `\chapter` forces, so every page
/// — chapter-opening or not — renders identically. Headers stay empty (no
/// running heads); only the footer page number is set. Pages that must stay
/// UNNUMBERED (cover/blank/title page, §2) already override this with their
/// own `\thispagestyle{empty}`, which is unaffected by redefining `plain`.
String latexPageNumberingBlock() {
  final buf = StringBuffer();
  buf.writeln(r'\fancyhf{}');
  buf.writeln(r'\renewcommand{\headrulewidth}{0pt}');
  buf.writeln(r'\fancyfoot[LE,RO]{\thepage}');
  buf.writeln(r'\pagestyle{fancy}');
  buf.writeln(r'\fancypagestyle{plain}{%');
  buf.writeln(r'  \fancyhf{}%');
  buf.writeln(r'  \renewcommand{\headrulewidth}{0pt}%');
  buf.writeln(r'  \fancyfoot[LE,RO]{\thepage}%');
  buf.writeln(r'}');
  return buf.toString();
}

/// Selects a main font that actually EXISTS on the compiling machine, instead
/// of relying on fontspec's implicit default. With no `\setmainfont` at all,
/// `fontspec` silently falls back to the **Latin Modern OpenType** fonts
/// (`lmroman*`) — a separate OTF collection (TeX Live's `lm`/`tex-gyre`
/// packages) that is NOT guaranteed to be installed even on a working XeLaTeX
/// setup (e.g. a minimal `texlive-latex-base`-only install has the classic
/// Type1 Computer Modern for pdfLaTeX, but not these OTF faces) — compiling
/// then fails with "Font ... not loadable: Metric (TFM) file or installed
/// font not found" (a real, reported case: 2026-07-19). `\IfFontExistsTF`
/// (a public `fontspec` command, no extra package) tries a cascade of common
/// OTF-capable fonts and uses the first one actually present, never vendoring
/// any font file — the app ships no fonts, matching the unbranded/unvendored
/// export. If NONE of these resolve, `fontspec`'s
/// own default is left in place as the final fallback (an exotic TeX install
/// missing all of them was already failing before this fix; this only adds
/// paths that succeed on a normal one).
String latexFontFallbackBlock() {
  const candidates = [
    'Latin Modern Roman',
    'TeX Gyre Termes',
    'Noto Serif',
    'DejaVu Serif',
    'Liberation Serif',
  ];
  final buf = StringBuffer();
  var depth = 0;
  for (final font in candidates) {
    buf.writeln('\\IfFontExistsTF{$font}{\\setmainfont{$font}}{%');
    depth++;
  }
  buf.write('}' * depth);
  buf.writeln();
  return buf.toString();
}

/// The six path colours (`\definecolor{path<Colour>}`), the `\pathdot` macro
/// the scene generator emits, and the `\pathcircle` macro the Paths chapter
/// emits — shared by every theme's preamble so both calls always resolve.
/// Single source of truth is [pathColors]; never
/// hard-coded here. Requires `xcolor` + `graphicx` + `hyperref` to be loaded.
///
/// `\pathdot` is a coloured bullet, NOT a tikz picture: it is emitted INSIDE a
/// `\section{...}` heading, and tikz makes `;`/`:` active — fragile in that moving
/// argument (it breaks under XeLaTeX). `\texorpdfstring` keeps it out of PDF
/// bookmarks.
///
/// `\pathcircle` is the BIGGER, row-height circle the Paths chapter (§3) puts
/// inside a path's `\subsection{...}` heading — `\resizebox` (from `graphicx`,
/// already loaded everywhere) scales the same bullet glyph to `1em` (matching
/// the current line's text height) instead of the small heading-sized dot;
/// `\raisebox` re-centres it on the baseline (a scaled math symbol otherwise
/// floats up, since its own depth scales to ~0 too). Like `\pathdot`, it is
/// used INSIDE a sectioning-command title (a moving argument feeding the PDF
/// bookmark outline via hyperref), so it needs the SAME `\texorpdfstring`
/// guard — hyperref's outline generation cannot safely tokenize a raw math
/// mode / colour / resizebox sequence into a PDF string.
String latexPathColorBlock() {
  final buf = StringBuffer();
  for (final p in pathColors) {
    buf.writeln(
      '\\definecolor{${latexColorNameForPathId(p.id)}}'
      '{HTML}{${latexHexFor(p.color)}}',
    );
  }
  buf.writeln(
    r'\newcommand{\pathdot}[1]{\texorpdfstring{{\color{#1}$\bullet$}}{}}',
  );
  buf.writeln(r'\newcommand{\pathcircle}[1]{\texorpdfstring{%');
  buf.writeln(
    r'  \raisebox{-0.15em}{\textcolor{#1}{\resizebox{!}{1em}{$\bullet$}}}}{}}',
  );
  return buf.toString();
}

/// Normalizes a stored `metadata.language` value to one of the app's
/// supported LOWERCASE ISO codes (en/de/fr/pt/es/pl/zh/ja) — accepting an
/// exact ISO code in ANY case, an endonym (e.g. "Polski"), or a legacy
/// English exonym (e.g. "Polish"), via [SupportedLanguages.codeFor] (the SAME
/// normalization the Language dropdown itself applies). Falls back to a
/// simple trimmed/lower-cased form when nothing matches, so an unrecognized
/// code still reaches [polyglossiaLanguageFor] /
/// `LatexLabels.forLanguage` in a canonical shape instead of silently
/// mismatching on stray case (this fixes a real bug: a `metadata.language`
/// stored as `"PL"` made the preamble correctly say `\setmainlanguage{polish}`
/// — [polyglossiaLanguageFor] already lower-cased — while `LatexLabels`
/// fields (e.g. the Paths chapter's "page" word) silently fell back to
/// English, since its locale lookup compared case-sensitively).
String normalizeLanguageCode(String langCode) =>
    SupportedLanguages.codeFor(langCode) ?? langCode.trim().toLowerCase();

/// Maps an adventure language ISO code (`metadata.language`) to a `polyglossia`
/// main-language name. `zh`/`ja` have no polyglossia coverage, so they fall back
/// to `english` (hyphenation is irrelevant for CJK; XeLaTeX+fontspec still renders
/// the glyphs). An empty / unrecognized code also falls back to `english`.
String polyglossiaLanguageFor(String langCode) =>
    _polyglossia[normalizeLanguageCode(langCode)] ?? 'english';

const Map<String, String> _polyglossia = {
  'en': 'english',
  'de': 'german',
  'fr': 'french',
  'es': 'spanish',
  'pt': 'portuguese',
  'pl': 'polish',
};

/// The LaTeX colour name defined in the preamble for a path colour id
/// (`yellow` -> `pathYellow`), so `path_names[]` can resolve to `\pathdot{...}`.
String latexColorNameForPathId(String colorId) {
  if (colorId.isEmpty) return 'path';
  return 'path${colorId[0].toUpperCase()}${colorId.substring(1)}';
}

/// A [Color] as a 6-digit upper-case RGB hex (no alpha) for `\definecolor{..}{HTML}{..}`.
String latexHexFor(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

/// The optional title page: the adventure name, then
/// the version / author — TEXT ONLY (the cover is its own full-bleed FIRST
/// page, [latexCoverPage], rendered before this). Rendered inside a
/// single-column `titlepage`. Any empty field is omitted. Returns an empty
/// string when there is nothing to show. `metadata.system` is NEVER shown —
/// it is an internal identifier (e.g. `7thsea2e`), not adventure content.
String latexTitlePage({
  required String name,
  String version = '',
  String author = '',
}) {
  if (name.isEmpty && version.isEmpty && author.isEmpty) {
    return '';
  }
  final buf = StringBuffer();
  buf.writeln(r'\begin{titlepage}');
  buf.writeln(r'\centering');
  if (name.isNotEmpty) {
    buf.writeln('{\\Huge\\bfseries ${latexEscape(name)}}\\par');
  }
  if (version.isNotEmpty) {
    buf.writeln('\\vspace{0.5em}{\\large ${latexEscape(version)}}\\par');
  }
  if (author.isNotEmpty) {
    buf.writeln('\\vspace{0.5em}{\\large ${latexEscape(author)}}\\par');
  }
  buf.writeln(r'\end{titlepage}');
  return buf.toString();
}

/// The full-bleed COVER PAGE: the FIRST page of the
/// document when the adventure has a cover — the image fills the whole
/// physical page edge-to-edge, ignoring margins, via `eso-pic`'s ONE-SHOT
/// `\AddToShipoutPictureBG*`. Requires `eso-pic` (loaded by
/// [latexPreamble]). [coverAsset] is the packaged path
/// (`assets/cover.png`) or null/empty; returns an empty string then (no page
/// emitted, no `\clearpage` consumed).
String latexCoverPage(String? coverAsset) {
  if (coverAsset == null || coverAsset.isEmpty) return '';
  final buf = StringBuffer();
  buf.writeln(r'\AddToShipoutPictureBG*{%');
  buf.writeln(
    '  \\put(0,0){\\includegraphics[width=\\paperwidth,height=\\paperheight]{$coverAsset}}%',
  );
  buf.writeln(r'}');
  buf.writeln(r'\thispagestyle{empty}');
  buf.writeln(r'\mbox{}');
  buf.writeln(r'\clearpage');
  return buf.toString();
}

/// A single BLANK page — no content, no header/footer, no page number
/// (`\thispagestyle{empty}`). Emitted right after the full-bleed cover page,
/// so the cover's very next page is intentionally
/// empty rather than jumping straight into the title page.
String latexBlankPage() {
  final buf = StringBuffer();
  buf.writeln(r'\thispagestyle{empty}');
  buf.writeln(r'\mbox{}');
  buf.writeln(r'\clearpage');
  return buf.toString();
}

/// The automatic table-of-contents page: replaces
/// the old post-title-page cover — a plain `\tableofcontents`, generated by
/// LaTeX itself from every `\chapter`/`\section` the document emits (a second
/// compile pass resolves it, like every other cross-reference in this
/// document). Every page before it (cover / blank / title page) stays
/// `\thispagestyle{empty}` (unnumbered), so `\setcounter{page}{2}` here makes
/// this the FIRST page to show a number — displayed as page 2, not 1 (a
/// deliberate document-wide numbering choice, independent of how many hidden
/// front-matter pages preceded it).
String latexTableOfContentsPage() {
  final buf = StringBuffer();
  buf.writeln(r'\setcounter{page}{2}');
  buf.writeln(r'\tableofcontents');
  buf.writeln(r'\clearpage');
  return buf.toString();
}
