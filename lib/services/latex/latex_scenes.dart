// Chapter 1 (Scenes) of the LaTeX export. A pure generator: decoded doc +
// labels + asset sink -> LaTeX.

import '../../paths/path_colors.dart';
import 'latex_model.dart';
import 'latex_preamble.dart';
import 'latex_text.dart';

/// Renders Chapter 1 — the scenes in `doc['scenes']` order (the roster). Each
/// scene STARTS ON A NEW PAGE (`\clearpage` between scenes; the first follows
/// the chapter heading on its fresh page). Each
/// scene is a `\section` (name + type + path-colour dots), its background, then
/// Narration / NPCs / Notes / Images subsections (only when non-empty), and a
/// linked Next-scenes list. Image references are registered on [assets] and only
/// emitted when the source file exists.
String latexScenesChapter(Map doc, LatexLabels labels, AssetSink assets) {
  final npcsByName = _byKey(doc['npcs'], 'name');
  final notesByUuid = _byKey(doc['notes'], 'note_uuid');
  final imagesByUuid = _byKey(doc['images'], 'image_uuid');
  final scenesByUuid = _byKey(doc['scenes'], 'scene_uuid');
  final keByUuid = _byKey(doc['key_events'], 'key_event_uuid');
  final pathsByName = _byKey(doc['paths'], 'name');
  final validColorIds = {for (final p in pathColors) p.id};
  final metadata = doc['metadata'];
  final system = (metadata is Map && metadata['system'] is String)
      ? metadata['system'] as String
      : '';

  final buf = StringBuffer();
  buf.writeln('\\chapter{${latexEscape(labels.scenes)}}');
  buf.writeln();
  // Every scene starts on a NEW PAGE: the chapter
  // heading already opens a fresh page for the first scene; each further
  // scene gets a \clearpage (which also flushes pending floats).
  var first = true;
  for (final s in _list(doc['scenes'])) {
    if (s is! Map) continue;
    if (!first) {
      buf.writeln(r'\clearpage');
      buf.writeln();
    }
    first = false;
    _writeScene(
      buf,
      s,
      labels,
      assets,
      npcsByName,
      notesByUuid,
      imagesByUuid,
      scenesByUuid,
      keByUuid,
      pathsByName,
      validColorIds,
      system,
    );
  }
  return buf.toString();
}

void _writeScene(
  StringBuffer buf,
  Map s,
  LatexLabels labels,
  AssetSink assets,
  Map<String, Map> npcsByName,
  Map<String, Map> notesByUuid,
  Map<String, Map> imagesByUuid,
  Map<String, Map> scenesByUuid,
  Map<String, Map> keByUuid,
  Map<String, Map> pathsByName,
  Set<String> validColorIds,
  String system,
) {
  // --- Section title: name (type) + one dot per path colour the scene sits on.
  final dots = <String>[];
  for (final pn in _list(s['path_names'])) {
    final path = pn is String ? pathsByName[pn] : null;
    final colorId = path == null ? '' : _str(path['color']);
    if (validColorIds.contains(colorId)) {
      dots.add('\\pathdot{${latexColorNameForPathId(colorId)}}');
    }
  }
  final type = labels.sceneType(_str(s['scene_type']));
  // The short (optional) title feeds \sectionmark / running heads / TOC — it
  // must stay free of \pathdot's \color{...} argument: some classes' default
  // \sectionmark (e.g. article, used by the 7thsea2e theme) runs its argument
  // through \MakeUppercase before storing it, which uppercases the colour NAME
  // too ("pathGreen" -> "PATHGREEN"), an undefined xcolor colour. The dots are
  // decorative and irrelevant in a running head, so they're kept OUT of the
  // short title entirely (braced, so a stray "]" in the name can't terminate
  // the optional argument early).
  final shortTitle = '${latexEscape(_str(s['name']))} (${latexEscape(type)})';
  final title = '$shortTitle${dots.isEmpty ? '' : ' ${dots.join(' ')}'}';
  buf.writeln('\\section[{$shortTitle}]{$title}');
  buf.writeln('\\label{scene:${_str(s['scene_uuid'])}}');
  buf.writeln();

  // --- Background (full-width), IMMEDIATELY after the title —
  // a plain, NON-floating `center`
  // block, not `figure`/`figure*`: a floating environment can drift away
  // from its declared position to wherever LaTeX's placement algorithm next
  // allows it (a real reported bug when the body was two columns — the
  // image ended up rendering well after the scene's own text instead of
  // right after the title); `center` always renders exactly where it
  // appears in the source.
  final bg = _str(s['bg_image']);
  if (bg.isNotEmpty &&
      assets.add('assets/bg_$bg.png', 'images/bg_images/$bg.png')) {
    buf.writeln('\\begin{center}');
    buf.writeln('\\includegraphics[width=\\textwidth]{assets/bg_$bg.png}');
    buf.writeln('\\end{center}');
    buf.writeln();
  }

  // --- Narration.
  final desc = _str(s['description']);
  if (desc.trim().isNotEmpty) {
    buf.writeln('\\subsection{${latexEscape(labels.narration)}}');
    buf.writeln(latexParagraphs(latexEscape(desc)));
    buf.writeln();
  }

  // --- NPCs: a borderless, left-aligned table of portrait tiles (icon, then
  // name + localized type on a new line), linked to Chapter 2. Each row holds
  // as many NPCs as fit the column width (§4a); extras wrap to further rows.
  final npcEntries = [
    for (final ref in _list(s['npcs'])) ?npcsByName[_refString(ref)],
  ];
  if (npcEntries.isNotEmpty) {
    buf.writeln('\\subsection{${latexEscape(labels.npcsInScene)}}');
    _writeNpcTable(buf, npcEntries, labels, assets, system);
    for (final npc in npcEntries) {
      final text = _visibilityText(npc['visibility_rules'], keByUuid, labels);
      if (text != null) {
        buf.writeln('\\textit{${latexEscape(_str(npc['name']))}: $text}\\par');
      }
    }
    buf.writeln();
  }

  // --- Notes (name + formatted body).
  final noteEntries = [
    for (final ref in _list(s['notes'])) ?notesByUuid[_refString(ref)],
  ];
  if (noteEntries.isNotEmpty) {
    buf.writeln('\\subsection{${latexEscape(labels.notes)}}');
    for (final note in noteEntries) {
      buf.writeln('\\textbf{${latexEscape(_str(note['note_name']))}}\\par');
      final body = latexFromNoteContent(_str(note['note_content']));
      if (body.isNotEmpty) buf.writeln(body);
      _writeVisibility(buf, note['visibility_rules'], keByUuid, labels);
      buf.writeln();
    }
  }

  // --- Images (in-column graphic + name).
  final imageEntries = [
    for (final ref in _list(s['images'])) ?imagesByUuid[_refString(ref)],
  ];
  if (imageEntries.isNotEmpty) {
    buf.writeln('\\subsection{${latexEscape(labels.images)}}');
    for (final img in imageEntries) {
      final uuid = _str(img['image_uuid']);
      if (assets.add('assets/img_$uuid.png', 'images/other/$uuid.png')) {
        buf.writeln(
          '\\includegraphics[width=0.6\\linewidth]{assets/img_$uuid.png}\\par',
        );
      }
      final name = _str(img['name']);
      if (name.isNotEmpty) buf.writeln('${latexEscape(name)}\\par');
      _writeVisibility(buf, img['visibility_rules'], keByUuid, labels);
    }
    buf.writeln();
  }

  // --- Next scenes (linked; target's visibility condition in parentheses).
  final items = <String>[];
  for (final ref in _list(s['next_scenes'])) {
    final uuid = _refString(ref);
    final target = scenesByUuid[uuid];
    if (target == null) continue;
    var item = '\\hyperref[scene:$uuid]{${latexEscape(_str(target['name']))}}';
    final vis = _visibilityText(target['visibility_rules'], keByUuid, labels);
    if (vis != null) item += ' (\\textit{$vis})';
    items.add('  \\item $item');
  }
  if (items.isNotEmpty) {
    buf.writeln('\\subsection*{${latexEscape(labels.nextScenes)}}');
    buf.writeln('\\begin{itemize}');
    for (final it in items) {
      buf.writeln(it);
    }
    buf.writeln('\\end{itemize}');
    buf.writeln();
  }
}

/// Portrait width for the scene NPC table, in `em` (scales with the
/// theme's font size, unlike a fixed physical unit) — kept at the same 9em
/// height the icon previously rendered at (1:1.43 icon-image aspect ratio),
/// expressed here as a width so the column count
/// is a plain division.
const double _npcCellWidthEm = 9 / 1.43;

/// Extra allowance (padding either side of the portrait) counted per column
/// when deciding how many NPCs fit one row.
const double _npcColumnGapEm = 1.0;

/// Assumed usable text width (`em`) for the document's one-column body
/// (every export renders in a single column).
const double _npcTableAvailableWidthEm = 42.0;

/// How many NPC portraits fit across the scene NPC table's column width before
/// wrapping to a further table row — always at
/// least one, so a single oversized entry still renders.
int _npcColumnsPerRow() {
  final n = (_npcTableAvailableWidthEm / (_npcCellWidthEm + _npcColumnGapEm))
      .floor();
  return n < 1 ? 1 : n;
}

/// Renders the scene's NPCs as a borderless (`tabular`, no rules), left-aligned
/// table: a portrait row (only emitted when at least one NPC has an icon
/// asset) then a name row — the NPC's name, and its localized "type" in
/// parentheses when the system/stats resolve one ([LatexLabels.npcType]) —
/// each cell linking to Chapter 2. A row of `\\` (LaTeX's own row separator)
/// is what actually terminates a "line" here: a manual `\\` INSIDE one cell
/// (to break icon from name within a single cell) is NOT used — nested inside
/// `\hyperref{...}`, it broke the array package's row-scanning (a real XeLaTeX
/// compile caught this; two genuine table rows per NPC-row-group sidesteps it
/// entirely). [_npcColumnsPerRow] cells per row-group; a short final group is
/// padded with empty cells so columns stay aligned.
void _writeNpcTable(
  StringBuffer buf,
  List<Map> npcEntries,
  LatexLabels labels,
  AssetSink assets,
  String system,
) {
  final maxCols = _npcColumnsPerRow();
  // Never provision more columns than there are NPCs — a small scene's table
  // isn't padded with empty columns; the max only kicks in once exceeded.
  final cols = npcEntries.length < maxCols ? npcEntries.length : maxCols;
  final iconCells = <String>[];
  final labelCells = <String>[];
  for (final npc in npcEntries) {
    final uuid = _str(npc['npc_uuid']);
    final name = latexEscape(_str(npc['name']));
    final type = labels.npcType(system, npc['stats']);
    final label = type == null ? name : '$name (${latexEscape(type)})';
    labelCells.add('\\hyperref[npc:$uuid]{$label}');

    final icon = _str(npc['icon_image']);
    if (icon.isNotEmpty &&
        assets.add('assets/npcicon_$icon.png', 'images/npcs/$icon.png')) {
      iconCells.add(
        '\\hyperref[npc:$uuid]{'
        '\\includegraphics[width=${_npcCellWidthEm}em]{assets/npcicon_$icon.png}}',
      );
    } else {
      iconCells.add('');
    }
  }
  final anyIcon = iconCells.any((c) => c.isNotEmpty);

  buf.writeln('\\noindent');
  final colSpec = List.filled(cols, 'p{${_npcCellWidthEm}em}').join();
  buf.writeln('\\begin{tabular}{$colSpec}');
  for (var i = 0; i < labelCells.length; i += cols) {
    if (anyIcon) {
      final row = iconCells.skip(i).take(cols).toList();
      while (row.length < cols) {
        row.add('');
      }
      buf.writeln('${row.join(' & ')} \\\\');
    }
    final row = labelCells.skip(i).take(cols).toList();
    while (row.length < cols) {
      row.add('');
    }
    buf.writeln('${row.join(' & ')} \\\\');
  }
  buf.writeln('\\end{tabular}');
  buf.writeln();
}

/// Writes an element's visibility condition as an italic line (when present).
void _writeVisibility(
  StringBuffer buf,
  dynamic rules,
  Map<String, Map> keByUuid,
  LatexLabels labels,
) {
  final text = _visibilityText(rules, keByUuid, labels);
  if (text != null) buf.writeln('\\textit{$text}\\par');
}

/// `Visible when (<op>): name1, name2` for a `visibility_rules`, or null when the
/// rule is absent/empty or none of its key events resolve.
String? _visibilityText(
  dynamic rules,
  Map<String, Map> keByUuid,
  LatexLabels labels,
) {
  if (rules is! Map) return null;
  final refs = rules['key_events'];
  if (refs is! List || refs.isEmpty) return null;
  final names = <String>[];
  for (final r in refs) {
    final ke = r is String ? keByUuid[r] : null;
    if (ke != null) {
      final n = _str(ke['name']);
      if (n.isNotEmpty) names.add(latexEscape(n));
    }
  }
  if (names.isEmpty) return null;
  final op = _str(rules['op']).isNotEmpty ? _str(rules['op']) : 'and';
  return '${latexEscape(labels.visibleWhen)} ($op): ${names.join(', ')}';
}

List<dynamic> _list(dynamic v) => v is List ? v : const [];

String _str(dynamic v) => v is String ? v : '';

/// A scene reference entry as a string: the raw string, or the first string value
/// of a `{name}` / `{..._uuid}` reference object (tolerant of either shape).
String _refString(dynamic e) {
  if (e is String) return e;
  if (e is Map) {
    for (final v in e.values) {
      if (v is String) return v;
    }
  }
  return '';
}

/// Indexes a collection list by a string [key] field (uuid / name).
Map<String, Map> _byKey(dynamic listV, String key) {
  final out = <String, Map>{};
  if (listV is List) {
    for (final e in listV) {
      if (e is Map && e[key] is String) out[e[key] as String] = e;
    }
  }
  return out;
}
