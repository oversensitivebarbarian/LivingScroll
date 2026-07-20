import 'package:flutter/foundation.dart';

import '../util/uuid.dart';
import '../visibility/visibility_rules.dart';
import 'scene.dart';

/// One available adventure path offered by the scene editor's Paths multi-select
/// and resolved by the scene tile's colour discs: its stable colour [colorId]
/// (yellow/green/red/blue/violet/orange) paired with its authored [name].
typedef ScenePathRef = ({String colorId, String name});

/// In-memory state for the Scenes section: the list of scenes, the adventure's
/// available paths (for the Paths multi-select + the tile colour discs) and
/// key_events (for the visibility editor), plus the currently edited scene.
///
/// The game shell owns it so its navigation guard can consult [isDirty] when the
/// user leaves the section mid-edit, and persists [toJson] to LivingScroll.json.
class ScenesController extends ChangeNotifier {
  ScenesController({String Function()? newId}) : _newId = newId ?? uuidV4;

  final String Function() _newId;

  final List<Scene> _scenes = [];
  List<ScenePathRef> _paths = const [];
  List<KeyEventRef> _keyEvents = const [];

  List<Scene> get scenes => List.unmodifiable(_scenes);

  /// The adventure's paths (colourId + name) in declared order, for the Paths
  /// multi-select and for resolving a scene's path_names to colour discs.
  List<ScenePathRef> get paths => _paths;

  /// The adventure's key_events (uuid + name), for the visibility editor.
  List<KeyEventRef> get keyEvents => _keyEvents;

  /// Replaces the available paths (colourId + name) without touching scenes or
  /// the open edit. The shell calls this on load and after the Paths section
  /// changes so the editor and tiles see up-to-date paths.
  void setPaths(List<ScenePathRef> paths) {
    _paths = List.unmodifiable(paths);
    notifyListeners();
  }

  /// Replaces the available key_events shown by the visibility editor.
  void setKeyEvents(List<KeyEventRef> events) {
    _keyEvents = List.unmodifiable(events);
    notifyListeners();
  }

  /// Loads scenes, paths and key_events from a decoded LivingScroll.json.
  void loadFrom(Map<String, dynamic> document) {
    _scenes.clear();
    final list = document['scenes'];
    if (list is List) {
      for (final s in list) {
        if (s is Map) _scenes.add(Scene.fromJson(s));
      }
    }
    _paths = _parsePaths(document);
    _keyEvents = _parseKeyEvents(document);
    _editing = null;
    notifyListeners();
  }

  static List<ScenePathRef> _parsePaths(Map document) {
    final out = <ScenePathRef>[];
    final paths = document['paths'];
    if (paths is List) {
      for (final p in paths) {
        if (p is Map && p['color'] is String && p['name'] is String) {
          final name = p['name'] as String;
          if (name.trim().isNotEmpty) {
            out.add((colorId: p['color'] as String, name: name));
          }
        }
      }
    }
    return List.unmodifiable(out);
  }

  static List<KeyEventRef> _parseKeyEvents(Map document) {
    final out = <KeyEventRef>[];
    final ke = document['key_events'];
    if (ke is List) {
      for (final e in ke) {
        if (e is Map && e['name'] is String) {
          out.add((
            uuid: e['key_event_uuid'] is String
                ? e['key_event_uuid'] as String
                : '',
            name: e['name'] as String,
          ));
        }
      }
    }
    return List.unmodifiable(out);
  }

  // --- edit state ---------------------------------------------------------

  _Edit? _editing;

  bool get isEditing => _editing != null;
  bool get isNew => _editing?.isNew ?? false;
  String? get editingUuid => _editing?.working.uuid;

  /// The working copy of the scene under edit (null when the list is shown).
  Scene? get editing => _editing?.working;

  String get editName => _editing?.working.name ?? '';
  String get editDescription => _editing?.working.description ?? '';
  String get editSceneType =>
      _editing?.working.sceneType ?? Scene.defaultSceneType;
  String get editBgImage => _editing?.working.bgImage ?? '';
  List<String> get editPathNames => _editing?.working.pathNames ?? const [];
  List<String> get editNpcNames => _editing?.working.npcNames ?? const [];
  List<String> get editKeyEventNames =>
      _editing?.working.keyEventNames ?? const [];
  List<String> get editNoteUuids => _editing?.working.noteUuids ?? const [];
  List<String> get editImageUuids => _editing?.working.imageUuids ?? const [];
  List<String> get editAudioUuids => _editing?.working.audioUuids ?? const [];
  List<String> get editNextSceneUuids =>
      _editing?.working.nextSceneUuids ?? const [];
  VisibilityRules get editVisibility =>
      _editing?.working.visibility ?? const VisibilityRules();

  set editName(String value) => _mutate((s) => s.name = value);
  set editDescription(String value) => _mutate((s) => s.description = value);
  set editSceneType(String value) => _mutate((s) => s.sceneType = value);
  set editBgImage(String value) => _mutate((s) => s.bgImage = value);
  set editVisibility(VisibilityRules value) =>
      _mutate((s) => s.visibility = value);
  set editNpcNames(List<String> v) => _mutate((s) => s.npcNames = [...v]);
  set editKeyEventNames(List<String> v) =>
      _mutate((s) => s.keyEventNames = [...v]);
  set editNoteUuids(List<String> v) => _mutate((s) => s.noteUuids = [...v]);
  set editImageUuids(List<String> v) => _mutate((s) => s.imageUuids = [...v]);
  set editAudioUuids(List<String> v) => _mutate((s) => s.audioUuids = [...v]);
  set editNextSceneUuids(List<String> v) =>
      _mutate((s) => s.nextSceneUuids = [...v]);

  /// Adds [name] to the edited scene's path_names when absent, removes it when
  /// present (the Paths multi-select toggle).
  void togglePath(String name) {
    _mutate((s) {
      if (!s.pathNames.remove(name)) s.pathNames.add(name);
    });
  }

  void _mutate(void Function(Scene) change) {
    final e = _editing;
    if (e == null) return;
    change(e.working);
    notifyListeners();
  }

  /// Opens the editor for a brand-new scene.
  void beginNew() {
    _editing = _Edit.fresh();
    notifyListeners();
  }

  /// Opens the editor for the existing scene [uuid].
  void beginEdit(String uuid) {
    final scene = _scenes.firstWhere((s) => s.uuid == uuid);
    _editing = _Edit.from(scene);
    notifyListeners();
  }

  /// Closes the editor without saving (Cancel / Abandon).
  void cancelEdit() {
    _editing = null;
    notifyListeners();
  }

  /// Dirty while the working copy diverges from the edited scene's baseline.
  bool get isDirty {
    final e = _editing;
    if (e == null) return false;
    return !_sameScene(e.working, e.baseline);
  }

  /// A scene needs a name to be saved.
  bool get canSave => editName.trim().isNotEmpty;

  /// True when no other scene already uses [name] (trimmed). The edited scene is
  /// excluded so renaming a scene to its own name still passes.
  bool isNameUnique(String name) {
    final trimmed = name.trim();
    final currentUuid = _editing?.working.uuid;
    return !_scenes.any((s) => s.name == trimmed && s.uuid != currentUuid);
  }

  /// Commits the working copy (adds a new scene or updates the edited one) and
  /// closes the editor. Returns false without saving when the name is empty or
  /// duplicates another scene's name — uniqueness is enforced here so every save
  /// path (the editor's Save and the rail guard's Save) is held to it.
  bool save() {
    final e = _editing;
    if (e == null || !canSave) return false;
    if (!isNameUnique(e.working.name)) return false;
    e.working.name = e.working.name.trim();
    if (e.isNew) {
      _scenes.add(e.working.nameToUuidIfNeeded(_newId));
    } else {
      final i = _scenes.indexWhere((s) => s.uuid == e.working.uuid);
      if (i >= 0) _scenes[i] = e.working;
    }
    _editing = null;
    notifyListeners();
    return true;
  }

  /// Removes the scene [uuid] (and closes the editor if it was the one open).
  /// Cascade-strips every reference to its scene_uuid from other scenes'
  /// next_scenes[] (a deleted scene can no longer be a next scene).
  void delete(String uuid) {
    _scenes.removeWhere((s) => s.uuid == uuid);
    for (final s in _scenes) {
      s.nextSceneUuids.removeWhere((u) => u == uuid);
    }
    if (_editing?.working.uuid == uuid) _editing = null;
    notifyListeners();
  }

  /// Moves the scene at [oldIndex] to [newIndex] in the `scenes[]` list order
  /// (drag-to-reorder in the Scenes section). [newIndex] is the target index
  /// AFTER the item at [oldIndex] is removed — i.e. the value the
  /// `ReorderableListView.onReorderItem` callback already provides (for the
  /// legacy `onReorder` apply `if (newIndex > oldIndex) newIndex--` first). Only
  /// the list ORDER changes — no content, no `next_scenes` links — so it is
  /// allowed even in save-edit.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _scenes.length) return;
    final scene = _scenes.removeAt(oldIndex);
    _scenes.insert(newIndex.clamp(0, _scenes.length), scene);
    notifyListeners();
  }

  /// The `scenes` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final s in _scenes) s.toJson()];

  static bool _sameScene(Scene a, Scene b) =>
      a.name == b.name &&
      a.description == b.description &&
      a.sceneType == b.sceneType &&
      a.bgImage == b.bgImage &&
      listEquals(a.npcNames, b.npcNames) &&
      listEquals(a.keyEventNames, b.keyEventNames) &&
      listEquals(a.noteUuids, b.noteUuids) &&
      listEquals(a.imageUuids, b.imageUuids) &&
      listEquals(a.audioUuids, b.audioUuids) &&
      listEquals(a.pathNames, b.pathNames) &&
      listEquals(a.nextSceneUuids, b.nextSceneUuids) &&
      a.visibility == b.visibility;
}

extension on Scene {
  /// A freshly-saved new scene mints a uuid when it has none.
  Scene nameToUuidIfNeeded(String Function() newId) {
    if (uuid.isEmpty) {
      return Scene(
        uuid: newId(),
        name: name,
        description: description,
        sceneType: sceneType,
        bgImage: bgImage,
        npcNames: npcNames,
        keyEventNames: keyEventNames,
        noteUuids: noteUuids,
        imageUuids: imageUuids,
        audioUuids: audioUuids,
        pathNames: pathNames,
        nextSceneUuids: nextSceneUuids,
        visibility: visibility,
        extra: extra,
      );
    }
    return this;
  }
}

/// The working copy of the edited scene plus its baseline for dirty tracking.
class _Edit {
  _Edit({required this.working, required this.baseline})
    : isNew = working.uuid.isEmpty;

  factory _Edit.fresh() {
    final s = Scene(uuid: '');
    return _Edit(working: s, baseline: s.copy());
  }

  factory _Edit.from(Scene s) => _Edit(working: s.copy(), baseline: s.copy());

  final Scene working;
  final Scene baseline;
  final bool isNew;
}
