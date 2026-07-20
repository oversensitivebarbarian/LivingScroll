import 'dart:io';

import 'package:flutter/foundation.dart';

import '../util/uuid.dart';
import '../visibility/visibility_rules.dart';
import 'note.dart';
import 'note_media.dart';

/// In-memory state for the Notes section: the list of notes, the adventure's
/// key_events (for the visibility editor), and the currently edited note.
///
/// The game shell owns it so its navigation guard can consult [isDirty] when the
/// user leaves the section mid-edit, and persists [toJson] to LivingScroll.json.
class NotesController extends ChangeNotifier {
  NotesController({String Function()? newId}) : _newId = newId ?? uuidV4;

  final String Function() _newId;

  final List<Note> _notes = [];
  List<KeyEventRef> _keyEvents = const [];

  List<Note> get notes => List.unmodifiable(_notes);

  /// The adventure's key_events (uuid + name), for the visibility editor: it
  /// shows each by name but stores the uuid in the rule.
  List<KeyEventRef> get keyEvents => _keyEvents;

  List<NoteMediaRef> _media = const [];

  /// The images a note may embed — the adventure's images plus its NPC
  /// portraits. Fed by the game shell ([setMedia]); used by the note editor's
  /// image picker and to resolve embedded images for display.
  List<NoteMediaRef> get media => _media;

  /// Resolves an image embed's `<scope>:<uuid>` reference to its file (or null
  /// when the referenced image is no longer in the adventure).
  File? mediaFile(String reference) {
    for (final m in _media) {
      if (m.reference == reference) return m.file;
    }
    return null;
  }

  /// Replaces the embeddable images shown by the note editor's image picker
  /// (and used to render embeds), without touching the notes or the open edit.
  void setMedia(List<NoteMediaRef> media) {
    _media = List.unmodifiable(media);
    notifyListeners();
  }

  /// Replaces the available key_events (uuid + name) shown by the visibility
  /// editor, without touching the notes or the open edit. The game shell calls
  /// this when the Key events section changes so a note authored afterwards sees
  /// the up-to-date events.
  void setKeyEvents(List<KeyEventRef> events) {
    _keyEvents = List.unmodifiable(events);
    notifyListeners();
  }

  /// Loads notes and key_events (uuid + name) from a decoded LivingScroll.json.
  void loadFrom(Map<String, dynamic> document) {
    _notes.clear();
    final list = document['notes'];
    if (list is List) {
      for (final n in list) {
        if (n is Map) _notes.add(Note.fromJson(n));
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
  String get editContent => _editing?.content ?? '';
  VisibilityRules get editVisibility =>
      _editing?.visibility ?? const VisibilityRules();

  set editName(String value) {
    final e = _editing;
    if (e == null) return;
    e.name = value;
    notifyListeners();
  }

  set editContent(String value) {
    final e = _editing;
    if (e == null) return;
    e.content = value;
    notifyListeners();
  }

  set editVisibility(VisibilityRules value) {
    final e = _editing;
    if (e == null) return;
    e.visibility = value;
    notifyListeners();
  }

  /// Opens the editor for a brand-new note.
  void beginNew() {
    _editing = _Edit.fresh();
    notifyListeners();
  }

  /// Opens the editor for the existing note [uuid].
  void beginEdit(String uuid) {
    final note = _notes.firstWhere((n) => n.uuid == uuid);
    _editing = _Edit.from(note);
    notifyListeners();
  }

  /// Closes the editor without saving (Cancel / Abandon).
  void cancelEdit() {
    _editing = null;
    notifyListeners();
  }

  /// Dirty while the working copy diverges from the edited note's baseline.
  bool get isDirty {
    final e = _editing;
    if (e == null) return false;
    return e.name != e.baseName ||
        e.content != e.baseContent ||
        e.visibility != e.baseVisibility;
  }

  /// A note needs a name to be saved.
  bool get canSave => editName.trim().isNotEmpty;

  /// Returns true when no other note in the document already uses [name]
  /// (trimmed, case-sensitive). The currently edited note is excluded so
  /// renaming a note to its own name still passes.
  bool isNameUnique(String name) {
    final trimmed = name.trim();
    final currentUuid = _editing?.uuid;
    return !_notes.any(
      (n) => n.name == trimmed && n.uuid != currentUuid,
    );
  }

  /// Commits the working copy (adds a new note or updates the edited one) and
  /// closes the editor. Returns `true` when the note was saved; returns `false`
  /// without saving when the name is empty ([canSave]) or duplicates another
  /// note's name ([isNameUnique]) — uniqueness is enforced here so every save
  /// path (the editor's Save and the rail guard's Save) is held to it.
  bool save() {
    final e = _editing;
    if (e == null || !canSave) return false;
    if (!isNameUnique(e.name)) return false;
    if (e.isNew) {
      _notes.add(Note(
        uuid: _newId(),
        name: e.name.trim(),
        content: e.content,
        visibility: e.visibility,
      ));
    } else {
      final note = _notes.firstWhere((n) => n.uuid == e.uuid);
      note.name = e.name.trim();
      note.content = e.content;
      note.visibility = e.visibility;
    }
    _editing = null;
    notifyListeners();
    return true;
  }

  /// Removes the note [uuid] (and closes the editor if it was the one open).
  void delete(String uuid) {
    _notes.removeWhere((n) => n.uuid == uuid);
    if (_editing?.uuid == uuid) _editing = null;
    notifyListeners();
  }

  /// The `notes` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final n in _notes) n.toJson()];
}

/// The working copy of the edited note plus its baseline for dirty tracking.
class _Edit {
  _Edit({
    this.uuid,
    required this.name,
    required this.content,
    required this.visibility,
  })  : isNew = uuid == null,
        baseName = name,
        baseContent = content,
        baseVisibility = visibility;

  factory _Edit.fresh() =>
      _Edit(name: '', content: '', visibility: const VisibilityRules());

  factory _Edit.from(Note n) => _Edit(
        uuid: n.uuid,
        name: n.name,
        content: n.content,
        visibility: n.visibility,
      );

  final String? uuid;
  final bool isNew;
  String name;
  String content;
  VisibilityRules visibility;
  final String baseName;
  final String baseContent;
  final VisibilityRules baseVisibility;
}
