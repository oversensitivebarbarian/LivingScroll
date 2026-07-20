import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../create/cover_crop.dart';
import '../util/uuid.dart';
import '../visibility/visibility_rules.dart';
import 'npc.dart';
import 'stat_template.dart';

/// In-memory state for the NPC section: the list of NPCs, the adventure's
/// key_events (for the visibility editor), and the currently edited NPC.
///
/// The game shell owns it so its navigation guard can consult [isDirty] when the
/// user leaves the section mid-edit, and persists [toJson] to LivingScroll.json.
/// Mirrors `NotesController`: an NPC's [Npc.name] must be unique within the
/// document (it is referenced by name in scenes), so [save] enforces it.
///
/// Images flow through staging: picking a full image runs two crops (full, then
/// icon cropped FROM the full); the cropped full is staged as a temp PNG
/// ([editFullStagedPath]) and the icon as a crop region over it ([editIconCrop]).
/// The game shell writes both to disk on save and records their ids via
/// [setEditImageUuids]. Clone and (cascade) delete are performed on disk by the
/// store and reflected here by a reload, so this controller has no clone/delete.
class NpcsController extends ChangeNotifier {
  NpcsController({String Function()? newId}) : _newId = newId ?? uuidV4;

  final String Function() _newId;

  final List<Npc> _npcs = [];
  List<KeyEventRef> _keyEvents = const [];

  /// The bound system's NPC stat template. Set by the game shell once the
  /// adventure's `metadata.system` is known; Basic RPG keeps the empty default
  /// so its editor shows no stat pages.
  StatTemplate _template = StatTemplate.empty;

  StatTemplate get template => _template;

  /// The bound `metadata.system` id (null until [setTemplate] records it). Drives
  /// which system-specific NPC editor the section shows.
  String? _systemId;
  String? get systemId => _systemId;

  /// When true, saving persists only the stats APPLICABLE to the current state
  /// (fields hidden by `showWhen` are pruned) — see [SystemDef.pruneHiddenStats].
  bool _pruneHiddenStats = false;

  /// Binds the system stat template (driven by `metadata.system`), optionally
  /// recording the [systemId] (for editor dispatch) and whether hidden stats are
  /// pruned on save ([pruneHiddenStats]).
  void setTemplate(
    StatTemplate template, {
    String? systemId,
    bool pruneHiddenStats = false,
  }) {
    _template = template;
    _systemId = systemId;
    _pruneHiddenStats = pruneHiddenStats;
  }

  List<Npc> get npcs => List.unmodifiable(_npcs);

  /// The adventure's key_events (uuid + name), for the visibility editor.
  List<KeyEventRef> get keyEvents => _keyEvents;

  /// Replaces the available key_events shown by the visibility editor.
  void setKeyEvents(List<KeyEventRef> events) {
    _keyEvents = List.unmodifiable(events);
    notifyListeners();
  }

  /// Loads NPCs and key_events from a decoded LivingScroll.json.
  void loadFrom(Map<String, dynamic> document) {
    _npcs.clear();
    final list = document['npcs'];
    if (list is List) {
      for (final n in list) {
        if (n is Map) _npcs.add(Npc.fromJson(n));
      }
    }
    _keyEvents = _parseKeyEvents(document);
    _editing = null;
    notifyListeners();
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
  String? get editingUuid => _editing?.uuid;

  String get editName => _editing?.name ?? '';
  String get editDescription => _editing?.description ?? '';
  String get editBackstory => _editing?.backstory ?? '';
  VisibilityRules get editVisibility =>
      _editing?.visibility ?? const VisibilityRules();

  /// Id of the NPC's already-saved full / icon image (if any).
  String? get editFullImageUuid => _editing?.fullImageUuid;
  String? get editIconImageUuid => _editing?.iconImageUuid;

  /// Path of a freshly cropped full image (a temp PNG at the full profile),
  /// staged until save, or `null`.
  String? get editFullStagedPath => _editing?.fullStagedPath;

  /// The icon crop region selected over [editFullStagedPath], or `null`.
  CoverCrop? get editIconCrop => _editing?.iconCrop;

  /// The working copy of the edited NPC's system stats (`npcs[].stats`), seeded
  /// from the template defaults (new) or the NPC on disk (edit). Derived fields
  /// are never stored here; the form reads them via the derivation registry.
  Map<String, dynamic> get editStats =>
      _editing?.stats ?? const <String, dynamic>{};

  /// Sets one stat value on the working copy.
  void setStat(String key, dynamic value) {
    final e = _editing;
    if (e == null) return;
    e.stats[key] = value;
    notifyListeners();
  }

  set editName(String value) {
    final e = _editing;
    if (e == null) return;
    e.name = value;
    notifyListeners();
  }

  set editDescription(String value) {
    final e = _editing;
    if (e == null) return;
    e.description = value;
    notifyListeners();
  }

  set editBackstory(String value) {
    final e = _editing;
    if (e == null) return;
    e.backstory = value;
    notifyListeners();
  }

  set editVisibility(VisibilityRules value) {
    final e = _editing;
    if (e == null) return;
    e.visibility = value;
    notifyListeners();
  }

  /// Stages a freshly cropped full image (temp PNG at the full profile),
  /// clearing any previous icon crop (a new full image needs a new icon crop).
  void stageFull(String fullStagedPath) {
    final e = _editing;
    if (e == null) return;
    e.fullStagedPath = fullStagedPath;
    e.iconCrop = null;
    notifyListeners();
  }

  /// Stages the icon crop region over the staged full image.
  void stageIcon(CoverCrop iconCrop) {
    final e = _editing;
    if (e == null || e.fullStagedPath == null) return;
    e.iconCrop = iconCrop;
    notifyListeners();
  }

  /// Records the image ids after the game shell wrote the staged images to disk;
  /// clears the staged source + crop.
  void setEditImageUuids(String fullUuid, String iconUuid) {
    final e = _editing;
    if (e == null) return;
    e.fullImageUuid = fullUuid;
    e.iconImageUuid = iconUuid;
    e.fullStagedPath = null;
    e.iconCrop = null;
    notifyListeners();
  }

  void beginNew() {
    _editing = _Edit.fresh(_template.defaults());
    notifyListeners();
  }

  void beginEdit(String uuid) {
    final npc = _npcs.firstWhere((n) => n.uuid == uuid);
    _editing = _Edit.from(npc, _template.defaults());
    notifyListeners();
  }

  void cancelEdit() {
    _editing = null;
    notifyListeners();
  }

  /// Dirty while the working copy diverges from the edited NPC, or a new image
  /// has been staged.
  bool get isDirty {
    final e = _editing;
    if (e == null) return false;
    return e.name != e.baseName ||
        e.description != e.baseDescription ||
        e.backstory != e.baseBackstory ||
        e.visibility != e.baseVisibility ||
        e.fullStagedPath != null ||
        jsonEncode(e.stats) != jsonEncode(e.baseStats);
  }

  bool get _hasFull =>
      _editing?.fullStagedPath != null || _editing?.fullImageUuid != null;
  bool get _hasIcon =>
      (_editing?.fullStagedPath != null && _editing?.iconCrop != null) ||
      _editing?.iconImageUuid != null;

  /// An NPC needs a name and both role images to be saved.
  bool get canSave => editName.trim().isNotEmpty && _hasFull && _hasIcon;

  /// Returns true when no other NPC uses [name] (trimmed). The currently edited
  /// NPC is excluded so renaming to its own name still passes.
  bool isNameUnique(String name) {
    final trimmed = name.trim();
    final currentUuid = _editing?.uuid;
    return !_npcs.any((n) => n.name == trimmed && n.uuid != currentUuid);
  }

  /// Commits the working copy and closes the editor. Returns `false` without
  /// saving when [canSave]/[isNameUnique] fail. Image files must already have
  /// been written (and their ids set via [setEditImageUuids]) by the shell.
  bool save() {
    final e = _editing;
    if (e == null || !canSave) return false;
    if (!isNameUnique(e.name)) return false;
    if (e.isNew) {
      _npcs.add(
        Npc(
          uuid: _newId(),
          name: e.name.trim(),
          fullImage: e.fullImageUuid,
          iconImage: e.iconImageUuid,
          description: e.description.trim(),
          backstory: e.backstory.trim(),
          visibility: e.visibility,
          extra: _statsExtra(e.stats),
        ),
      );
    } else {
      final npc = _npcs.firstWhere((n) => n.uuid == e.uuid);
      npc.name = e.name.trim();
      npc.fullImage = e.fullImageUuid;
      npc.iconImage = e.iconImageUuid;
      npc.description = e.description.trim();
      npc.backstory = e.backstory.trim();
      npc.visibility = e.visibility;
      if (_template.isEmpty) {
        npc.extra.remove('stats');
      } else {
        npc.extra['stats'] = _persistedStats(e.stats);
      }
    }
    _editing = null;
    notifyListeners();
    return true;
  }

  /// The `npcs` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final n in _npcs) n.toJson()];

  /// The `extra` map for a freshly created NPC — carries `stats` only when the
  /// bound system has a non-empty template.
  Map<String, dynamic> _statsExtra(Map<String, dynamic> stats) =>
      _template.isEmpty ? const {} : {'stats': _persistedStats(stats)};

  /// The `stats` object to persist for the current template. Normally the whole
  /// working map; when [_pruneHiddenStats] is set (7th Sea 2e) only the fields
  /// applicable to the current state are kept — a derived field is never stored,
  /// and a field hidden by its `showWhen` (e.g. a Monster's `strength`) is
  /// dropped, so each kind stores exactly its own fields.
  Map<String, dynamic> _persistedStats(Map<String, dynamic> stats) {
    if (!_pruneHiddenStats) return Map<String, dynamic>.from(stats);
    final out = <String, dynamic>{};
    for (final f in _template.fields) {
      if (f.isDerived) continue;
      if (!isFieldVisible(f, stats)) continue;
      if (stats.containsKey(f.key)) out[f.key] = stats[f.key];
    }
    return out;
  }
}

/// The working copy of the edited NPC plus its baseline for dirty tracking.
class _Edit {
  _Edit({
    this.uuid,
    required this.name,
    required this.description,
    required this.backstory,
    required this.visibility,
    this.fullImageUuid,
    this.iconImageUuid,
    Map<String, dynamic> stats = const {},
  }) : isNew = uuid == null,
       baseName = name,
       baseDescription = description,
       baseBackstory = backstory,
       baseVisibility = visibility,
       stats = Map<String, dynamic>.from(stats),
       baseStats = _deepCopy(stats);

  factory _Edit.fresh(Map<String, dynamic> defaults) => _Edit(
    name: '',
    description: '',
    backstory: '',
    visibility: const VisibilityRules(),
    stats: defaults,
  );

  factory _Edit.from(Npc n, Map<String, dynamic> defaults) {
    // Seed from defaults, then overlay any stats already on disk (back-filling
    // keys a newer template added). Unknown on-disk keys are kept.
    final onDisk = n.extra['stats'];
    final merged = <String, dynamic>{...defaults};
    if (onDisk is Map) {
      onDisk.forEach((k, v) => merged['$k'] = v);
    }
    return _Edit(
      uuid: n.uuid,
      name: n.name,
      description: n.description,
      backstory: n.backstory,
      visibility: n.visibility,
      fullImageUuid: n.fullImage,
      iconImageUuid: n.iconImage,
      stats: merged,
    );
  }

  /// Deep copy via JSON round-trip (stats are plain JSON), for the dirty baseline.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> m) =>
      m.isEmpty ? {} : jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  final String? uuid;
  final bool isNew;
  String name;
  String description;
  String backstory;
  VisibilityRules visibility;
  String? fullImageUuid;
  String? iconImageUuid;

  /// The working copy of the NPC's system stats (`npcs[].stats`).
  final Map<String, dynamic> stats;

  /// The dirty baseline for [stats] (a deep copy at edit start).
  final Map<String, dynamic> baseStats;

  /// A freshly cropped full image (temp PNG), staged until save.
  String? fullStagedPath;

  /// The icon crop region over [fullStagedPath].
  CoverCrop? iconCrop;

  final String baseName;
  final String baseDescription;
  final String baseBackstory;
  final VisibilityRules baseVisibility;
}
