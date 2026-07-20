import 'package:flutter/foundation.dart';

import '../util/uuid.dart';
import 'soundtrack.dart';

/// In-memory state for the Soundtracks section: the list of tracks and which one
/// is currently playing (drives the tile's Play/Stop glyph).
///
/// The game shell owns it so it can wire add (pick + copy + persist), delete
/// (remove + delete file + persist) and playback (resolve file + play/stop). The
/// section has no editor, so — unlike Notes / Key events — there is no edit/dirty
/// state. Track names must be UNIQUE within `audio[]`.
class SoundtracksController extends ChangeNotifier {
  SoundtracksController({String Function()? newId}) : _newId = newId ?? uuidV4;

  /// Mints a new `audio_uuid` for an added track (injectable for tests).
  final String Function() _newId;

  final List<Soundtrack> _items = [];

  List<Soundtrack> get items => List.unmodifiable(_items);

  /// The uuid of the track currently playing, or `null` when nothing plays.
  String? _playingUuid;
  String? get playingUuid => _playingUuid;
  bool isPlaying(String uuid) => _playingUuid == uuid;

  /// Loads tracks from a decoded LivingScroll.json (and stops any playback).
  void loadFrom(Map<String, dynamic> document) {
    _items.clear();
    final list = document['audio'];
    if (list is List) {
      for (final a in list) {
        if (a is Map) _items.add(Soundtrack.fromJson(a));
      }
    }
    _playingUuid = null;
    notifyListeners();
  }

  /// True when no track already uses [name] (trimmed) — the derived display name
  /// must be unique within `audio[]`.
  bool isNameUnique(String name) {
    final trimmed = name.trim();
    return !_items.any((s) => s.name == trimmed);
  }

  /// Appends a new track with the derived [name], minting an `audio_uuid`, and
  /// returns that uuid. The caller copies the file (`audio/<uuid>.<ext>`) and
  /// persists `audio[]`.
  String add(String name) {
    final uuid = _newId();
    _items.add(Soundtrack(uuid: uuid, name: name.trim()));
    notifyListeners();
    return uuid;
  }

  /// Removes the track [uuid] (and clears the playing flag if it was playing).
  void delete(String uuid) {
    _items.removeWhere((s) => s.uuid == uuid);
    if (_playingUuid == uuid) _playingUuid = null;
    notifyListeners();
  }

  /// Records which track is playing (or `null`). Drives the tile glyph.
  void setPlaying(String? uuid) {
    _playingUuid = uuid;
    notifyListeners();
  }

  /// The `audio` list to write back to LivingScroll.json.
  List<Map<String, dynamic>> toJson() => [for (final s in _items) s.toJson()];
}
