/// The system-bound NPC stat template model.
///
/// A template is an ordered list of [StatPage]s (the multi-page creation form).
/// Each page holds [StatGroup]s, each group an ordered list of [StatField]s. A
/// system with no stats (Basic RPG) uses an empty template ([StatTemplate.empty]).
///
/// Per-NPC values live in `npcs[].stats`, keyed by [StatField.key]. Values are
/// plain JSON (see [StatType]); a [StatType.list] field stores a JSON array of
/// objects validated against its [StatField.item] sub-template. Derived fields
/// ([StatField.isDerived]) are computed from other values and NEVER stored.
library;

/// JSON-storable kinds a [StatField] can hold.
enum StatType {
  /// JSON integer, optional [StatField.min]/[StatField.max].
  intField,

  /// JSON string (free text).
  text,

  /// JSON boolean.
  boolField,

  /// JSON string, member of [StatField.options].
  enumField,

  /// JSON array of strings, each a member of [StatField.options].
  enumMulti,

  /// JSON array of objects, each validated against [StatField.item].
  list,
}

/// Conditional visibility: a field is shown only when the value at [key] equals
/// [equals] (or, with [ShowWhen.oneOf], is one of [oneOfValues]). A hidden field
/// is neither asked nor required nor written.
class ShowWhen {
  const ShowWhen(this.key, this.equals) : oneOfValues = null;

  /// Visible when `stats[key]` is one of [values].
  const ShowWhen.oneOf(this.key, List<Object> values)
    : oneOfValues = values,
      equals = null;

  final String key;
  final Object? equals;
  final List<Object>? oneOfValues;

  bool matches(Map<String, dynamic> stats) {
    final v = stats[key];
    final set = oneOfValues;
    return set != null ? set.contains(v) : v == equals;
  }
}

/// Resolves the live options of a field whose [StatField.optionsFrom] is set,
/// given the surrounding stats (e.g. races available for the chosen creature
/// type). An empty result auto-hides the field.
typedef OptionsResolver =
    List<String> Function(StatField field, Map<String, dynamic> stats);

/// One leaf (or `list`) field in a template.
class StatField {
  const StatField({
    required this.key,
    required this.labelKey,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
    this.options = const [],
    this.item = const [],
    this.required = false,
    this.derived,
    this.optionsFrom,
    this.showWhen,
  });

  /// Stable machine key (snake_case), unique within the template; the key under
  /// which the value is stored in `npcs[].stats`.
  final String key;

  /// Localization key for the human label (resolved via AppLocalizations).
  final String labelKey;

  final StatType type;

  /// Default on create. When null, falls back to a type default (see [defaults]).
  final Object? defaultValue;

  /// Inclusive int bounds (int only). Null => unbounded.
  final int? min;
  final int? max;

  /// Allowed values for [StatType.enumField] / [StatType.enumMulti].
  final List<String> options;

  /// Sub-template for one entry of a [StatType.list] field.
  final List<StatField> item;

  /// When true, the authoring form must hold a non-empty value before save.
  final bool required;

  /// When set, the value is computed from other fields by the system's
  /// derivation registry under this id, is read-only, and is never persisted.
  final String? derived;

  /// When set, the field's enum options are RESOLVED live from other fields
  /// (e.g. `race` options depend on `creature_type`) via an [OptionsResolver];
  /// [options] then holds only a static fallback. A field whose live options are
  /// empty is auto-hidden.
  final String? optionsFrom;

  /// Conditional visibility gate.
  final ShowWhen? showWhen;

  bool get isDerived => derived != null;

  /// The seed value for a fresh NPC (used by [StatTemplate.defaults]).
  Object? get seed {
    if (defaultValue != null) return defaultValue;
    switch (type) {
      case StatType.intField:
        return min ?? 0;
      case StatType.text:
        return '';
      case StatType.boolField:
        return false;
      case StatType.enumField:
        return options.isNotEmpty ? options.first : '';
      case StatType.enumMulti:
        return <String>[];
      case StatType.list:
        return <Map<String, dynamic>>[];
    }
  }
}

/// A labelled cluster of fields within a page (pure layout).
class StatGroup {
  const StatGroup({required this.labelKey, required this.fields});

  final String labelKey;
  final List<StatField> fields;
}

/// One step of the multi-page creation form.
class StatPage {
  const StatPage({
    required this.key,
    required this.titleKey,
    required this.groups,
  });

  final String key;
  final String titleKey;
  final List<StatGroup> groups;

  Iterable<StatField> get fields sync* {
    for (final g in groups) {
      yield* g.fields;
    }
  }
}

/// A whole system's NPC stat template.
class StatTemplate {
  const StatTemplate(this.pages);

  /// The empty template (Basic RPG): no stats, no pages.
  static const StatTemplate empty = StatTemplate([]);

  final List<StatPage> pages;

  bool get isEmpty => pages.isEmpty;

  /// Every field, in page/group/field order.
  Iterable<StatField> get fields sync* {
    for (final p in pages) {
      yield* p.fields;
    }
  }

  StatField? fieldFor(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// A fresh stats map: every non-derived leaf seeded with its default. Derived
  /// fields are never seeded (they are recomputed on read).
  Map<String, dynamic> defaults() {
    final out = <String, dynamic>{};
    for (final f in fields) {
      if (f.isDerived) continue;
      out[f.key] = f.seed;
    }
    return out;
  }
}

/// Whether a field is currently visible given the surrounding [stats]: honours
/// [StatField.showWhen] and auto-hides a [StatField.optionsFrom] field whose live
/// options ([resolveOptions]) are empty.
bool isFieldVisible(
  StatField field,
  Map<String, dynamic> stats, {
  OptionsResolver? resolveOptions,
}) {
  final cond = field.showWhen;
  if (cond != null && !cond.matches(stats)) return false;
  if (field.optionsFrom != null && resolveOptions != null) {
    if (resolveOptions(field, stats).isEmpty) return false;
  }
  return true;
}

/// The effective options of a field: live ([StatField.optionsFrom]) when a
/// resolver is given, else the static [StatField.options].
List<String> effectiveOptions(
  StatField field,
  Map<String, dynamic> stats, {
  OptionsResolver? resolveOptions,
}) {
  if (field.optionsFrom != null && resolveOptions != null) {
    return resolveOptions(field, stats);
  }
  return field.options;
}

/// System-layer validation of a `stats` map against [template]. Returns a list
/// of human-oriented error strings keyed by field; empty list == valid.
/// Derived and currently hidden ([ShowWhen]) fields are skipped.
List<String> validateStats(
  StatTemplate template,
  Map<String, dynamic> stats, {
  OptionsResolver? resolveOptions,
}) {
  final errors = <String>[];

  void check(StatField f, dynamic value, String path) {
    final opts = effectiveOptions(f, stats, resolveOptions: resolveOptions);
    switch (f.type) {
      case StatType.intField:
        if (value is! int) {
          errors.add('$path: expected int');
          return;
        }
        if (f.min != null && value < f.min!) {
          errors.add('$path: below min ${f.min}');
        }
        if (f.max != null && value > f.max!) {
          errors.add('$path: above max ${f.max}');
        }
      case StatType.text:
        if (value is! String) errors.add('$path: expected text');
        if (f.required && (value is! String || value.trim().isEmpty)) {
          errors.add('$path: required');
        }
      case StatType.boolField:
        if (value is! bool) errors.add('$path: expected bool');
      case StatType.enumField:
        if (value is! String) {
          errors.add('$path: expected text');
        } else if (value.isEmpty) {
          if (f.required) errors.add('$path: required');
        } else if (!opts.contains(value)) {
          errors.add('$path: "$value" not in options');
        }
      case StatType.enumMulti:
        if (value is! List) {
          errors.add('$path: expected list');
          return;
        }
        for (final v in value) {
          if (v is! String || !opts.contains(v)) {
            errors.add('$path: "$v" not in options');
          }
        }
      case StatType.list:
        if (value is! List) {
          errors.add('$path: expected list');
          return;
        }
        for (var i = 0; i < value.length; i++) {
          final entry = value[i];
          if (entry is! Map) {
            errors.add('$path[$i]: expected object');
            continue;
          }
          final asMap = Map<String, dynamic>.from(entry);
          for (final sub in f.item) {
            if (!isFieldVisible(sub, asMap)) continue;
            if (!asMap.containsKey(sub.key)) {
              if (sub.required || !sub.isDerived) {
                // missing -> use seed for type check, flag required text/list
                if (sub.required) errors.add('$path[$i].${sub.key}: required');
                continue;
              }
            }
            if (sub.isDerived) continue;
            check(sub, asMap[sub.key] ?? sub.seed, '$path[$i].${sub.key}');
          }
        }
    }
  }

  for (final f in template.fields) {
    if (f.isDerived) continue;
    if (!isFieldVisible(f, stats, resolveOptions: resolveOptions)) continue;
    if (!stats.containsKey(f.key)) {
      if (f.required) errors.add('${f.key}: required');
      continue;
    }
    check(f, stats[f.key], f.key);
  }

  return errors;
}
