/// User overrides persisted in `{Settings}/overrides.json`.
///
/// Each field is a "stub": a `null` value means *absent* — fall back to the
/// application default. Writing a default-valued setting therefore drops its
/// stub rather than storing it (see [toJson]).
class SettingsOverrides {
  const SettingsOverrides({
    this.lang,
    this.mode,
    this.autoplay,
    this.railExtended,
  });

  /// Language override (ISO code: en/de/fr/pt/es/pl/zh/ja) or `null` (default).
  final String? lang;

  /// Display-mode override: `'light'` | `'dark'`, or `null` for `auto`
  /// (follow the system), which is the application default.
  final String? mode;

  /// Music autoplay override. The application default is ON, so only the
  /// non-default value (`false`) is ever stored as a stub; `null` (or `true`)
  /// means "absent — use the default (on)". Read it through [autoplayOn].
  final bool? autoplay;

  /// Navigation-rail (the "roller") expanded/collapsed override, persisted so
  /// the choice survives between app launches. The application default is
  /// COLLAPSED, so only the non-default value (`true`) is stored as a stub;
  /// `null` (or `false`) means "absent — collapsed". Read it through
  /// [railExtendedOn].
  final bool? railExtended;

  /// Whether scene music should autoplay — the resolved setting (default on).
  bool get autoplayOn => autoplay ?? true;

  /// Whether the navigation rail should start expanded — the resolved setting
  /// (default collapsed).
  bool get railExtendedOn => railExtended ?? false;

  factory SettingsOverrides.fromJson(Map<String, dynamic> json) =>
      SettingsOverrides(
        lang: json['lang'] as String?,
        mode: json['mode'] as String?,
        autoplay: json['autoplay'] as bool?,
        railExtended: json['railExtended'] as bool?,
      );

  /// Only non-default stubs are serialized, so a default value is omitted
  /// (autoplay is written ONLY when explicitly off; railExtended ONLY when
  /// explicitly expanded).
  Map<String, dynamic> toJson() => {
        if (lang != null) 'lang': lang,
        if (mode != null) 'mode': mode,
        if (autoplay == false) 'autoplay': false,
        if (railExtended == true) 'railExtended': true,
      };

  /// True when no stub is set — overrides.json may then be omitted entirely.
  /// Autoplay counts as set only when explicitly off; railExtended only when
  /// explicitly expanded.
  bool get isEmpty =>
      lang == null && mode == null && autoplay != false && railExtended != true;

  @override
  bool operator ==(Object other) =>
      other is SettingsOverrides &&
      other.lang == lang &&
      other.mode == mode &&
      other.autoplay == autoplay &&
      other.railExtended == railExtended;

  @override
  int get hashCode => Object.hash(lang, mode, autoplay, railExtended);
}
