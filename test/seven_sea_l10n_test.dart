import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations_en.dart';
import 'package:living_scroll/l10n/app_localizations_pl.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea_l10n.dart';

void main() {
  final en = AppLocalizationsEn();
  final pl = AppLocalizationsPl();

  group('field / page labels', () {
    test('English', () {
      expect(seaLabel(en, 'npcSeaPageKind'), 'NPC type');
      expect(seaLabel(en, 'npcSeaPageDetails'), 'Details');
      expect(seaLabel(en, 'statSeaStrength'), 'Strength');
      expect(seaLabel(en, 'statSeaVillainyRank'), 'Villainy Rank');
      expect(seaLabel(en, 'statSeaAdvantages'), 'Advantages');
    });

    test('Polish', () {
      expect(seaLabel(pl, 'statSeaStrength'), 'Siła');
      expect(seaLabel(pl, 'statSeaInfluence'), 'Wpływy');
      expect(seaLabel(pl, 'statSeaVillainyRank'), 'Ranga Nikczemności');
      expect(seaLabel(pl, 'statSeaAdvantages'), 'Atuty');
    });
  });

  group('kind labels', () {
    test('every kind resolves to a non-empty label in both locales', () {
      for (final k in SevenSea.kinds) {
        expect(seaKindLabel(en, k), isNotEmpty);
        expect(seaKindLabel(pl, k), isNotEmpty);
      }
      expect(seaKindLabel(en, 'villain'), 'Villain');
      expect(seaKindLabel(en, 'brute_squad'), 'Brutes, Monsters, Allies');
      expect(seaKindLabel(en, 'monster'), 'Story character');
      expect(seaKindLabel(pl, 'villain'), 'Złoczyńca');
      expect(seaKindLabel(pl, 'brute_squad'), 'Łotry, Potwory, Sojusznicy');
      expect(seaKindLabel(pl, 'monster'), 'Postać fabularna');
    });
  });

  group('advantage labels are localized only for Polish', () {
    test('Polish uses the Polish name; English uses the English name', () {
      expect(seaAdvantageLabel(pl, 'able_drunker'), 'Mocna głowa');
      expect(seaAdvantageLabel(en, 'able_drunker'), 'Able Drunker');
      expect(seaAdvantageLabel(pl, 'sorcery'), 'Magia');
      expect(seaAdvantageLabel(en, 'sorcery'), 'Sorcery');
    });

    test('every advantage resolves to a non-empty label in both locales', () {
      for (final a in kAdvantages) {
        expect(seaAdvantageLabel(en, a.key), a.en);
        expect(seaAdvantageLabel(pl, a.key), a.pl);
      }
    });
  });
}
