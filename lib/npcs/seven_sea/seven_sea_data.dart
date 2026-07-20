/// Static data tables for the 7th Sea 2nd Edition NPC system. The canonical
/// source is the top EN⇥PL Advantages table, grouped by point cost; a
/// Polish-only appendix from that source is IGNORED as non-canonical.
library;

/// One Villain Advantage: a stable [key] (snake_case slug, the value stored in
/// `npcs[].stats.advantages`), its English name [en], its Polish name [pl], and
/// the [points] cost band it belongs to. The DISPLAY label is [en] in every
/// locale EXCEPT Polish, which uses [pl].
class Advantage {
  const Advantage(this.key, this.en, this.pl, this.points);

  final String key;
  final String en;
  final String pl;
  final int points;
}

/// Every 7th Sea 2e Advantage, in point-cost then source order. The [Advantage.key]s
/// are the enum options of the `advantages` stat field.
const List<Advantage> kAdvantages = [
  // --- 1 point ---
  Advantage('able_drunker', 'Able Drunker', 'Mocna głowa', 1),
  Advantage('cast_iron_stomach', 'Cast Iron Stomach', 'Strusi żołądek', 1),
  Advantage('direction_sense', 'Direction Sense', 'Orientacja', 1),
  Advantage('foreign_born', 'Foreign Born', 'Cudzoziemiec', 1),
  Advantage('large', 'Large', 'Duży', 1),
  Advantage('linguist', 'Linguist', 'Poliglota', 1),
  Advantage('sea_legs', 'Sea Legs', 'Marynarski krok', 1),
  Advantage('small', 'Small', 'Mały', 1),
  Advantage('survivalist', 'Survivalist', 'Sztuka przetrwania', 1),
  Advantage('time_sense', 'Time Sense', 'Wyczucie czasu', 1),
  // --- 2 points ---
  Advantage('barterer', 'Barterer', 'Targowanie', 2),
  Advantage('come_hither', 'Come hither', 'Chodźno-tu', 2),
  Advantage('connection', 'Connection', 'Znajomości', 2),
  Advantage('disarming_smile', 'Disarming smile', 'Obezwładniający uśmiech', 2),
  Advantage('eagle_eyes', 'Eagle eyes', 'Sokoli wzrok', 2),
  Advantage('extended_family', 'Extended family', 'Daleka rodzina', 2),
  Advantage('fascinate', 'Fascinate', 'Fascynacja', 2),
  Advantage('friend_at_court', 'Friend at court', 'Przyjaciel na dworze', 2),
  Advantage('got_it', 'Got it!', 'Zrobione!', 2),
  Advantage('handy', 'Handy', 'Złota rączka', 2),
  Advantage('indomitable_will', 'Indomitable will', 'Nieugiętość', 2),
  Advantage('inspire_generosity', 'Inspire generosity', 'Nie bądź Żyła', 2),
  Advantage('leadership', 'Leadership', 'Przywództwo', 2),
  Advantage(
    'married_to_the_sea',
    'Married to the sea',
    'Zaślubiony z morzem',
    2,
  ),
  Advantage('perfect_balance', 'Perfect balance', 'Doskonała równowaga', 2),
  Advantage('poison_immunity', 'Poison immunity', 'Odporność na trucizny', 2),
  Advantage('psst_over_here', 'Psst, over here', 'Psst, tutaj', 2),
  Advantage(
    'reckless_takedown',
    'Reckless takedown',
    'Zuchwałe obezwładnienie',
    2,
  ),
  Advantage('reputation', 'Reputation', 'Reputacja', 2),
  Advantage('second_story_work', 'Second story work', 'Na krzywy ryj', 2),
  Advantage('slip_free', 'Slip free', 'Houdini', 2),
  Advantage('sorcery', 'Sorcery', 'Magia', 2),
  Advantage('staredown', 'Staredown', 'Groźne spojrzenie', 2),
  Advantage('streetwise', 'Streetwise', 'Człowiek ulicy', 2),
  Advantage('team_player', 'Team player', 'Gracz drużynowy', 2),
  Advantage('valiant_spirit', 'Valiant spirit', 'Waleczność', 2),
  // --- 3 points ---
  Advantage(
    'an_honest_misunderstanding',
    'An honest misunderstanding',
    'Niezamierzona pomyłka',
    3,
  ),
  Advantage('bar_fighter', 'Bar fighter', 'Zabijaka', 3),
  Advantage('boxer', 'Boxer', 'Bokser', 3),
  Advantage('bruiser', 'Bruiser', 'Silnoręki', 3),
  Advantage('brush_pass', 'Brush pass', 'Lepkie rączki', 3),
  Advantage('camaraderie', 'Camaraderie', 'Braterstwo', 3),
  Advantage('dead_eye', 'Dead eye', 'Pewna ręka', 3),
  Advantage('dynamic_approach', 'Dynamic approach', 'Zmiana planów', 3),
  Advantage('fencer', 'Fencer', 'Szermierz', 3),
  Advantage('foul_weather_jack', 'Foul weather jack', 'Morskie opowieści', 3),
  Advantage(
    'masterpiece_crafter',
    'Masterpiece crafter',
    'Mistrz rzemiosła',
    3,
  ),
  Advantage('opportunist', 'Opportunist', 'Oportunista', 3),
  Advantage('ordained', 'Ordained', 'Wyświęcony', 3),
  Advantage('patron', 'Patron', 'Patron', 3),
  Advantage('quick_reflexes', 'Quick reflexes', 'Szybki refleks', 3),
  Advantage('rich', 'Rich', 'Majątek', 3),
  Advantage('signature_item', 'Signature item', 'Unikalny przedmiot', 3),
  Advantage('sniper', 'Sniper', 'Sniper', 3),
  Advantage('tenure', 'Tenure', 'Posada', 3),
  Advantage('virtuoso', 'Virtuoso', 'Wirtuoz', 3),
  // --- 4 points ---
  Advantage('academy', 'Academy', 'Akademia wojskowa', 4),
  Advantage('alchemist', 'Alchemist', 'Alchemik', 4),
  Advantage('hard_to_kill', 'Hard to kill', 'Twardziel', 4),
  Advantage('legendary_trait', 'Legendary Trait', 'Legendarna umiejętność', 4),
  Advantage('lyceum', 'Lyceum', 'Ogłada', 4),
  Advantage('miracle_worker', 'Miracle worker', 'Cudotwórca', 4),
  Advantage('riot_breaker', 'Riot breaker', 'Szturmowiec', 4),
  Advantage('seidr', 'Seidr', 'Seidr', 4),
  Advantage('specialist', 'Specialist', 'Specjalista', 4),
  Advantage('trusted_companion', 'Trusted companion', 'Zaufany człowiek', 4),
  Advantage('university', 'University', 'Uniwersytet', 4),
  // --- 5 points ---
  Advantage('duelist_academy', 'Duelist academy', 'Szkoła szermiercza', 5),
  Advantage('i_wont_die_here', "I won't die here", 'Nie dziś', 5),
  Advantage(
    'im_taking_you_with_me',
    "I'm taking you with me",
    'Zginiesz ze mną',
    5,
  ),
  Advantage('joie_de_vivre', 'Joie de vivre', 'Joie de vivre', 5),
  Advantage('spark_of_genius', 'Spark of genius', 'Przebłysk geniuszu', 5),
  Advantage('strength_of_ten', 'Strength of ten', 'Kawał chłopa', 5),
  Advantage(
    'the_devils_own_luck',
    "The devil's own luck",
    'Cholerne szczęście',
    5,
  ),
  Advantage(
    'together_we_are_strong',
    'Together we are strong',
    'W jedności siła',
    5,
  ),
  Advantage(
    'were_not_so_different',
    "We're not so different",
    'Jesteśmy tacy sami...',
    5,
  ),
];

/// Fast key -> [Advantage] lookup.
final Map<String, Advantage> kAdvantageByKey = {
  for (final a in kAdvantages) a.key: a,
};
