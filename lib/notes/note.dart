import '../visibility/visibility_rules.dart';

/// One note: a stable [uuid], a [name], free-text
/// [content], and a GM-only [visibility] gate.
///
/// Any other schema keys (the runtime `seen` flag, `immutable`, …) are preserved
/// verbatim through [extra] so a round-trip never drops save-only data.
class Note {
  Note({
    required this.uuid,
    this.name = '',
    this.content = '',
    this.visibility = const VisibilityRules(),
    this.immutable = false,
    Map<String, dynamic> extra = const {},
  }) : extra = Map<String, dynamic>.from(extra);

  final String uuid;
  String name;
  String content;
  VisibilityRules visibility;

  /// Runtime save-only flag: part of the immutable base content stamped at
  /// save creation — frozen (no edit / no delete) in the save-edit editor.
  /// Absent/`false` in projects and exports; serialized only when `true`.
  bool immutable;

  /// Unrecognised keys preserved verbatim (e.g. the runtime `seen` flag).
  final Map<String, dynamic> extra;

  static const Set<String> _known = {
    'note_uuid',
    'note_name',
    'note_content',
    'visibility_rules',
    'immutable',
  };

  factory Note.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    final extra = <String, dynamic>{
      for (final e in json.entries)
        if (e.key is String && !_known.contains(e.key)) '${e.key}': e.value,
    };
    return Note(
      uuid: s(json['note_uuid']),
      name: s(json['note_name']),
      content: s(json['note_content']),
      visibility: VisibilityRules.fromJson(json['visibility_rules']),
      immutable: json['immutable'] == true,
      extra: extra,
    );
  }

  /// The object written to LivingScroll.json. `visibility_rules` is omitted when
  /// empty (an always-visible note); `immutable` is written only when true.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'note_uuid': uuid,
      'note_name': name,
      'note_content': content,
    };
    final rules = visibility.toJson();
    if (rules != null) json['visibility_rules'] = rules;
    if (immutable) json['immutable'] = true;
    json.addAll(extra);
    return json;
  }
}
