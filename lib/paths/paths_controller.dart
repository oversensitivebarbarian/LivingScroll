import 'package:flutter/foundation.dart';

/// One path's editable data.
class PathEntry {
  PathEntry({this.name = '', this.description = '', this.immutable = false});

  String name;
  String description;

  /// Runtime save-only flag: part of the immutable base content stamped at
  /// save creation. Preserved on round-trip so the save-edit editor never
  /// drops it. Absent/`false` in projects and exports.
  bool immutable;
}

/// In-memory state for the Paths section: the name/description of each path
/// (keyed by colour id) plus the currently edited path.
///
/// The game shell owns it so its navigation guard can consult [isDirty] when the
/// user leaves the Paths section mid-edit. (Persistence to LivingScroll.json is
/// a later step — the path data shape is not defined yet.)
class PathsController extends ChangeNotifier {
  PathsController(List<String> ids)
    : _entries = {for (final id in ids) id: PathEntry()};

  final Map<String, PathEntry> _entries;

  /// Colour ids currently referenced by at least one scene's `path_names`
  /// (matched against each path's STORED name — `paths[]` / `scenes[].path_names`).
  /// Pushed by the game shell whenever scenes or paths change
  /// (`_refreshUsedPaths` in game_screen.dart) so the edit form can refuse to
  /// blank the name of a path a scene still depends on.
  Set<String> _usedIds = const <String>{};

  /// Replaces the set of colour ids referenced by a scene right now.
  void setUsedIds(Set<String> ids) {
    if (setEquals(_usedIds, ids)) return;
    _usedIds = ids;
    notifyListeners();
  }

  /// Whether [id]'s stored name is referenced by any scene right now.
  bool isUsedByScene(String id) => _usedIds.contains(id);

  String name(String id) => _entries[id]?.name ?? '';
  String description(String id) => _entries[id]?.description ?? '';

  /// Whether the path [id] is immutable base content (frozen in save-content
  /// editing).
  bool immutable(String id) => _entries[id]?.immutable ?? false;

  /// The colour ids this controller manages, in their declared order.
  Iterable<String> get ids => _entries.keys;

  /// Populates the paths from a decoded `LivingScroll.json`: each `paths` entry
  /// is matched to a known colour by its `color` field. Unknown colours and
  /// malformed entries are ignored.
  void loadFrom(Map<String, dynamic> document) {
    for (final entry in _entries.values) {
      entry.name = '';
      entry.description = '';
      entry.immutable = false;
    }
    final paths = document['paths'];
    if (paths is List) {
      for (final item in paths) {
        if (item is! Map) continue;
        final color = item['color'];
        if (color is! String) continue;
        final entry = _entries[color];
        if (entry == null) continue;
        final n = item['name'];
        final d = item['description'];
        entry.name = n is String ? n : '';
        entry.description = d is String ? d : '';
        entry.immutable = item['immutable'] == true;
      }
    }
    _editingId = null;
    notifyListeners();
  }

  /// The `paths` list to write back: one object per non-empty path, in colour
  /// order, with the colour as the unique key (colours never repeat).
  List<Map<String, dynamic>> toJson() => [
    for (final id in _entries.keys)
      if (_entries[id]!.name.trim().isNotEmpty ||
          _entries[id]!.description.trim().isNotEmpty)
        {
          'name': _entries[id]!.name.trim(),
          'color': id,
          'description': _entries[id]!.description.trim(),
          if (_entries[id]!.immutable) 'immutable': true,
        },
  ];

  // --- edit state ---------------------------------------------------------

  String? _editingId;
  String _editName = '';
  String _editDescription = '';

  /// The path currently being edited, or `null` when the grid is shown.
  String? get editingId => _editingId;
  bool get isEditing => _editingId != null;

  String get editName => _editName;
  String get editDescription => _editDescription;

  /// Opens the edit form for [id], loading its stored values as the baseline.
  void beginEdit(String id) {
    _editingId = id;
    _editName = _entries[id]?.name ?? '';
    _editDescription = _entries[id]?.description ?? '';
    notifyListeners();
  }

  set editName(String value) {
    _editName = value;
    notifyListeners();
  }

  set editDescription(String value) {
    _editDescription = value;
    notifyListeners();
  }

  /// Dirty while the working copy diverges from the edited path's stored values.
  bool get isDirty {
    final id = _editingId;
    if (id == null) return false;
    final stored = _entries[id]!;
    return _editName != stored.name || _editDescription != stored.description;
  }

  /// Save is offered only when there is something to persist. Whether that
  /// save is actually ALLOWED (name not required, or not blank) is
  /// [nameRequiredButEmpty]'s job, checked on tap — mirroring the
  /// scenes/notes duplicate-name pattern (button enabled, tap-time dialog).
  bool get canSave => isDirty;

  /// True when Save must be refused: the path being edited is referenced by a
  /// scene's `path_names`, and the working name has been left blank. A path
  /// with no name cannot be selected by a scene, so clearing the name of one
  /// already in use would silently strand that scene's reference.
  bool get nameRequiredButEmpty {
    final id = _editingId;
    if (id == null) return false;
    return _usedIds.contains(id) && _editName.trim().isEmpty;
  }

  /// Commits the working copy to the edited path and returns to the grid.
  void save() {
    final id = _editingId;
    if (id == null) return;
    final entry = _entries[id]!;
    entry.name = _editName;
    entry.description = _editDescription;
    _editingId = null;
    notifyListeners();
  }

  /// Drops the working copy and returns to the grid (Abandon).
  void discardEdit() {
    _editingId = null;
    notifyListeners();
  }
}
