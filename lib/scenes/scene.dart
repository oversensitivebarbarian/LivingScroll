import '../visibility/visibility_rules.dart';

/// One scene. The authored fields (name, narration/
/// description, the reference lists, paths and the visibility gate) are modelled
/// explicitly; every other schema field the form does not edit yet (scene_type,
/// season_tag, episode_tag, next_scenes, state, …) is preserved verbatim in
/// [extra] so a round-trip never drops data.
///
/// Reference lists store the value each collection is keyed by:
///   - [npcNames], [keyEventNames], [pathNames] reference BY NAME
///     (npcs.name / key_events.name / paths.name);
///   - [noteUuids], [imageUuids], [audioUuids], [nextSceneUuids] reference BY UUID
///     (notes.note_uuid / images.image_uuid / audio.audio_uuid /
///     scenes.scene_uuid — so renaming a target scene never breaks a next link).
/// All are stored as flat string lists, matching the existing cascade strippers
/// in ProjectsStore (which match a plain string entry `e == name`).
class Scene {
  Scene({
    required this.uuid,
    this.name = '',
    this.description = '',
    this.sceneType = defaultSceneType,
    this.bgImage = '',
    List<String>? npcNames,
    List<String>? keyEventNames,
    List<String>? noteUuids,
    List<String>? imageUuids,
    List<String>? audioUuids,
    List<String>? pathNames,
    List<String>? nextSceneUuids,
    this.visibility = const VisibilityRules(),
    this.immutable = false,
    Map<String, dynamic>? extra,
  }) : npcNames = npcNames ?? [],
       keyEventNames = keyEventNames ?? [],
       noteUuids = noteUuids ?? [],
       imageUuids = imageUuids ?? [],
       audioUuids = audioUuids ?? [],
       pathNames = pathNames ?? [],
       nextSceneUuids = nextSceneUuids ?? [],
       extra = extra ?? {};

  final String uuid;
  String name;
  String description;

  /// One of [sceneTypes] (start/standard/recurring/end). The new_scene "Typ
  /// sceny" radio writes it; defaults to [defaultSceneType].
  String sceneType;

  /// The scene's background image (`scenes.bg_image`): a single image_uuid (an
  /// `images[].image_uuid`, file at `images/other/<bg_image>.png`) shown as the
  /// full-window background in the game preview and play view. Empty => a flat
  /// surface colour. (Replaced the removed `location_name`.)
  String bgImage;

  /// The allowed scene_type values, in radio order.
  static const sceneTypes = ['start', 'standard', 'recurring', 'end'];
  static const defaultSceneType = 'standard';
  List<String> npcNames;
  List<String> keyEventNames;
  List<String> noteUuids;
  List<String> imageUuids;
  List<String> audioUuids;
  List<String> pathNames;

  /// Other scenes that may follow this one (scenes.next_scenes[] ->
  /// scenes.scene_uuid). Stored by uuid so renaming a target scene never breaks
  /// the link; resolved to the target's name only for display.
  List<String> nextSceneUuids;
  VisibilityRules visibility;

  /// Runtime save-only flag: the scene is part of the immutable base content
  /// stamped when the save was created — frozen in the save-edit editor (only
  /// `next_scenes` remains editable). Absent/`false` in projects and exports.
  /// Serialized only when `true`.
  bool immutable;

  /// Schema fields not edited by the form, preserved verbatim across a save.
  final Map<String, dynamic> extra;

  /// The schema keys this model owns; everything else in a decoded object is
  /// captured in [extra] and written back untouched.
  static const _ownedKeys = {
    'scene_uuid',
    'name',
    'description',
    'scene_type',
    'bg_image',
    'npcs',
    'key_events',
    'notes',
    'images',
    'audio',
    'path_names',
    'next_scenes',
    'visibility_rules',
    'immutable',
  };

  factory Scene.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    List<String> strings(Object? v) {
      if (v is! List) return [];
      return [
        for (final e in v)
          if (e is String)
            e
          else if (e is Map && e['name'] is String)
            e['name']
                as String // tolerate the {name: ...} reference form
          else if (e is Map && e['note_uuid'] is String)
            e['note_uuid'] as String,
      ];
    }

    final extra = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = entry.key;
      if (key is String && !_ownedKeys.contains(key)) {
        extra[key] = entry.value;
      }
    }

    final rawType = s(json['scene_type']);
    return Scene(
      uuid: s(json['scene_uuid']),
      name: s(json['name']),
      description: s(json['description']),
      sceneType: sceneTypes.contains(rawType) ? rawType : defaultSceneType,
      bgImage: s(json['bg_image']),
      npcNames: strings(json['npcs']),
      keyEventNames: strings(json['key_events']),
      noteUuids: strings(json['notes']),
      imageUuids: strings(json['images']),
      audioUuids: strings(json['audio']),
      pathNames: strings(json['path_names']),
      nextSceneUuids: strings(json['next_scenes']),
      visibility: VisibilityRules.fromJson(json['visibility_rules']),
      immutable: json['immutable'] == true,
      extra: extra,
    );
  }

  /// The object written to LivingScroll.json. Owned fields first, then the
  /// preserved [extra] fields; `visibility_rules` is omitted when empty.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'scene_uuid': uuid,
      'name': name,
      'description': description,
      'scene_type': sceneType,
      'bg_image': bgImage,
      'npcs': npcNames,
      'key_events': keyEventNames,
      'notes': noteUuids,
      'images': imageUuids,
      'audio': audioUuids,
      'path_names': pathNames,
      'next_scenes': nextSceneUuids,
    };
    final rules = visibility.toJson();
    if (rules != null) json['visibility_rules'] = rules;
    if (immutable) json['immutable'] = true;
    json.addAll(extra);
    return json;
  }

  Scene copy() => Scene(
    uuid: uuid,
    name: name,
    description: description,
    sceneType: sceneType,
    bgImage: bgImage,
    npcNames: [...npcNames],
    keyEventNames: [...keyEventNames],
    noteUuids: [...noteUuids],
    imageUuids: [...imageUuids],
    audioUuids: [...audioUuids],
    pathNames: [...pathNames],
    nextSceneUuids: [...nextSceneUuids],
    visibility: visibility,
    immutable: immutable,
    extra: Map<String, dynamic>.from(extra),
  );
}
