// Chapter 2 (NPCs) of the LaTeX export. A pure generator: decoded doc + labels
// + asset sink -> LaTeX.

import '../../npcs/seven_sea/seven_sea.dart';
import 'latex_model.dart';
import 'latex_text.dart';

/// Renders Chapter 2 — one `\subsection` per NPC in `doc['npcs']` order, each
/// labelled `npc:<npc_uuid>` (matching the `\hyperref[npc:<uuid>]` links from the
/// scenes chapter), with the portrait then a Short description / Backstory
/// subsubsection (only when non-empty). The portrait is registered on [assets] and
/// emitted only when the source file exists. Emits NOTHING (empty string,
/// no `\chapter{NPCs}` heading at all) when the adventure defines no NPCs —
/// matching the Paths chapter's optionality — so
/// callers can `buf.write` it unconditionally.
///
/// System-specific stats: for `7thsea2e` a Villain and
/// a Brute (`brute_squad`) NPC also get a **Stats** subsubsection, and a Villain an
/// **Advantages** subsubsection — see [_writeSevenSeaStats].
String latexNpcsChapter(Map doc, LatexLabels labels, AssetSink assets) {
  final npcs = _list(doc['npcs']).whereType<Map>().toList();
  if (npcs.isEmpty) return '';

  final metadata = doc['metadata'];
  String meta(String key) => (metadata is Map && metadata[key] is String)
      ? metadata[key] as String
      : '';
  final system = meta('system');
  final langCode = meta('language');

  final buf = StringBuffer();
  buf.writeln('\\chapter{${latexEscape(labels.npcs)}}');
  buf.writeln();
  for (final n in npcs) {
    _writeNpc(buf, n, labels, assets, system, langCode);
  }
  return buf.toString();
}

void _writeNpc(
  StringBuffer buf,
  Map n,
  LatexLabels labels,
  AssetSink assets,
  String system,
  String langCode,
) {
  final name = latexEscape(_str(n['name']));
  final type = labels.npcType(system, n['stats']);
  final heading = type == null ? name : '$name (${latexEscape(type)})';
  buf.writeln('\\subsection{$heading}');
  buf.writeln('\\label{npc:${_str(n['npc_uuid'])}}');
  buf.writeln();

  // Portrait (in-column).
  final full = _str(n['full_image']);
  if (full.isNotEmpty &&
      assets.add('assets/npcfull_$full.png', 'images/npcs/$full.png')) {
    buf.writeln(
      '\\includegraphics[width=0.5\\linewidth]{assets/npcfull_$full.png}\\par',
    );
    buf.writeln();
  }

  final desc = _str(n['description']);
  if (desc.trim().isNotEmpty) {
    buf.writeln('\\subsubsection{${latexEscape(labels.shortDescription)}}');
    buf.writeln(latexParagraphs(latexEscape(desc)));
    buf.writeln();
  }

  final back = _str(n['backstory']);
  if (back.trim().isNotEmpty) {
    buf.writeln('\\subsubsection{${latexEscape(labels.backstory)}}');
    buf.writeln(latexParagraphs(latexEscape(back)));
    buf.writeln();
  }

  if (system == SevenSea.systemId) {
    _writeSevenSeaStats(buf, n['stats'], labels, langCode);
  }
}

/// 7th Sea 2e NPC stats, keyed off `stats.kind`:
///   * **villain** — a **Stats** subsubsection (Strength, Influence, computed
///     Villainy Rank) and, when it has any, an **Advantages** subsubsection listing
///     the NPC's advantages (localized: Polish uses the advantage's `pl` name);
///   * **brute_squad** ("Brutes, Monsters, Allies") — a **Stats** subsubsection
///     with Strength only;
///   * **monster** ("Story character") — no stats.
void _writeSevenSeaStats(
  StringBuffer buf,
  dynamic rawStats,
  LatexLabels labels,
  String langCode,
) {
  if (rawStats is! Map) return;
  final stats = Map<String, dynamic>.from(rawStats);
  final kind = stats['kind'];
  if (kind != 'villain' && kind != 'brute_squad') return;

  buf.writeln('\\subsubsection{${latexEscape(labels.stats)}}');
  buf.writeln(
    '\\textbf{${latexEscape(labels.strength)}:} ${_intStat(stats, 'strength')}\\par',
  );
  if (kind == 'villain') {
    buf.writeln(
      '\\textbf{${latexEscape(labels.influence)}:} ${_intStat(stats, 'influence')}\\par',
    );
    buf.writeln(
      '\\textbf{${latexEscape(labels.rank)}:} ${SevenSea.villainyRank(stats)}\\par',
    );
  }
  buf.writeln();

  if (kind != 'villain') return;
  final names = <String>[];
  for (final a in _list(stats['advantages'])) {
    if (a is! String) continue;
    final adv = kAdvantageByKey[a];
    if (adv == null) continue; // unknown advantage key -> skipped
    names.add(langCode == 'pl' ? adv.pl : adv.en);
  }
  if (names.isEmpty) return;
  buf.writeln('\\subsubsection{${latexEscape(labels.advantages)}}');
  buf.writeln('\\begin{itemize}');
  for (final name in names) {
    buf.writeln('  \\item ${latexEscape(name)}');
  }
  buf.writeln('\\end{itemize}');
  buf.writeln();
}

int _intStat(Map<String, dynamic> stats, String key) {
  final v = stats[key];
  return v is int ? v : 0;
}

List<dynamic> _list(dynamic v) => v is List ? v : const [];

String _str(dynamic v) => v is String ? v : '';
