import '../npcs/seven_sea/seven_sea.dart';
import '../npcs/stat_template.dart';

/// One supported game system: its display [name] and its [npcTemplate] — the
/// system-bound stat fields layered on top of the common NPC fields.
/// Basic RPG adds none ([StatTemplate.empty]); 7th Sea 2e a kind-driven form.
class SystemDef {
  const SystemDef({
    required this.name,
    required this.npcTemplate,
    this.selectable = true,
    this.pruneHiddenStats = false,
  });

  final String name;
  final StatTemplate npcTemplate;

  /// Whether this system is offered in the new-adventure System dropdown. A
  /// non-selectable system stays fully supported (valid, openable, its NPC
  /// template active) — it just can't be chosen for a NEW adventure.
  final bool selectable;

  /// When true, saving an NPC persists ONLY the stats APPLICABLE to the current
  /// state (fields hidden by their `showWhen` are pruned), instead of the whole
  /// seeded stats map. Used by 7th Sea 2e, where a Monster stores no stats, a
  /// Brute squad only `strength`, etc.
  final bool pruneHiddenStats;
}

/// The catalogue of game systems this build supports (id -> [SystemDef]).
///
/// It is the single source of truth used by:
///   * the new-adventure form's System dropdown ([names]),
///   * the Adventure settings System field (disabled, label lookup),
///   * the system-specific NPC editor ([templateFor]), and
///   * adventure validation — an adventure whose stored `metadata.system` is not
///     one of [ids] cannot be opened by this build, so its Create-grid tile
///     renders in the invalid state.
class GameSystems {
  const GameSystems._();

  /// Supported systems, id -> definition.
  static final Map<String, SystemDef> catalogue = {
    'basic': const SystemDef(
      name: 'Basic RPG',
      npcTemplate: StatTemplate.empty,
    ),
    // 7th Sea 2e: a kind-driven NPC form; only the applicable stats are stored.
    SevenSea.systemId: SystemDef(
      name: SevenSea.systemName,
      npcTemplate: SevenSea.template,
      pruneHiddenStats: true,
    ),
  };

  /// All supported system ids (for validation — every catalogue system stays
  /// valid/openable, regardless of [SystemDef.selectable]).
  static Set<String> get ids => catalogue.keys.toSet();

  /// id -> display name for the new-adventure System dropdown — SELECTABLE
  /// systems only.
  static Map<String, String> get names => {
    for (final e in catalogue.entries)
      if (e.value.selectable) e.key: e.value.name,
  };

  /// id -> display name for EVERY supported system (used where a non-selectable
  /// system must still render, e.g. the immutable Adventure-settings field).
  static Map<String, String> get allNames => {
    for (final e in catalogue.entries) e.key: e.value.name,
  };

  /// The display name of a system id, or null if unknown.
  static String? nameOf(String id) => catalogue[id]?.name;

  /// The NPC stat template bound to a system id (empty for unknown systems).
  static StatTemplate templateFor(String? id) =>
      catalogue[id]?.npcTemplate ?? StatTemplate.empty;

  /// Whether a system persists only the applicable (visible) NPC stats on save
  /// ([SystemDef.pruneHiddenStats]); false for unknown systems.
  static bool pruneHiddenStatsFor(String? id) =>
      catalogue[id]?.pruneHiddenStats ?? false;
}
