import '../../l10n/app_localizations.dart';
import 'seven_sea_data.dart';

/// Resolves a 7th Sea template `labelKey` / `titleKey` (a stable string stored in
/// the [SevenSea] template) to its localized text. The form chrome and field
/// labels are localized in EN + PL (other languages fall back to the English
/// placeholder).
String seaLabel(AppLocalizations l, String key) {
  switch (key) {
    // Page titles.
    case 'npcSeaPageKind':
      return l.npcSeaPageKind;
    case 'npcSeaPageDetails':
      return l.npcSeaPageDetails;
    // Field labels.
    case 'npcSeaKindLabel':
      return l.npcSeaKindLabel;
    case 'statSeaStrength':
      return l.statSeaStrength;
    case 'statSeaInfluence':
      return l.statSeaInfluence;
    case 'statSeaVillainyRank':
      return l.statSeaVillainyRank;
    case 'statSeaAdvantages':
      return l.statSeaAdvantages;
    case 'statSeaSchemes':
      return l.statSeaSchemes;
    default:
      return key;
  }
}

/// The localized label of an NPC kind (`villain` / `brute_squad` / `monster`).
String seaKindLabel(AppLocalizations l, String kind) {
  switch (kind) {
    case 'villain':
      return l.npcSeaKindVillain;
    case 'brute_squad':
      return l.npcSeaKindBrute;
    case 'monster':
      return l.npcSeaKindMonster;
    default:
      return kind;
  }
}

/// The DISPLAY label of an Advantage, by its stored [key]. Polish (`pl`) uses
/// the Polish name; every other locale uses the English name.
String seaAdvantageLabel(AppLocalizations l, String key) {
  final a = kAdvantageByKey[key];
  if (a == null) return key;
  return l.localeName == 'pl' ? a.pl : a.en;
}
