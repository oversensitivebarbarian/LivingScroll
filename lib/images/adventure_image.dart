import '../visibility/visibility_rules.dart';

/// One image in the adventure's general image pool: a stable [uuid]
/// (`image_uuid`), an optional [name], and a GM-only
/// [visibility] gate (`visibility_rules`). The file lives at
/// `images/other/<uuid>.png`.
///
/// Any other schema keys (the runtime `seen` flag, `immutable`, …) are preserved
/// verbatim through [extra] so a round-trip never drops save-only data.
class AdventureImage {
  AdventureImage({
    required this.uuid,
    this.name = '',
    this.visibility = const VisibilityRules(),
    this.immutable = false,
    Map<String, dynamic> extra = const {},
  }) : extra = Map<String, dynamic>.from(extra);

  /// `image_uuid` — stable identifier; also names the file under `images/other/`.
  final String uuid;

  /// Display name (derived from the picked file name; not required to be unique).
  String name;

  /// GM-only visibility gate (empty == always visible).
  VisibilityRules visibility;

  /// Runtime save-only flag: part of the immutable base content stamped at
  /// save creation — frozen (no edit / no delete) in the save-edit editor.
  /// Absent/`false` in projects and exports; serialized only when `true`.
  bool immutable;

  /// Unrecognised keys preserved verbatim (e.g. the runtime `seen` flag).
  final Map<String, dynamic> extra;

  static const Set<String> _known = {
    'image_uuid',
    'name',
    'visibility_rules',
    'immutable',
  };

  factory AdventureImage.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    final extra = <String, dynamic>{
      for (final e in json.entries)
        if (e.key is String && !_known.contains(e.key)) '${e.key}': e.value,
    };
    return AdventureImage(
      uuid: s(json['image_uuid']),
      name: s(json['name']),
      visibility: VisibilityRules.fromJson(json['visibility_rules']),
      immutable: json['immutable'] == true,
      extra: extra,
    );
  }

  /// The object written to LivingScroll.json's `images[]` (empty visibility_rules
  /// is omitted; `immutable` is written only when true).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'image_uuid': uuid, 'name': name};
    final rules = visibility.toJson();
    if (rules != null) json['visibility_rules'] = rules;
    if (immutable) json['immutable'] = true;
    json.addAll(extra);
    return json;
  }
}
