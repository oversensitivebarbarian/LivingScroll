import 'package:flutter/foundation.dart';

import '../util/uuid.dart';
import 'key_event.dart';

/// In-memory state for the Key events section: the list of key_events and the
/// currently edited event.
///
/// The game shell owns it so its navigation guard can consult [isDirty] when the
/// user leaves the section mid-edit, and persists [toJson] to LivingScroll.json.
/// Mirrors `NotesController`: a key_event's [KeyEvent.name] must be unique within
/// the document (it is the identifier other entities reference), so [save]
/// enforces uniqueness.
class KeyEventsController extends ChangeNotifier {
  KeyEventsController({String Function()? newId}) : _newId = newId ?? uuidV4;

  /// Mints a new `key_event_uuid` for a freshly created event (injectable for
  /// deterministic tests).
  final String Function() _newId;

  final List<KeyEvent> _events = [];

  List<KeyEvent> get events => List.unmodifiable(_events);

  /// Loads key_events from a decoded LivingScroll.json.
  void loadFrom(Map<String, dynamic> document) {
    _events.clear();
    final list = document['key_events'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) _events.add(KeyEvent.fromJson(e));
      }
    }
    _editing = null;
    notifyListeners();
  }

  // --- edit state ---------------------------------------------------------

  _Edit? _editing;

  bool get isEditing => _editing != null;
  bool get isNew => _editing?.isNew ?? false;

  /// The name the edited event had when the editor opened (its identity key).
  String? get editingName => _editing?.originalName;

  String get editName => _editing?.name ?? '';

  set editName(String value) {
    final e = _editing;
    if (e == null) return;
    e.name = value;
    notifyListeners();
  }

  /// Opens the editor for a brand-new event.
  void beginNew() {
    _editing = _Edit.fresh();
    notifyListeners();
  }

  /// Opens the editor for the existing event [name].
  void beginEdit(String name) {
    final event = _events.firstWhere((e) => e.name == name);
    _editing = _Edit.from(event);
    notifyListeners();
  }

  /// Closes the editor without saving (Cancel / Abandon).
  void cancelEdit() {
    _editing = null;
    notifyListeners();
  }

  /// Dirty while the working copy's name diverges from the baseline. (name is
  /// the only authored field — see [KeyEvent].)
  bool get isDirty {
    final e = _editing;
    if (e == null) return false;
    return e.name != e.baseName;
  }

  /// An event needs a name to be saved.
  bool get canSave => editName.trim().isNotEmpty;

  /// Returns true when no other event already uses [name] (trimmed,
  /// case-sensitive). The currently edited event is excluded so renaming an
  /// event to its own name still passes.
  bool isNameUnique(String name) {
    final trimmed = name.trim();
    final current = _editing?.originalName;
    return !_events.any((e) => e.name == trimmed && e.name != current);
  }

  /// Commits the working copy (adds a new event or updates the edited one) and
  /// closes the editor. Returns `true` when the event was saved; returns `false`
  /// without saving when the name is empty ([canSave]) or duplicates another
  /// event's name ([isNameUnique]).
  bool save() {
    final e = _editing;
    if (e == null || !canSave) return false;
    if (!isNameUnique(e.name)) return false;
    if (e.isNew) {
      // A new event defaults to unchecked; uuid is minted here.
      _events.add(KeyEvent(uuid: _newId(), name: e.name.trim()));
    } else {
      // Only the name is editable; the existing event keeps its uuid + state.
      final event = _events.firstWhere((x) => x.name == e.originalName);
      event.name = e.name.trim();
    }
    _editing = null;
    notifyListeners();
    return true;
  }

  /// Removes the event [name] from the in-memory list (and closes the editor if
  /// it was the one open). The on-disk cascade (stripping references in notes /
  /// scenes) is the store's responsibility.
  void delete(String name) {
    _events.removeWhere((e) => e.name == name);
    if (_editing?.originalName == name) _editing = null;
    notifyListeners();
  }

  /// The `key_events` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final e in _events) e.toJson()];
}

/// The working copy of the edited event's name plus its baseline for dirty
/// tracking. (name is the only authored field; uuid + state live on the
/// underlying [KeyEvent] and are preserved across an edit.)
class _Edit {
  _Edit({this.originalName, required this.name})
      : isNew = originalName == null,
        baseName = name;

  factory _Edit.fresh() => _Edit(name: '');

  factory _Edit.from(KeyEvent e) => _Edit(originalName: e.name, name: e.name);

  final String? originalName;
  final bool isNew;
  String name;
  final String baseName;
}
