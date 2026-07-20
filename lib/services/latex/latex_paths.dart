// Chapter "Paths" of the LaTeX export. A pure
// generator: decoded doc + labels -> LaTeX. Placed BEFORE Chapter 1 (Scenes) —
// shared by every theme/system, like the scene/NPC generators.

import '../../paths/path_colors.dart';
import 'latex_model.dart';
import 'latex_preamble.dart';
import 'latex_text.dart';

/// Renders the Paths chapter — one `\subsection` per entry in `doc['paths']`
/// (the roster order): `\subsection{\pathcircle{colourName} \hspace{0.4em}
/// name}` — a ROW-HEIGHT coloured circle (its `paths[].color`, when it
/// resolves to one of the six path colours), a fixed gap, then the
/// path's name, all IN THE HEADING ITSELF (an unresolvable/empty colour drops
/// the circle and gap, leaving a plain `\subsection{name}`). The
/// `description` follows as an ordinary body paragraph. Then — when any scene
/// references this path by name (`scenes[].path_names[]`) — an `itemize`
/// listing those scenes IN ROSTER ORDER (`doc['scenes']` order), each a link
/// to its Chapter-1 section plus its page number in parentheses, PREFIXED
/// with the adventure-language word for "page" (`\pageref`, resolved from
/// that scene's own `\label{scene:<uuid>}`). Emits
/// NOTHING (empty string) when the adventure defines no paths, so callers can
/// `buf.write` it unconditionally and it simply disappears. A path without a
/// name is skipped (a subsection needs a title); this can't happen for a path
/// actually used by a scene, since `path_names[]` references paths BY NAME.
String latexPathsChapter(Map doc, LatexLabels labels) {
  final list = _list(doc['paths']);
  if (list.isEmpty) return '';

  final scenes = _list(doc['scenes']);
  final validColorIds = {for (final p in pathColors) p.id};
  final buf = StringBuffer();
  buf.writeln('\\chapter{${latexEscape(labels.paths)}}');
  buf.writeln();
  for (final p in list) {
    if (p is! Map) continue;
    final name = _str(p['name']);
    if (name.isEmpty) continue;
    final colorId = _str(p['color']);
    final hasCircle = validColorIds.contains(colorId);
    final circle = hasCircle
        ? '\\pathcircle{${latexColorNameForPathId(colorId)}} \\hspace{0.4em} '
        : '';
    buf.writeln('\\subsection{$circle${latexEscape(name)}}');
    final desc = _str(p['description']);
    if (desc.trim().isNotEmpty) {
      buf.writeln(latexParagraphs(latexEscape(desc)));
    }
    buf.writeln();

    final items = <String>[];
    for (final s in scenes) {
      if (s is! Map) continue;
      final onThisPath = _list(
        s['path_names'],
      ).whereType<String>().contains(name);
      if (!onThisPath) continue;
      final uuid = _str(s['scene_uuid']);
      final sceneName = _str(s['name']);
      if (uuid.isEmpty || sceneName.isEmpty) continue;
      final pageRef = labels.pageReference('\\pageref{scene:$uuid}');
      items.add(
        '  \\item \\hyperref[scene:$uuid]{${latexEscape(sceneName)}} '
        '($pageRef)',
      );
    }
    if (items.isNotEmpty) {
      buf.writeln('\\begin{itemize}');
      for (final it in items) {
        buf.writeln(it);
      }
      buf.writeln('\\end{itemize}');
      buf.writeln();
    }
  }
  return buf.toString();
}

List<dynamic> _list(dynamic v) => v is List ? v : const [];

String _str(dynamic v) => v is String ? v : '';
