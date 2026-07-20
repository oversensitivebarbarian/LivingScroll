// LaTeX text utilities for the Export-to-LaTeX feature. Pure String -> String
// helpers, no I/O:
//   * [latexEscape]       — escape LaTeX specials in a raw data string,
//   * [latexParagraphs]   — turn newlines of an ALREADY-escaped field into
//                           LaTeX paragraphs / line breaks,
//   * [latexFromNoteContent] — render a note's Quill Delta to LaTeX with its
//                           inline formatting preserved (bold/italic/underline/
//                           strike/code/link) and bullet/ordered lists.

import '../../notes/note_content.dart';

/// LaTeX-escapes a raw data string (name / description / note run) so it is safe
/// to typeset verbatim. Iterates code points, so
/// multi-byte (CJK) text passes through unchanged for XeLaTeX. Backslash is
/// handled inline (not by a later pass), so inserted escape sequences are never
/// re-escaped.
String latexEscape(String input) {
  if (input.isEmpty) return '';
  final buf = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      case 0x5C: // \
        buf.write(r'\textbackslash{}');
      case 0x26: // &
        buf.write(r'\&');
      case 0x25: // %
        buf.write(r'\%');
      case 0x24: // $
        buf.write(r'\$');
      case 0x23: // #
        buf.write(r'\#');
      case 0x5F: // _
        buf.write(r'\_');
      case 0x7B: // {
        buf.write(r'\{');
      case 0x7D: // }
        buf.write(r'\}');
      case 0x7E: // ~
        buf.write(r'\textasciitilde{}');
      case 0x5E: // ^
        buf.write(r'\textasciicircum{}');
      default:
        buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

/// Turns the newlines of an ALREADY-escaped plain field (`description` /
/// `backstory`) into LaTeX: a blank line (two-or-more newlines) becomes a
/// paragraph break, a single newline becomes a forced line break (`\\`). Empty
/// paragraphs are dropped. Input MUST be pre-escaped ([latexEscape]).
String latexParagraphs(String escapedText) {
  if (escapedText.isEmpty) return '';
  final normalized = escapedText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final paragraphs = <String>[];
  for (final para in normalized.split(RegExp(r'\n{2,}'))) {
    final lines = [
      for (final l in para.split('\n'))
        if (l.trim().isNotEmpty) l.trimRight(),
    ];
    if (lines.isEmpty) continue;
    paragraphs.add(lines.join('\\\\\n'));
  }
  return paragraphs.join('\n\n');
}

/// Renders a stored `note_content` (a Quill Delta)
/// to LaTeX WITH its formatting preserved: inline bold/italic/underline/
/// strike/code/link, plus bullet /
/// ordered lists. An empty note renders an empty string.
///
/// Design (v1): each Quill line becomes its own LaTeX paragraph (blocks joined by
/// a blank line); consecutive list lines collapse into one `itemize`/`enumerate`;
/// a header line renders as a bold paragraph (note content, not a document
/// section). Embedded images in a note are DROPPED in v1 (a documented
/// simplification; text formatting is always kept).
String latexFromNoteContent(String stored) {
  final ops = documentFromStored(stored).toDelta().toList();

  // Split the delta into lines. A Quill line is terminated by a '\n'; block
  // attributes (list/header) ride on that newline's op.
  final lines = <_Line>[];
  var current = <_Seg>[];
  for (final op in ops) {
    if (!op.isInsert) continue;
    final data = op.data;
    if (data is String) {
      final pieces = data.split('\n');
      for (var i = 0; i < pieces.length; i++) {
        if (pieces[i].isNotEmpty) current.add(_Seg(pieces[i], op.attributes));
        // A '\n' followed this piece (every piece but the last) -> close a line.
        if (i < pieces.length - 1) {
          lines.add(_Line(current, op.attributes));
          current = <_Seg>[];
        }
      }
    }
    // A Map `data` is an embed (image, …) -> dropped in v1.
  }
  if (current.isNotEmpty) lines.add(_Line(current, null));

  return _renderLines(lines);
}

String _renderLines(List<_Line> lines) {
  final blocks = <String>[];
  var i = 0;
  while (i < lines.length) {
    final list = _listType(lines[i].block);
    if (list != null) {
      final env = list == 'ordered' ? 'enumerate' : 'itemize';
      final items = <String>[];
      while (i < lines.length && _listType(lines[i].block) == list) {
        items.add('  \\item ${_renderInline(lines[i].segs)}');
        i++;
      }
      blocks.add('\\begin{$env}\n${items.join('\n')}\n\\end{$env}');
      continue;
    }
    final content = _renderInline(lines[i].segs);
    i++;
    if (content.trim().isEmpty) continue; // blank line -> just a separator
    blocks.add(_isHeader(lines[i - 1].block) ? '\\textbf{$content}' : content);
  }
  return blocks.join('\n\n');
}

String _renderInline(List<_Seg> segs) {
  final buf = StringBuffer();
  for (final s in segs) {
    buf.write(_renderSeg(s));
  }
  return buf.toString();
}

/// One styled text run -> escaped text wrapped by its inline attributes. Wrapping
/// order is fixed (innermost first): code, strike, underline, italic, bold, then
/// link outermost — so output is deterministic.
String _renderSeg(_Seg s) {
  var t = latexEscape(s.text);
  final a = s.attrs;
  if (a == null || a.isEmpty) return t;
  if (a['code'] == true) t = '\\texttt{$t}';
  if (a['strike'] == true) t = '\\sout{$t}';
  if (a['underline'] == true) t = '\\underline{$t}';
  if (a['italic'] == true) t = '\\textit{$t}';
  if (a['bold'] == true) t = '\\textbf{$t}';
  final link = a['link'];
  if (link is String && link.isNotEmpty) t = '\\href{${_escapeUrl(link)}}{$t}';
  return t;
}

/// Minimal escaping for a URL inside `\href{...}`: only the characters LaTeX
/// would otherwise misread (`%` comment, `#` parameter, `&` alignment).
String _escapeUrl(String url) =>
    url.replaceAll('%', r'\%').replaceAll('#', r'\#').replaceAll('&', r'\&');

/// The Quill list kind on a block newline (`bullet`/`ordered`/…), or null.
String? _listType(Map<String, dynamic>? block) {
  final v = block?['list'];
  return v is String ? v : null;
}

bool _isHeader(Map<String, dynamic>? block) => block?['header'] != null;

/// One inline text run with its Quill attributes (bold/italic/link/…).
class _Seg {
  _Seg(this.text, this.attrs);
  final String text;
  final Map<String, dynamic>? attrs;
}

/// One Quill line: its inline segments plus the block attributes carried by the
/// terminating newline (list/header).
class _Line {
  _Line(this.segs, this.block);
  final List<_Seg> segs;
  final Map<String, dynamic>? block;
}
