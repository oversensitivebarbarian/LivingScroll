import '../util/uuid.dart';

/// One exploration **track**: a subset of the party travelling the scene graph
/// on its own. Party split is a runtime-only mechanic — a session starts as ONE
/// track holding every player and can divide into more.
///
/// [currentSceneUuid] may point at an author scene (`scenes[]`) OR a runtime
/// ad-hoc scene (`adhoc_scenes[]`); the controller treats them the same and
/// merges purely on uuid equality.
class Track {
  Track({
    required this.id,
    required this.currentSceneUuid,
    required this.pcNames,
    this.focused = false,
  });

  /// Stable minted id (uuidV4), distinct from any scene uuid.
  final String id;

  /// The scene this track currently stands on (author or ad-hoc uuid). Mutated
  /// by [PartyController.moveFocusedTo] on navigation.
  String currentSceneUuid;

  /// The player-character names travelling on this track. Split removes some,
  /// merge unions them.
  final Set<String> pcNames;

  /// Exactly one track in a controller is focused (shown full-screen) at a time.
  bool focused;
}

/// The pure, UI-free, I/O-free brain of party split: it owns the list of
/// [Track]s and the rules for split / focus / merge / track-end, plus the
/// [maxTracks] cap. The host (`PlaythroughScreen`)
/// wraps every mutation in `setState` and persists [toJson] to `party.json`;
/// this class has NO dependency on `BuildContext`, files or `ProjectsStore`.
class PartyController {
  PartyController._(this._tracks, int maxTracks, this._newId)
    : maxTracks = maxTracks < maxParallelTracks ? maxTracks : maxParallelTracks;

  /// Hard upper bound on the number of concurrent tracks, regardless of roster
  /// size: a session can divide into AT MOST this many parallel paths. A larger
  /// roster does not raise it.
  static const int maxParallelTracks = 4;

  /// A fresh session: ONE focused track on [sceneUuid] holding all [players].
  /// [maxTracks] is the roster size, clamped to [maxParallelTracks]: a session
  /// splits into at most `min(players.length, `[maxParallelTracks]`)` tracks;
  /// pass `players.length` (or 1 when there are no players — split is then
  /// impossible). [newId] is injectable for deterministic tests.
  factory PartyController.single({
    required String sceneUuid,
    required Set<String> players,
    required int maxTracks,
    String Function()? newId,
  }) {
    final mint = newId ?? uuidV4;
    return PartyController._(
      [
        Track(
          id: mint(),
          currentSceneUuid: sceneUuid,
          pcNames: {...players},
          focused: true,
        ),
      ],
      maxTracks,
      mint,
    );
  }

  final List<Track> _tracks;

  /// The maximum number of concurrent tracks for this session: the roster size
  /// clamped to [maxParallelTracks] (= `min(players.length, `[maxParallelTracks]`)`).
  final int maxTracks;

  final String Function() _newId;

  /// The active tracks, in creation order (read-only view).
  List<Track> get tracks => List.unmodifiable(_tracks);

  /// The focused track (the one shown full-screen). Exactly one track is focused
  /// while [tracks] is non-empty.
  Track get focused =>
      _tracks.firstWhere((t) => t.focused, orElse: () => _tracks.first);

  /// Index of the focused track in [tracks], or -1 when none is marked.
  int get focusedIndex => _tracks.indexWhere((t) => t.focused);

  /// Whether the party is currently divided (more than one track).
  bool get isSplit => _tracks.length > 1;

  /// Whether a split is available: below the roster cap AND the focused track
  /// holds at least two PC (you cannot split a solo track).
  bool get canSplit =>
      _tracks.length < maxTracks && focused.pcNames.length >= 2;

  /// Whether EVERY active track currently stands on an end scene (per
  /// [isEndScene]). This is the ONLY condition under which the whole adventure
  /// may be finished while the party is split: the GM must first bring every
  /// track to an end scene (not necessarily the SAME one).
  bool allTracksAtEnd(bool Function(String sceneUuid) isEndScene) =>
      _tracks.every((t) => isEndScene(t.currentSceneUuid));

  /// Splits the focused track: the PC in [pcToNewTrack] move to a NEW track that
  /// starts on the SAME scene; the rest stay on the source. Focus stays on the
  /// source track. Returns the new track.
  ///
  /// Throws [StateError] when [canSplit] is false, and [ArgumentError] when
  /// [pcToNewTrack] is empty, is not a strict subset of the focused track's PC
  /// (at least one PC must stay), or names a PC the track does not hold.
  Track split({required Set<String> pcToNewTrack}) {
    if (!canSplit) {
      throw StateError('split is not available (canSplit == false)');
    }
    final source = focused;
    if (pcToNewTrack.isEmpty ||
        pcToNewTrack.length >= source.pcNames.length ||
        !pcToNewTrack.every(source.pcNames.contains)) {
      throw ArgumentError(
        'pcToNewTrack must be a non-empty proper subset of the focused '
        "track's PC (at least one stays, at least one moves)",
      );
    }
    source.pcNames.removeAll(pcToNewTrack);
    final track = Track(
      id: _newId(),
      currentSceneUuid: source.currentSceneUuid,
      pcNames: {...pcToNewTrack},
      focused: false,
    );
    _tracks.add(track);
    return track;
  }

  /// Makes the track with [trackId] the focused one (all others un-focused).
  /// No-op when no track has that id.
  void switchFocus(String trackId) {
    if (!_tracks.any((t) => t.id == trackId)) return;
    for (final t in _tracks) {
      t.focused = t.id == trackId;
    }
  }

  /// Moves the focused track onto [sceneUuid] (navigation). Does NOT perform a
  /// merge — the host runs the merge check separately via [mergeTargetFor] /
  /// [merge] after navigating, so a jump and a follow share one path.
  void moveFocusedTo(String sceneUuid) {
    focused.currentSceneUuid = sceneUuid;
  }

  /// Another active track standing on the SAME `currentSceneUuid` as [t], or
  /// null when [t] is alone on its scene. The condition is pure uuid equality —
  /// there is NO author-vs-ad-hoc gate: each ad-hoc scene has a unique minted
  /// uuid, so two independently created ad-hoc scenes never match, while two
  /// tracks genuinely on the same scene (author, or a shared ad-hoc reached by
  /// a jump) do.
  Track? mergeTargetFor(Track t) {
    for (final o in _tracks) {
      if (o.id != t.id && o.currentSceneUuid == t.currentSceneUuid) return o;
    }
    return null;
  }

  /// Merges tracks [a] and [b] (which stand on the same scene): the survivor is
  /// the one closer to the root — the lower index in [tracks], i.e. the
  /// earlier-created track. The other's PC are unioned into the survivor, it is
  /// removed, and focus moves to the survivor.
  void merge(Track a, Track b) {
    final ia = _tracks.indexOf(a);
    final ib = _tracks.indexOf(b);
    if (ia < 0 || ib < 0 || identical(a, b)) return;
    final survivor = ia <= ib ? a : b;
    final gone = identical(survivor, a) ? b : a;
    survivor.pcNames.addAll(gone.pcNames);
    _tracks.remove(gone);
    switchFocus(survivor.id);
  }

  /// The tracks snapshot for `party.json`. Ad-hoc scenes are stored separately
  /// by the host; this covers only the track list.
  Map<String, dynamic> toJson() => {
    'tracks': [
      for (final t in _tracks)
        {
          'id': t.id,
          'current_scene_uuid': t.currentSceneUuid,
          'pc_names': t.pcNames.toList(),
          'focused': t.focused,
        },
    ],
  };

  /// Restores a controller from a `party.json` [json] snapshot. Validates the
  /// focus invariant: if the snapshot has no focused track, or
  /// more than one, the FIRST track is made focused. A snapshot with no usable
  /// tracks yields a single empty focused track (defensive — callers should use
  /// [PartyController.single] for a fresh session).
  factory PartyController.fromJson(
    Map<String, dynamic> json, {
    required int maxTracks,
    String Function()? newId,
  }) {
    final mint = newId ?? uuidV4;
    final tracks = <Track>[];
    if (json['tracks'] is List) {
      for (final e in json['tracks'] as List) {
        if (e is! Map) continue;
        tracks.add(
          Track(
            id: e['id'] is String ? e['id'] as String : mint(),
            currentSceneUuid: e['current_scene_uuid'] is String
                ? e['current_scene_uuid'] as String
                : '',
            pcNames: {
              for (final p
                  in (e['pc_names'] is List ? e['pc_names'] as List : const []))
                if (p is String) p,
            },
            focused: e['focused'] == true,
          ),
        );
      }
    }
    if (tracks.isEmpty) {
      tracks.add(
        Track(id: mint(), currentSceneUuid: '', pcNames: {}, focused: true),
      );
    }
    final focusedCount = tracks.where((t) => t.focused).length;
    if (focusedCount != 1) {
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].focused = i == 0;
      }
    }
    return PartyController._(tracks, maxTracks, mint);
  }
}
