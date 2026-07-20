import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../npcs/seven_sea/seven_sea.dart';
import 'tile_lock.dart';

/// The 7th Sea stat badges shown at the bottom of an NPC tile.
/// Two kinds carry badges:
///   - a **Villain** (`kind == 'villain'`) — Strength / Influence / Rank;
///   - a **Brute** (`kind == 'brute_squad'`, the "Brutes, Monsters, Allies" NPC)
///     — Strength ONLY, drawn as a single CENTERED badge.
/// A Story character (`monster`) and every non-7th-Sea NPC leave the tile plain
/// (`NpcTile.villain == null`).
class NpcVillainStats {
  const NpcVillainStats({
    this.kind = 'villain',
    required this.strength,
    required this.influence,
    required this.rank,
    this.advantages = const [],
  });

  /// The NPC kind driving how many badges are drawn: `villain` (three) or
  /// `brute_squad` (one, centered). Defaults to `villain`.
  final String kind;

  final int strength;

  /// The AVAILABLE influence shown on the tile: the stored `influence` MINUS the
  /// influence invested in schemes (`SevenSea.availableInfluence`). 0 for a Brute.
  final int influence;

  /// The Villainy Rank (= strength + AVAILABLE influence, so it is recalculated
  /// when influence is invested in schemes — it always equals strength +
  /// [influence]). 0 for a Brute (no rank).
  final int rank;

  /// The villain's selected Advantage keys (`stats.advantages`), in table order;
  /// empty when none are chosen (always empty for a Brute). The tile badges
  /// ignore this — it is used by the Play view's NPC info dialog, which lists the
  /// advantages in two columns.
  final List<String> advantages;
}

/// The 7th Sea badge values for an NPC, or `null` when the NPC's kind carries no
/// badges (a Story character / a non-7th-Sea NPC). A **Villain** yields all three
/// (Strength / AVAILABLE-Influence / Rank + advantages); a **Brute** yields
/// Strength only (influence/rank 0, no advantages). The Influence badge shows the
/// influence STILL AVAILABLE — the stored rating minus what is invested in schemes
/// (`SevenSea.availableInfluence`) — and the Rank is recalculated from it
/// (Strength + available Influence, `SevenSea.villainyRank`), so Rank always equals
/// Strength + the Influence badge. Shared by
/// every place that renders an NPC tile — the game NPC grid AND the Play view — so
/// the tile looks the same everywhere.
NpcVillainStats? sevenSeaVillain(String? systemId, Object? stats) {
  if (systemId != SevenSea.systemId) return null;
  if (stats is! Map) return null;
  final kind = stats['kind'];
  if (kind != 'villain' && kind != 'brute_squad') return null;
  final s = Map<String, dynamic>.from(stats);
  int at(String k) => s[k] is int ? s[k] as int : 0;
  final isVillain = kind == 'villain';
  final adv = s['advantages'];
  return NpcVillainStats(
    kind: kind as String,
    strength: at('strength'),
    // Influence badge = stored influence − influence invested in schemes.
    influence: isVillain ? SevenSea.availableInfluence(s) : 0,
    // Rank = strength + AVAILABLE influence, recalculated as schemes are invested
    // (SevenSea.villainyRank), so Rank == strength + the Influence badge.
    rank: isVillain ? SevenSea.villainyRank(s) : 0,
    advantages: isVillain && adv is List
        ? adv.whereType<String>().toList()
        : const [],
  );
}

/// One cell of the NPC grid. Same shape as the Adventure
/// tile: the NPC's icon image fills the tile (1:1.43), with a circular context
/// menu (Clone / Delete) pinned top-right. Tapping the tile opens the editor.
///
/// For a 7th Sea Villain or Brute ([villain] non-null) solid badges are laid
/// across the BOTTOM of the tile — three for a Villain (Strength, Influence,
/// Rank), one centered for a Brute (Strength) — each a large value over a smaller
/// trait name ([NpcVillainBadges]).
///
/// Keys are parameterised by the NPC's `npc_uuid` so every tile is unique.
class NpcTile extends StatelessWidget {
  const NpcTile({
    super.key,
    required this.uuid,
    required this.image,
    required this.onTap,
    required this.onClone,
    required this.onDelete,
    this.villain,
    this.locked = false,
  });

  /// The grid's max cell width (the `SliverGridDelegateWithMaxCrossAxisExtent`
  /// upper bound). Single source of truth for "the NPC tile size", reused by the
  /// NPC editor's icon_image picker so it matches the tile.
  static const double maxExtent = 220;

  /// Portrait role-image ratio (width / height), 1:1.43.
  static const double aspectRatio = 1 / 1.43;

  final String uuid;

  /// The NPC's icon image (`images/npcs/<icon_image>.png`), or `null`.
  final File? image;

  final VoidCallback onTap;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  /// The 7th Sea Villain badge values, or `null` for a non-Villain / non-7th-Sea
  /// NPC (then no badges are drawn).
  final NpcVillainStats? villain;

  /// Immutable base content in save-content editing: the tile
  /// does not open the editor, its menu offers only Clone (no Delete — the base
  /// NPC is frozen), and a lock badge is overlaid. Clone stays available because
  /// it creates a NEW (mutable) NPC without touching the frozen one.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: InkWell(
        key: ValueKey('game.npc.tile.$uuid'),
        onTap: locked ? null : onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image.file(image!, fit: BoxFit.cover)
                else
                  ColoredBox(color: scheme.surfaceContainerHighest),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.secondaryContainer,
                    ),
                    child: PopupMenuButton<String>(
                      key: ValueKey('game.npc.tile.menu.$uuid'),
                      icon: Icon(
                        Icons.more_vert,
                        color: scheme.onSecondaryContainer,
                      ),
                      onSelected: (value) {
                        if (value == 'clone') onClone();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          key: ValueKey('game.npc.tile.menu.$uuid.item.clone'),
                          value: 'clone',
                          child: Text(l10n.npcsClone),
                        ),
                        // A frozen (immutable) base NPC cannot be deleted.
                        if (!locked)
                          PopupMenuItem<String>(
                            key: ValueKey(
                              'game.npc.tile.menu.$uuid.item.delete',
                            ),
                            value: 'delete',
                            child: Text(l10n.npcsDelete),
                          ),
                      ],
                    ),
                  ),
                ),
                // Lock badge (top-left) marking a frozen base NPC.
                if (locked)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: TileLockBadge(
                      badgeKey: ValueKey('game.npc.tile.$uuid.locked'),
                    ),
                  ),
                if (villain != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NpcVillainBadges(
                      keyPrefix: 'game.npc.tile.$uuid',
                      villain: villain!,
                      tileHeight: constraints.maxHeight,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The 7th Sea stat badges laid across the bottom of an NPC tile.
/// Shared by the game NPC grid ([NpcTile]) and the
/// Play view so the tile looks IDENTICAL in both. The band is one badge tall —
/// 1/5 of [tileHeight]; each badge is a cell with a margin so it touches neither
/// its neighbours nor the tile edges, a solid `secondaryContainer` box with a
/// LARGE value over a SMALLER trait name.
///
/// The badge COUNT follows the kind: a **Villain** shows three (Strength,
/// Influence, Rank across the band); a **Brute** shows ONE — Strength — CENTERED,
/// taking the same 1/3 cell width as a single villain badge.
///
/// [keyPrefix] scopes the keys to the host tile (`game.npc.tile.<uuid>` or
/// `play.npc.tile.<uuid>`): the band is `<keyPrefix>.villain`, each badge
/// `<keyPrefix>.villain.<trait>`, its value `<keyPrefix>.villain.<trait>.value`.
class NpcVillainBadges extends StatelessWidget {
  const NpcVillainBadges({
    super.key,
    required this.keyPrefix,
    required this.villain,
    required this.tileHeight,
  });

  /// Each badge is this fraction of the tile height (1/5).
  static const double heightFraction = 1 / 5;

  final String keyPrefix;
  final NpcVillainStats villain;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    // One badge cell: the margin (outer Padding) keeps it off its neighbours and
    // the tile edges; the KEY is on the inner box, so its measured rect excludes
    // the margin.
    Widget cell(String label, int value, String id) => Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        key: ValueKey('$keyPrefix.villain.$id'),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        // ONE FittedBox scales the whole value-over-name unit down to the
        // (possibly tiny) cell. A per-child `Expanded(value) + FittedBox(name)`
        // split overflowed by ~1px on very small tiles, because the name's
        // natural line height could not shrink below the cell height.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The large trait value over the smaller trait name; the 48:11
              // font ratio keeps the value prominent at every scale.
              Text(
                '$value',
                key: ValueKey('$keyPrefix.villain.$id.value'),
                style: TextStyle(
                  fontSize: 48,
                  height: 1.0,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // A Brute has ONLY Strength — its single badge is centered (a 1/3-width cell
    // flanked by equal spacers). A Villain shows all three across the band.
    final Widget band;
    if (villain.kind == 'brute_squad') {
      band = Row(
        children: [
          const Spacer(),
          Expanded(
            child: cell(l10n.npcSeaTileStrength, villain.strength, 'strength'),
          ),
          const Spacer(),
        ],
      );
    } else {
      band = Row(
        children: [
          Expanded(
            child: cell(l10n.npcSeaTileStrength, villain.strength, 'strength'),
          ),
          Expanded(
            child: cell(
              l10n.npcSeaTileInfluence,
              villain.influence,
              'influence',
            ),
          ),
          Expanded(child: cell(l10n.npcSeaTileRank, villain.rank, 'rank')),
        ],
      );
    }

    return SizedBox(
      key: ValueKey('$keyPrefix.villain'),
      height: tileHeight * heightFraction,
      child: band,
    );
  }
}
