// Shared contracts for the Export-to-LaTeX generators:
//   * [LatexAsset] / [AssetSink] — the image files the document references,
//   * [LatexLabels] — the fixed headings, in the ADVENTURE's language.
// The scene/NPC generators (latex_scenes.dart / latex_npcs.dart) consume these;
// the assembler (latex_exporter.dart) constructs an [AssetSink] backed by
// a real disk check and packages the collected [assets].

import 'dart:ui' show Locale;

import '../../l10n/app_localizations.dart';
import '../../npcs/seven_sea/seven_sea.dart';
import '../../npcs/seven_sea/seven_sea_l10n.dart';
import 'latex_preamble.dart' show normalizeLanguageCode;

/// One image the document needs: its path INSIDE the export archive and the path
/// of the source file RELATIVE to the adventure directory (`{Adventures}/<dir>/`).
class LatexAsset {
  const LatexAsset(this.archivePath, this.sourceRelPath);

  final String archivePath;
  final String sourceRelPath;
}

/// Collects the assets a document references. A generator calls [add] to register
/// an image; it returns `true` only when the source file EXISTS (per the injected
/// existence check), and the generator emits `\includegraphics` only then — so a
/// missing file drops both the asset and its reference.
/// Assets are deduplicated by [LatexAsset.archivePath] (the same image used by
/// several scenes is packaged once). Order is first-seen (deterministic).
class AssetSink {
  AssetSink(this._exists);

  final bool Function(String sourceRelPath) _exists;
  final List<LatexAsset> _assets = [];
  final Set<String> _seen = <String>{};

  /// The accepted assets, in first-seen order.
  List<LatexAsset> get assets => List.unmodifiable(_assets);

  /// Registers an asset. Returns whether it was accepted (source file exists);
  /// only then should the caller emit the graphic.
  bool add(String archivePath, String sourceRelPath) {
    if (!_exists(sourceRelPath)) return false;
    if (_seen.add(archivePath)) {
      _assets.add(LatexAsset(archivePath, sourceRelPath));
    }
    return true;
  }
}

/// The fixed document headings, in the adventure's language. A localized
/// instance is built via `LatexLabels.forLanguage`; the
/// [english] default is used by the Phase-B generator tests.
class LatexLabels {
  const LatexLabels({
    required this.scenes,
    required this.npcs,
    required this.paths,
    required this.narration,
    required this.npcsInScene,
    required this.notes,
    required this.images,
    required this.nextScenes,
    required this.shortDescription,
    required this.backstory,
    required this.visibleWhen,
    required this.sceneTypeStart,
    required this.sceneTypeStandard,
    required this.sceneTypeRecurring,
    required this.sceneTypeEnd,
    required this.stats,
    required this.strength,
    required this.influence,
    required this.rank,
    required this.advantages,
    required this.pageReference,
    required this.npcType,
  });

  /// Chapter 1 title.
  final String scenes;

  /// Chapter 2 title (and used as the in-scene NPC subsection via [npcsInScene]).
  final String npcs;

  /// The Paths chapter title, shown before Chapter 1 (Scenes) only when the
  /// adventure defines any paths.
  final String paths;

  final String narration;
  final String npcsInScene;
  final String notes;
  final String images;
  final String nextScenes;
  final String shortDescription;
  final String backstory;
  final String visibleWhen;

  final String sceneTypeStart;
  final String sceneTypeStandard;
  final String sceneTypeRecurring;
  final String sceneTypeEnd;

  // 7th Sea 2e (system `7thsea2e`) NPC stat headings.
  final String stats; // "Stats" subsubsection heading
  final String strength;
  final String influence;
  final String rank;
  final String advantages; // "Advantages" subsubsection heading + list

  /// The localized "page `<ref>`" phrase the Paths chapter (§3) wraps a scene's
  /// page-number parenthetical in — [pageRefTex] is a literal `\pageref{...}`
  /// LaTeX call, substituted VERBATIM into the language's word order (e.g. EN
  /// "page \pageref{...}", PL "strona \pageref{...}", ZH "第\pageref{...}页",
  /// JA "\pageref{...}ページ"); the ACTUAL page number resolves later, at
  /// LaTeX-compile time. Backed by the generated `latexPageReferenceTemplate`
  /// ARB message (a `{page}`placeholder), so word order lives in translation,
  /// not code.
  final String Function(String pageRefTex) pageReference;

  /// The localized "NPC type" label for a system + its `stats` map (the scene
  /// NPC table §4a and the Chapter-2 NPC heading §4), or `null` when the
  /// system has no such concept (`basic`, whose template has no stats at
  /// all) or the NPC's stats don't resolve one (missing/unrecognized `kind`)
  /// — callers omit the parenthetical entirely then. `7thsea2e` reuses
  /// [seaKindLabel] (`stats.kind`).
  final String? Function(String system, dynamic stats) npcType;

  /// The localized word for a `scene_type`, falling back to the raw value.
  String sceneType(String type) => switch (type) {
    'start' => sceneTypeStart,
    'standard' => sceneTypeStandard,
    'recurring' => sceneTypeRecurring,
    'end' => sceneTypeEnd,
    _ => type,
  };

  /// Labels for an adventure's [languageCode] (`metadata.language`, ISO), so the
  /// document headings localize to the ADVENTURE's language (§6) — NOT the app UI
  /// language. Resolved from the generated localizations; an empty / unsupported
  /// code falls back to English. [languageCode] is normalized first
  /// ([normalizeLanguageCode]: case-insensitive, endonym/exonym-tolerant) —
  /// without this, a stored `metadata.language` of e.g. `"PL"` (any case
  /// other than the canonical lowercase `"pl"`) would silently fall back to
  /// English labels here even though [polyglossiaLanguageFor] (which already
  /// lower-cases) picks the right `\setmainlanguage` in the preamble.
  static LatexLabels forLanguage(String languageCode) {
    final normalized = normalizeLanguageCode(languageCode);
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == normalized,
    );
    final l = lookupAppLocalizations(
      supported ? Locale(normalized) : const Locale('en'),
    );
    return LatexLabels(
      scenes: l.latexChapterScenes,
      npcs: l.latexChapterNpcs,
      paths: l.latexChapterPaths,
      narration: l.latexNarration,
      npcsInScene: l.latexChapterNpcs,
      notes: l.latexNotes,
      images: l.latexImages,
      nextScenes: l.latexNextScenes,
      shortDescription: l.latexShortDescription,
      backstory: l.latexBackstory,
      visibleWhen: l.latexVisibleWhen,
      sceneTypeStart: l.latexSceneTypeStart,
      sceneTypeStandard: l.latexSceneTypeStandard,
      sceneTypeRecurring: l.latexSceneTypeRecurring,
      sceneTypeEnd: l.latexSceneTypeEnd,
      // 7th Sea headings reuse the app's own EN+PL stat labels (statSea*).
      stats: l.latexStats,
      strength: l.statSeaStrength,
      influence: l.statSeaInfluence,
      rank: l.statSeaVillainyRank,
      advantages: l.statSeaAdvantages,
      pageReference: l.latexPageReferenceTemplate,
      npcType: (system, stats) => _resolveNpcType(l, system, stats),
    );
  }

  /// English defaults (Phase-B tests; production uses `forLanguage`).
  static const LatexLabels english = LatexLabels(
    scenes: 'Scenes',
    npcs: 'NPCs',
    paths: 'Paths',
    narration: 'Narration',
    npcsInScene: 'NPCs',
    notes: 'Notes',
    images: 'Images',
    nextScenes: 'Next scenes',
    shortDescription: 'Short description',
    backstory: 'Backstory',
    visibleWhen: 'Visible when',
    sceneTypeStart: 'opening scene',
    sceneTypeStandard: 'standard scene',
    sceneTypeRecurring: 'recurring scene',
    sceneTypeEnd: 'ending scene',
    stats: 'Stats',
    strength: 'Strength',
    influence: 'Influence',
    rank: 'Villainy Rank',
    advantages: 'Advantages',
    pageReference: _defaultPageReference,
    npcType: _defaultNpcType,
  );
}

/// English default for [LatexLabels.pageReference] (a top-level function, so
/// the `english` const constant can reference it as a compile-time constant).
String _defaultPageReference(String pageRefTex) => 'page $pageRefTex';

/// Resolves an NPC's localized "type" via [LatexLabels.forLanguage], shared by
/// the `7thsea2e` call site ([seaKindLabel]).
String? _resolveNpcType(AppLocalizations l, String system, dynamic stats) {
  if (stats is! Map) return null;
  if (system == SevenSea.systemId) {
    final kind = stats['kind'];
    if (kind is! String || kind.isEmpty) return null;
    return seaKindLabel(l, kind);
  }
  return null;
}

/// English-only default for [LatexLabels.npcType] (a top-level function, so
/// the `english` const constant can reference it as a compile-time constant;
/// mirrors [_resolveNpcType]'s per-system rules without an AppLocalizations
/// instance).
String? _defaultNpcType(String system, dynamic stats) {
  if (stats is! Map) return null;
  if (system == SevenSea.systemId) {
    final kind = stats['kind'];
    return switch (kind) {
      'villain' => 'Villain',
      'brute_squad' => 'Brutes, Monsters, Allies',
      'monster' => 'Story character',
      _ => null,
    };
  }
  return null;
}
