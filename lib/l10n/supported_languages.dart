/// The languages LivingScroll supports, as ISO code -> endonym (each language
/// shown in its OWN name, the convention for language pickers). Single source of
/// truth (like `GameSystems`) reused by:
///   * the Settings UI-language dropdown (`settings.language`), and
///   * the adventure CONTENT-language dropdown on the new-adventure and Adventure
///     settings forms (`create_new.field.language` / `game.settings.field.language`),
///     where the chosen code is stored in `metadata.language`.
class SupportedLanguages {
  const SupportedLanguages._();

  /// ISO code -> endonym, in the app's canonical language order.
  static const Map<String, String> names = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'pt': 'Português',
    'es': 'Español',
    'pl': 'Polski',
    'zh': '中文',
    'ja': '日本語',
  };

  /// English exonyms accepted when normalizing a legacy free-text value written
  /// before `metadata.language` became a controlled vocabulary.
  static const Map<String, String> _exonyms = {
    'english': 'en',
    'german': 'de',
    'french': 'fr',
    'portuguese': 'pt',
    'spanish': 'es',
    'polish': 'pl',
    'chinese': 'zh',
    'japanese': 'ja',
  };

  /// Whether [code] is one of the supported ISO codes.
  static bool isKnown(String code) => names.containsKey(code);

  /// Maps a stored `metadata.language` value — an ISO code, an endonym, or an
  /// English exonym (legacy free text) — to a supported ISO code, or `null` when
  /// it matches none (an unrecognized value the dropdown preserves verbatim).
  static String? codeFor(String stored) {
    final s = stored.trim();
    if (s.isEmpty) return null;
    if (names.containsKey(s)) return s;
    final lower = s.toLowerCase();
    for (final entry in names.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    return _exonyms[lower];
  }
}
