import '../stat_template.dart';
import 'seven_sea_data.dart';

export 'seven_sea_data.dart' show Advantage, kAdvantages, kAdvantageByKey;

/// 7th Sea 2nd Edition NPC system.
///
/// An NPC is one of three KINDS chosen first (Villain / Brute squad / Monster);
/// the kind steers which stat fields apply:
///  * **Monster** — no stats (only the common NPC fields).
///  * **Brute squad** — adds `strength` (a 3-digit numeric field).
///  * **Villain** — adds `strength`, `influence` (both 3-digit numeric), a
///    computed `villainy_rank` (= strength + AVAILABLE influence, i.e. reduced by
///    influence invested in schemes), an `advantages` checklist ([kAdvantages])
///    and a `schemes` list (Intrygi, each cost spent from influence).
///
/// The template is the single source of truth for keys / defaults / validation;
/// `villainy_rank` is DERIVED (computed on read, never persisted). On save only
/// the stats APPLICABLE to the chosen kind are written (hidden fields are pruned
/// — see `NpcsController` + [SystemDef.pruneHiddenStats]).
class SevenSea {
  const SevenSea._();

  static const String systemId = '7thsea2e';
  static const String systemName = '7th Sea 2nd Edition';

  /// The three NPC kinds, in selection order (the first is the default).
  static const List<String> kinds = ['villain', 'brute_squad', 'monster'];

  /// Numeric stat fields (strength/influence) are limited to 3 digits (0–999).
  static const int statDigits = 3;
  static const int statMax = 999;

  /// The `advantages` enum options — every [Advantage.key], in table order.
  static List<String> get advantageKeys => [for (final a in kAdvantages) a.key];

  // --- Schemes / Intrygi ----------------------------------------------------

  /// A scheme's `type`: a named **Intryga** ([schemeTypeScheme]) — the only kind
  /// the form adds — or a raw influence **Koszt** ([schemeTypeCost]).
  static const String schemeTypeScheme = 'scheme';
  static const String schemeTypeCost = 'cost';
  static const List<String> schemeTypes = [schemeTypeScheme, schemeTypeCost];

  /// The villain's schemes (`stats.schemes`), each a `{type, name, cost}` map.
  /// Empty when absent / not a Villain.
  static List<Map<String, dynamic>> schemes(Map<String, dynamic> stats) {
    final raw = stats['schemes'];
    if (raw is! List) return const [];
    return [
      for (final s in raw)
        if (s is Map) Map<String, dynamic>.from(s),
    ];
  }

  /// The schemes of one [type] — `schemeTypeScheme` for the named **Intrygi**
  /// (left panel of the play manager), `schemeTypeCost` for the purchased
  /// **Koszty** (right panel). Order preserved.
  static List<Map<String, dynamic>> schemesOfType(
    Map<String, dynamic> stats,
    String type,
  ) => [
    for (final s in schemes(stats))
      if ((s['type'] ?? schemeTypeScheme) == type) s,
  ];

  /// Whether a scheme has been RESOLVED (settled in the play view) — greyed and
  /// moved to the end of the list. A resolved Intryga still counts its cost.
  static bool schemeResolved(Map<String, dynamic> scheme) =>
      scheme['resolved'] == true;

  /// The influence committed to **Intrygi** (only `schemeTypeScheme` entries count
  /// — a Koszt purchase already reduced the stored influence directly, so it must
  /// NOT be double-counted). Resolved Intrygi STILL count (settling only pays out
  /// `cost × 2` into the stored influence, §3a).
  static int schemeCostTotal(Map<String, dynamic> stats) {
    var total = 0;
    for (final s in schemesOfType(stats, schemeTypeScheme)) {
      final c = s['cost'];
      if (c is int) total += c;
    }
    return total;
  }

  /// Influence still available to spend on schemes = `influence` − Intryga costs.
  /// [excludeIndex] omits the scheme at that index in the FULL `schemes` list from
  /// the committed sum (so EDITING an Intryga can keep or lower its own cost).
  /// Never negative-clamped — a caller compares a candidate cost against it.
  static int availableInfluence(
    Map<String, dynamic> stats, {
    int? excludeIndex,
  }) {
    final all = schemes(stats);
    var committed = 0;
    for (var i = 0; i < all.length; i++) {
      if (i == excludeIndex) continue;
      if ((all[i]['type'] ?? schemeTypeScheme) != schemeTypeScheme) continue;
      final c = all[i]['cost'];
      if (c is int) committed += c;
    }
    return _int(stats, 'influence') - committed;
  }

  static int _int(Map<String, dynamic> s, String key) {
    final v = s[key];
    return v is int ? v : 0;
  }

  /// Villainy Rank = Strength + AVAILABLE Influence (the influence rating MINUS
  /// what is invested in schemes — [availableInfluence]). Investing influence in an
  /// Intryga therefore recalculates the rank live, so the tile stays consistent:
  /// Rank always equals Strength + the Influence badge. With no schemes it
  /// reduces to Strength + Influence.
  static int villainyRank(Map<String, dynamic> s) =>
      _int(s, 'strength') + availableInfluence(s);

  /// Derivation registry: id -> pure function.
  static final Map<String, Object? Function(Map<String, dynamic>)> derivations =
      {'villainy_rank': villainyRank};

  static Object? derive(String id, Map<String, dynamic> stats) =>
      derivations[id]?.call(stats);

  /// How many equal Advantage columns fit [availableWidth] when each item needs
  /// at least [itemMinWidth] px (the widest advantage label plus its checkbox +
  /// padding, so a name is NEVER wrapped). The column count therefore adapts to
  /// BOTH the form width and the advantage names.
  /// Always at least 1 (a very narrow form shows a single column).
  static int advantageColumns(double availableWidth, double itemMinWidth) {
    if (availableWidth <= 0 || itemMinWidth <= 0) return 1;
    final fit = availableWidth ~/ itemMinWidth;
    return fit < 1 ? 1 : fit;
  }

  static StatTemplate get template => _template;
  static final StatTemplate _template = _buildTemplate();
}

const _ifVillain = ShowWhen('kind', 'villain');
const _ifVillainOrBrute = ShowWhen.oneOf('kind', ['villain', 'brute_squad']);

/// A 3-digit numeric stat field (0–999), shown only for the given kind(s).
StatField _numeric(String key, String labelKey, ShowWhen when) => StatField(
  key: key,
  labelKey: labelKey,
  type: StatType.intField,
  min: 0,
  max: SevenSea.statMax,
  defaultValue: 0,
  showWhen: when,
);

StatTemplate _buildTemplate() => StatTemplate([
  // Page 1 — the NPC kind selector (rendered as radio buttons).
  const StatPage(
    key: 'npc.7thsea.page.kind',
    titleKey: 'npcSeaPageKind',
    groups: [
      StatGroup(
        labelKey: 'npcSeaPageKind',
        fields: [
          StatField(
            key: 'kind',
            labelKey: 'npcSeaKindLabel',
            type: StatType.enumField,
            options: SevenSea.kinds,
            defaultValue: 'villain',
            required: true,
          ),
        ],
      ),
    ],
  ),
  // Page 2 — details: common NPC fields (handled by the screen) plus the
  // kind-specific stats.
  StatPage(
    key: 'npc.7thsea.page.details',
    titleKey: 'npcSeaPageDetails',
    groups: [
      StatGroup(
        labelKey: 'npcSeaPageDetails',
        fields: [
          _numeric('strength', 'statSeaStrength', _ifVillainOrBrute),
          _numeric('influence', 'statSeaInfluence', _ifVillain),
          const StatField(
            key: 'villainy_rank',
            labelKey: 'statSeaVillainyRank',
            type: StatType.intField,
            derived: 'villainy_rank',
            showWhen: _ifVillain,
          ),
          StatField(
            key: 'advantages',
            labelKey: 'statSeaAdvantages',
            type: StatType.enumMulti,
            options: SevenSea.advantageKeys,
            showWhen: _ifVillain,
          ),
          // Schemes / Intrygi — a list of {type, name, cost}. The form adds
          // only type "scheme" (Intryga); each cost is spent from `influence`.
          StatField(
            key: 'schemes',
            labelKey: 'statSeaSchemes',
            type: StatType.list,
            showWhen: _ifVillain,
            item: [
              StatField(
                key: 'type',
                labelKey: 'statSeaSchemes',
                type: StatType.enumField,
                options: SevenSea.schemeTypes,
                defaultValue: SevenSea.schemeTypeScheme,
              ),
              StatField(
                key: 'name',
                labelKey: 'npcSeaSchemeName',
                type: StatType.text,
                required: true,
              ),
              StatField(
                key: 'cost',
                labelKey: 'npcSeaSchemeCost',
                type: StatType.intField,
                min: 0,
                defaultValue: 0,
                required: true,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
]);
