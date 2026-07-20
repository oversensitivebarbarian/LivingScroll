import '../visibility/visibility_rules.dart';

/// One NPC: a stable [uuid] (`npc_uuid`), a [name] (UNIQUE — referenced BY NAME
/// in `scenes.npcs[]`), the two role images ([fullImage] / [iconImage], stored
/// at `images/npcs/<uuid>.png`), a [description], a [backstory], a runtime
/// [state] (active/inactive) and a GM-only [visibility] gate.
///
/// Basic RPG adds no stat fields (its NPC template is empty), but any
/// unrecognised keys present on disk (e.g. `gm_notes`, a future system's
/// `stats`) are preserved verbatim through [extra] so editing / cloning never
/// drops data this build does not author.
class Npc {
  Npc({
    required this.uuid,
    required this.name,
    this.fullImage,
    this.iconImage,
    this.description = '',
    this.backstory = '',
    this.state = 'active',
    this.visibility = const VisibilityRules(),
    this.immutable = false,
    Map<String, dynamic> extra = const {},
  }) : extra = Map<String, dynamic>.from(extra);

  /// `npc_uuid` — stable identifier minted on creation.
  final String uuid;

  /// The NPC's name — unique within the document's `npcs`.
  String name;

  /// Image id of the full portrait (`images/npcs/<fullImage>.png`).
  String? fullImage;

  /// Image id of the icon portrait (`images/npcs/<iconImage>.png`).
  String? iconImage;

  String description;
  String backstory;

  /// Runtime state, app-managed; new NPCs default to "active".
  String state;

  VisibilityRules visibility;

  /// Runtime save-only flag: part of the immutable base content stamped at
  /// save creation — frozen (no edit / no delete) in the save-edit editor.
  /// Absent/`false` in projects and exports; serialized only when `true`.
  bool immutable;

  /// Unrecognised keys preserved verbatim (so edits/clones don't drop data).
  final Map<String, dynamic> extra;

  static const Set<String> _known = {
    'name',
    'npc_uuid',
    'full_image',
    'icon_image',
    'description',
    'backstory',
    'state',
    'visibility_rules',
    'immutable',
  };

  factory Npc.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    String? id(Object? v) => (v is String && v.isNotEmpty) ? v : null;
    final extra = <String, dynamic>{
      for (final e in json.entries)
        if (!_known.contains(e.key)) '${e.key}': e.value,
    };
    return Npc(
      uuid: s(json['npc_uuid']),
      name: s(json['name']),
      fullImage: id(json['full_image']),
      iconImage: id(json['icon_image']),
      description: s(json['description']),
      backstory: s(json['backstory']),
      state: s(json['state']).isEmpty ? 'active' : s(json['state']),
      visibility: VisibilityRules.fromJson(json['visibility_rules']),
      immutable: json['immutable'] == true,
      extra: extra,
    );
  }

  /// The object written to LivingScroll.json's `npcs[]`.
  Map<String, dynamic> toJson() => {
    'name': name,
    'npc_uuid': uuid,
    'full_image': ?fullImage,
    'icon_image': ?iconImage,
    'description': description,
    'backstory': backstory,
    'state': state,
    'visibility_rules': ?visibility.toJson(),
    if (immutable) 'immutable': true,
    ...extra,
  };
}
