import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/cover_crop.dart';
import 'package:living_scroll/create/game_systems.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/npcs/seven_sea/seven_sea.dart';
import 'package:living_scroll/npcs/stat_template.dart';

/// A controller bound to the 7th Sea system, with images staged so [canSave]
/// passes. Returns it mid-edit of a fresh NPC.
NpcsController _editing({required String kind, String name = 'Nemo'}) {
  final c = NpcsController(newId: () => 'new-uuid');
  c.setTemplate(SevenSea.template,
      systemId: SevenSea.systemId, pruneHiddenStats: true);
  c.loadFrom({'npcs': []});
  c.beginNew();
  c.editName = name;
  c.stageFull('/tmp/full.png');
  c.stageIcon(const CoverCrop(left: 0, top: 0, width: 1, height: 0.7));
  c.setStat('kind', kind);
  return c;
}

Map<String, dynamic> _savedStats(NpcsController c) {
  expect(c.save(), isTrue);
  return Map<String, dynamic>.from(c.toJson().first['stats'] as Map);
}

void main() {
  group('SevenSea model', () {
    test('system identity', () {
      expect(SevenSea.systemId, '7thsea2e');
      expect(SevenSea.systemName, '7th Sea 2nd Edition');
      expect(SevenSea.kinds, ['villain', 'brute_squad', 'monster']);
    });

    test('villainy rank = strength + AVAILABLE influence', () {
      expect(SevenSea.villainyRank({'strength': 5, 'influence': 3}), 8);
      expect(SevenSea.villainyRank({'strength': 7}), 7); // missing influence -> 0
      expect(SevenSea.villainyRank(const {}), 0);
      expect(SevenSea.derive('villainy_rank', {'strength': 2, 'influence': 9}), 11);
    });

    test('villainy rank is recalculated when influence is invested in schemes', () {
      final stats = {
        'strength': 6,
        'influence': 10,
        'schemes': [
          {'type': 'scheme', 'name': 'A', 'cost': 4},
          {'type': 'scheme', 'name': 'B', 'cost': 3},
        ],
      };
      // 6 + (10 - 7) = 9, not 6 + 10.
      expect(SevenSea.villainyRank(stats), 9);
      expect(SevenSea.derive('villainy_rank', stats), 9);
      // Rank == strength + available influence, always.
      expect(SevenSea.villainyRank(stats),
          6 + SevenSea.availableInfluence(stats));
    });

    test('3-digit numeric bound', () {
      expect(SevenSea.statDigits, 3);
      expect(SevenSea.statMax, 999);
    });
  });

  group('schemes / intrygi', () {
    Map<String, dynamic> statsWith(List<Map<String, dynamic>> schemes,
            {int influence = 10}) =>
        {
          'kind': 'villain',
          'strength': 5,
          'influence': influence,
          'schemes': schemes,
        };

    test('scheme types', () {
      expect(SevenSea.schemeTypeScheme, 'scheme');
      expect(SevenSea.schemeTypeCost, 'cost');
      expect(SevenSea.schemeTypes, ['scheme', 'cost']);
    });

    test('schemes() reads the list; empty when absent/invalid', () {
      expect(SevenSea.schemes(const {}), isEmpty);
      expect(SevenSea.schemes({'schemes': 'nope'}), isEmpty);
      final list = SevenSea.schemes(statsWith([
        {'type': 'scheme', 'name': 'A', 'cost': 3}
      ]));
      expect(list, hasLength(1));
      expect(list.first['name'], 'A');
    });

    test('cost total sums every scheme cost', () {
      expect(
          SevenSea.schemeCostTotal(statsWith([
            {'type': 'scheme', 'name': 'A', 'cost': 3},
            {'type': 'scheme', 'name': 'B', 'cost': 4},
          ])),
          7);
      expect(SevenSea.schemeCostTotal(statsWith(const [])), 0);
    });

    test('available influence = influence − committed costs', () {
      final s = statsWith(influence: 10, [
        {'type': 'scheme', 'name': 'A', 'cost': 3},
        {'type': 'scheme', 'name': 'B', 'cost': 4},
      ]);
      expect(SevenSea.availableInfluence(s), 3); // 10 - 7
      // Editing index 1 frees its own cost from the budget.
      expect(SevenSea.availableInfluence(s, excludeIndex: 1), 7); // 10 - 3
      expect(SevenSea.availableInfluence(s, excludeIndex: 0), 6); // 10 - 4
    });

    test('template: schemes is a villain-only list field of {type,name,cost}', () {
      final f = SevenSea.template.fieldFor('schemes')!;
      expect(f.type, StatType.list);
      expect(f.showWhen!.matches({'kind': 'villain'}), isTrue);
      expect(f.showWhen!.matches({'kind': 'monster'}), isFalse);
      expect(f.item.map((s) => s.key), ['type', 'name', 'cost']);
      expect(f.item.firstWhere((s) => s.key == 'name').required, isTrue);
      expect(f.item.firstWhere((s) => s.key == 'cost').required, isTrue);
    });

    test('save keeps schemes for a Villain, prunes them for other kinds', () {
      final villain = _editing(kind: 'villain');
      villain.setStat('influence', 10);
      villain.setStat('schemes', [
        {'type': 'scheme', 'name': 'Plot', 'cost': 4}
      ]);
      final vStats = _savedStats(villain);
      expect(vStats['schemes'], [
        {'type': 'scheme', 'name': 'Plot', 'cost': 4}
      ]);

      // A Brute has no influence/schemes -> both pruned.
      final brute = _editing(kind: 'brute_squad');
      brute.setStat('schemes', [
        {'type': 'scheme', 'name': 'X', 'cost': 1}
      ]);
      expect(_savedStats(brute).containsKey('schemes'), isFalse);
    });
  });

  group('template', () {
    final t = SevenSea.template;

    test('two pages: kind then details', () {
      expect(t.pages.length, 2);
      expect(t.pages[0].key, 'npc.7thsea.page.kind');
      expect(t.pages[1].key, 'npc.7thsea.page.details');
    });

    test('kind field defaults to villain and is required', () {
      final kind = t.fieldFor('kind')!;
      expect(kind.type, StatType.enumField);
      expect(kind.options, SevenSea.kinds);
      expect(kind.defaultValue, 'villain');
      expect(kind.required, isTrue);
      expect(kind.showWhen, isNull); // always present (the discriminator)
    });

    test('strength shows for villain + brute, influence for villain only', () {
      final strength = t.fieldFor('strength')!;
      expect(strength.max, 999);
      expect(strength.showWhen!.matches({'kind': 'villain'}), isTrue);
      expect(strength.showWhen!.matches({'kind': 'brute_squad'}), isTrue);
      expect(strength.showWhen!.matches({'kind': 'monster'}), isFalse);

      final influence = t.fieldFor('influence')!;
      expect(influence.showWhen!.matches({'kind': 'villain'}), isTrue);
      expect(influence.showWhen!.matches({'kind': 'brute_squad'}), isFalse);
    });

    test('villainy_rank is derived (never a plain input)', () {
      final rank = t.fieldFor('villainy_rank')!;
      expect(rank.isDerived, isTrue);
      expect(rank.derived, 'villainy_rank');
      expect(rank.showWhen!.matches({'kind': 'villain'}), isTrue);
    });

    test('advantages is an enumMulti over every advantage key, villain only', () {
      final adv = t.fieldFor('advantages')!;
      expect(adv.type, StatType.enumMulti);
      expect(adv.options, SevenSea.advantageKeys);
      expect(adv.showWhen!.matches({'kind': 'villain'}), isTrue);
      expect(adv.showWhen!.matches({'kind': 'brute_squad'}), isFalse);
    });
  });

  group('advantages data', () {
    test('canonical count, unique keys, both names present', () {
      expect(kAdvantages.length, 76);
      final keys = kAdvantages.map((a) => a.key).toSet();
      expect(keys.length, kAdvantages.length); // no duplicate keys
      for (final a in kAdvantages) {
        expect(a.en, isNotEmpty);
        expect(a.pl, isNotEmpty);
        expect(a.points, inInclusiveRange(1, 5));
      }
    });

    test('spot-check EN/PL pairs from the canonical table', () {
      expect(kAdvantageByKey['able_drunker']!.pl, 'Mocna głowa');
      expect(kAdvantageByKey['sorcery']!.pl, 'Magia');
      expect(kAdvantageByKey['the_devils_own_luck']!.en, "The devil's own luck");
      expect(kAdvantageByKey['the_devils_own_luck']!.pl, 'Cholerne szczęście');
    });
  });

  group('validation', () {
    test('a valid villain stats map passes', () {
      final errors = validateStats(SevenSea.template, {
        'kind': 'villain',
        'strength': 5,
        'influence': 4,
        'advantages': ['sorcery', 'reputation'],
      });
      expect(errors, isEmpty);
    });

    test('an unknown advantage key is rejected', () {
      final errors = validateStats(SevenSea.template, {
        'kind': 'villain',
        'strength': 0,
        'influence': 0,
        'advantages': ['not_a_real_advantage'],
      });
      expect(errors, isNotEmpty);
    });
  });

  group('save prunes stats to the chosen kind', () {
    test('monster stores only its kind (no strength/influence/advantages)', () {
      final stats = _savedStats(_editing(kind: 'monster'));
      expect(stats, {'kind': 'monster'});
    });

    test('brute squad stores kind + strength only', () {
      final c = _editing(kind: 'brute_squad')..setStat('strength', 8);
      final stats = _savedStats(c);
      expect(stats, {'kind': 'brute_squad', 'strength': 8});
    });

    test('villain stores kind + strength + influence + advantages, not rank', () {
      final c = _editing(kind: 'villain')
        ..setStat('strength', 6)
        ..setStat('influence', 3)
        ..setStat('advantages', ['sorcery']);
      final stats = _savedStats(c);
      expect(stats, {
        'kind': 'villain',
        'strength': 6,
        'influence': 3,
        'advantages': ['sorcery'],
        'schemes': <Map<String, dynamic>>[], // present (empty) for a villain
      });
      expect(stats.containsKey('villainy_rank'), isFalse); // derived, never stored
    });
  });

  group('advantage column count', () {
    test('as many equal columns as fit the width', () {
      expect(SevenSea.advantageColumns(1000, 200), 5);
      expect(SevenSea.advantageColumns(999, 200), 4); // floor, no partial column
      expect(SevenSea.advantageColumns(640, 200), 3);
    });

    test('never fewer than one column', () {
      expect(SevenSea.advantageColumns(150, 200), 1); // too narrow for even one
      expect(SevenSea.advantageColumns(0, 200), 1);
      expect(SevenSea.advantageColumns(500, 0), 1); // guard against /0
    });

    test('more width -> at least as many columns (monotonic)', () {
      const itemMin = 180.0;
      var prev = 0;
      for (var w = 100.0; w <= 2000; w += 100) {
        final n = SevenSea.advantageColumns(w, itemMin);
        expect(n, greaterThanOrEqualTo(prev == 0 ? 1 : prev));
        prev = n;
      }
    });
  });

  group('GameSystems registration', () {
    test('7th Sea is a supported, selectable system', () {
      expect(GameSystems.ids, contains('7thsea2e'));
      expect(GameSystems.names['7thsea2e'], '7th Sea 2nd Edition');
      expect(GameSystems.templateFor('7thsea2e'), same(SevenSea.template));
      expect(GameSystems.pruneHiddenStatsFor('7thsea2e'), isTrue);
      expect(GameSystems.pruneHiddenStatsFor('basic'), isFalse);
    });
  });
}
