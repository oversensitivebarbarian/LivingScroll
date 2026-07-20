import 'dart:io';

import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../notes/note_media.dart';
import '../paths/path_colors.dart';
import '../scenes/party_controller.dart';
import '../scenes/scene.dart';
import '../settings/settings_scope.dart';
import '../visibility/visibility_rules.dart';
import '../util/uuid.dart';
import '../widgets/npc_tile.dart' show sevenSeaVillain;
import '../widgets/scene_tile.dart' show SceneTileDisc;
// Scene map (the Play "Mapa" item) is disabled for now — kept for future work.
// See docs/scene_map_widget.md. Re-enable together with the `mapView:` argument
// and the `_buildSceneMap` helpers below.
// import '../scenes/scenes_controller.dart' show ScenePathRef;
// import '../widgets/detail_dialog.dart';
// import '../widgets/scene_map/scene_graph.dart';
// import '../widgets/scene_map/scene_map_view.dart';
import 'play_screen.dart';

/// Hosts a live playthrough of a `{Saves}/<saveName>` adventure: it loads the
/// saved copy and renders the [PlayScreen] for the current scene, advancing as
/// the player follows next scenes / ad-hoc scenes.
///
/// [mode] decides progress recording:
///   * [PlayMode.gameplay] (the launch screen's **Play**) — every scene entered
///     is appended to the save's `history.json` (progress is saved).
///   * [PlayMode.preview] (the launch screen's **Dry run**) — nothing is written
///     (a no-progress trial run).
class PlaythroughScreen extends StatefulWidget {
  const PlaythroughScreen({
    super.key,
    required this.saveName,
    required this.startSceneUuid,
    required this.mode,
    this.store = const ProjectsStore(),
    this.onHome,
  });

  final String saveName;
  final String startSceneUuid;
  final PlayMode mode;
  final ProjectsStore store;

  /// Returns to the app's Home view after the adventure is finished (the end
  /// scene's Finish action). Falls back to popping to the first route.
  final VoidCallback? onHome;

  @override
  State<PlaythroughScreen> createState() => _PlaythroughScreenState();
}

class _PlaythroughScreenState extends State<PlaythroughScreen> {
  bool _loaded = false;
  String _base = '';
  final List<Scene> _scenes = [];
  List<dynamic> _npcs = const [];
  List<dynamic> _notes = const [];
  List<dynamic> _images = const [];
  List<({String uuid, String name})> _keyEvents = const [];
  List<({String name, String colorId})> _paths = const [];

  /// The whole decoded save document, kept so GM-note adds can read-modify-write
  /// it (append to gm_notes[] and link the scene(s)) and persist.
  Map<String, dynamic> _doc = const {};

  /// The party tracks; the displayed scene is derived from the focused track's
  /// `currentSceneUuid`.
  late PartyController _controller;

  /// Runtime ad-hoc scenes: improvised scenes started during play,
  /// each with a minted `scene_uuid`, a GM-entered name and the inherited
  /// next_scenes. They live only here + in `party.json`'s `adhoc_scenes[]` — never
  /// in the adventure's `scenes[]` — so they are never a generic jump target. A
  /// track's `currentSceneUuid` may point at one, and a resume restores the pool
  /// and lands the track back on its ad-hoc scene.
  final List<Scene> _adhoc = [];

  /// The scene currently shown: the author OR ad-hoc scene the focused track
  /// stands on ([_sceneByUuid] resolves both).
  Scene? get _scene => _sceneByUuid(_controller.focused.currentSceneUuid);

  Set<String> _checked = {};

  /// PREP mode back-stack: the (scene, carried checked events) we navigated FROM,
  /// so the Previous scene button can return to where we came from.
  final List<({Scene scene, Set<String> checked})> _backStack = [];

  bool get _gameplay => widget.mode == PlayMode.gameplay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final base = await widget.store.savePath(widget.saveName);
    final doc = await widget.store.readSave(widget.saveName);
    // The player roster (from group.json) sizes the party: a session can split
    // into at most min(players.length, PartyController.maxParallelTracks) tracks
    // (the controller clamps to that hard cap). Empty roster -> single track only.
    final players = await widget.store.readSavePlayers(widget.saveName);
    // A split session persists its tracks to party.json; a resume restores them.
    // Absent/unreadable -> fall back to a single track.
    final partyJson = await widget.store.readPartyState(widget.saveName);
    if (!mounted) return;
    final scenes = <Scene>[];
    if (doc?['scenes'] is List) {
      for (final s in doc!['scenes'] as List) {
        if (s is Map) scenes.add(Scene.fromJson(s));
      }
    }
    _keyEvents = [
      if (doc?['key_events'] is List)
        for (final e in doc!['key_events'] as List)
          if (e is Map && e['name'] is String)
            (
              uuid: e['key_event_uuid'] is String
                  ? e['key_event_uuid'] as String
                  : '',
              name: e['name'] as String,
            ),
    ];
    _paths = [
      if (doc?['paths'] is List)
        for (final p in doc!['paths'] as List)
          if (p is Map && p['name'] is String)
            (
              name: p['name'] as String,
              colorId: p['color'] is String ? p['color'] as String : '',
            ),
    ];
    // Resume: restore the carried checked key events from the save's persisted
    // key_events[].state (a fresh copy has none checked).
    final restored = <String>{
      if (doc?['key_events'] is List)
        for (final e in doc!['key_events'] as List)
          if (e is Map && e['state'] == 'checked' && e['name'] is String)
            e['name'] as String,
    };
    setState(() {
      _base = base;
      _doc = doc ?? <String, dynamic>{};
      _scenes
        ..clear()
        ..addAll(scenes);
      _npcs = (doc?['npcs'] is List) ? doc!['npcs'] as List : const [];
      _notes = (doc?['notes'] is List) ? doc!['notes'] as List : const [];
      _images = (doc?['images'] is List) ? doc!['images'] as List : const [];
      _checked = restored;
      // Restore the runtime ad-hoc scene pool FIRST, so a focused track standing
      // on an ad-hoc scene resolves below and the resume lands back on it.
      _adhoc
        ..clear()
        ..addAll(_adhocFromJson(partyJson));
      final maxTracks = players.isEmpty ? 1 : players.length;
      // Restore the tracks from party.json when present (a split session being
      // resumed); otherwise start a single track on the requested scene (falling
      // back to the first scene). The displayed scene is derived from the focused
      // track hereafter.
      final start =
          _sceneByUuid(widget.startSceneUuid) ??
          (_scenes.isNotEmpty ? _scenes.first : null);
      if (partyJson != null &&
          partyJson['tracks'] is List &&
          (partyJson['tracks'] as List).isNotEmpty) {
        _controller = PartyController.fromJson(partyJson, maxTracks: maxTracks);
        // Defensive: if the focused track's scene can't be resolved (a stale
        // uuid, absent from scenes[] AND the ad-hoc pool), fall back to the
        // requested/first scene so play never dead-ends.
        if (_sceneByUuid(_controller.focused.currentSceneUuid) == null &&
            start != null) {
          _controller.moveFocusedTo(start.uuid);
        }
      } else {
        _controller = PartyController.single(
          sceneUuid: start?.uuid ?? widget.startSceneUuid,
          players: {...players},
          maxTracks: maxTracks,
        );
      }
      _loaded = true;
    });
    await _recordEntry(_scene);
  }

  /// Records the entered [scene] into the save's history (by uuid) — gameplay
  /// only. An ad-hoc scene's uuid resolves via `party.json` on resume/replay.
  Future<void> _recordEntry(Scene? scene) async {
    if (!_gameplay || scene == null) return;
    await widget.store.appendSaveHistory(widget.saveName, scene.uuid);
  }

  /// Rebuilds the runtime ad-hoc scene pool from a `party.json` snapshot's
  /// `adhoc_scenes[]` (uuid + name + inherited next_scenes). Empty when absent.
  List<Scene> _adhocFromJson(Map<String, dynamic>? partyJson) {
    final list = partyJson?['adhoc_scenes'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map && e['scene_uuid'] is String)
          Scene(
            uuid: e['scene_uuid'] as String,
            name: e['name'] is String ? e['name'] as String : '',
            sceneType: Scene.defaultSceneType,
            nextSceneUuids: [
              for (final u
                  in (e['next_scenes'] is List
                      ? e['next_scenes'] as List
                      : const []))
                if (u is String) u,
            ],
          ),
    ];
  }

  /// Resolves [uuid] to a scene, searching the adventure's author scenes AND the
  /// runtime ad-hoc pool. Returns null when neither holds it.
  Scene? _sceneByUuid(String uuid) {
    for (final s in _scenes) {
      if (s.uuid == uuid) return s;
    }
    for (final s in _adhoc) {
      if (s.uuid == uuid) return s;
    }
    return null;
  }

  /// Whether another ACTIVE (non-focused) track already stands on scene [uuid] —
  /// following it would merge the two. Next scenes only ever hold
  /// author uuids, so this naturally never flags an ad-hoc scene.
  bool _occupiedByOtherTrack(String uuid) {
    for (final t in _controller.tracks) {
      if (!t.focused && t.currentSceneUuid == uuid) return true;
    }
    return false;
  }

  /// The Jump-to-scene targets: the current positions of OTHER active
  /// tracks first (path to merge — an author OR ad-hoc scene, flagged
  /// `otherTrackHere`), then GENERIC targets = unvisited AUTHOR scenes (never
  /// ad-hoc, never the focused track's current scene, never a track position
  /// already listed).
  List<PlayJumpTarget> _jumpTargets() {
    final targets = <PlayJumpTarget>[];
    final taken = <String>{};
    final currentUuid = _controller.focused.currentSceneUuid;
    for (final t in _controller.tracks) {
      if (t.focused || !taken.add(t.currentSceneUuid)) continue;
      final s = _sceneByUuid(t.currentSceneUuid);
      if (s != null) {
        targets.add((uuid: s.uuid, name: s.name, otherTrackHere: true));
      }
    }
    for (final s in _scenes) {
      if (s.uuid == currentUuid ||
          taken.contains(s.uuid) ||
          s.extra['visited'] == true) {
        continue;
      }
      targets.add((uuid: s.uuid, name: s.name, otherTrackHere: false));
    }
    return targets;
  }

  /// The current scene's GM notes (resolved from its `gmnotes` uuid links to the
  /// document's `gm_notes[]`).
  List<({String uuid, String content})> _gmNotesFor(Scene scene) {
    final links = scene.extra['gmnotes'];
    if (links is! List) return const [];
    final pool = _doc['gm_notes'];
    final out = <({String uuid, String content})>[];
    for (final uuid in links) {
      if (uuid is! String) continue;
      if (pool is List) {
        for (final g in pool) {
          if (g is Map && g['gmnote_uuid'] == uuid) {
            out.add((
              uuid: uuid,
              content: g['gmnote_content'] is String
                  ? g['gmnote_content'] as String
                  : '',
            ));
            break;
          }
        }
      }
    }
    return out;
  }

  /// Adds a GM note: appends it to `gm_notes[]` and links it to EVERY scene (a GM
  /// note is ALWAYS global), then persists the save and reloads so the new note
  /// shows. Mints a fresh `gmnote_uuid`. A GM note has no title.
  Future<void> _addGmNote(String content) async {
    final scene = _scene;
    if (scene == null) return;
    final uuid = uuidV4();
    final pool = (_doc['gm_notes'] is List)
        ? _doc['gm_notes'] as List
        : (_doc['gm_notes'] = <dynamic>[]);
    pool.add({'gmnote_uuid': uuid, 'gmnote_content': content});
    final scenes = (_doc['scenes'] is List) ? _doc['scenes'] as List : const [];
    for (final s in scenes) {
      if (s is! Map) continue;
      final links = (s['gmnotes'] is List)
          ? s['gmnotes'] as List
          : (s['gmnotes'] = <dynamic>[]);
      links.add(uuid);
    }
    await widget.store.writeSaveDocument(widget.saveName, _doc);
    if (!mounted) return;
    // Re-parse scenes so each scene's `extra['gmnotes']` reflects the new link.
    final reparsed = <Scene>[
      for (final s in scenes)
        if (s is Map) Scene.fromJson(s),
    ];
    setState(() {
      _scenes
        ..clear()
        ..addAll(reparsed);
      // _scene is a getter over the reparsed list — it re-resolves automatically.
    });
  }

  /// Deletes the GM note [uuid]: removes it from `gm_notes[]` and unlinks it from
  /// EVERY scene's `gmnotes[]`, then persists the save and reloads so the tile
  /// disappears.
  Future<void> _deleteGmNote(String uuid) async {
    final scene = _scene;
    if (scene == null) return;
    if (_doc['gm_notes'] is List) {
      (_doc['gm_notes'] as List).removeWhere(
        (g) => g is Map && g['gmnote_uuid'] == uuid,
      );
    }
    final scenes = (_doc['scenes'] is List) ? _doc['scenes'] as List : const [];
    for (final s in scenes) {
      if (s is Map && s['gmnotes'] is List) {
        (s['gmnotes'] as List).removeWhere((u) => u == uuid);
      }
    }
    await widget.store.writeSaveDocument(widget.saveName, _doc);
    if (!mounted) return;
    final reparsed = <Scene>[
      for (final s in scenes)
        if (s is Map) Scene.fromJson(s),
    ];
    setState(() {
      _scenes
        ..clear()
        ..addAll(reparsed);
      // _scene is a getter over the reparsed list — it re-resolves automatically.
    });
  }

  /// Persists a Villain's updated 7th Sea stats after the play Schemes/Intrygi
  /// manager changed its `influence` / `schemes` (gameplay only). Writes the save
  /// and rebuilds so the tile's badges reflect the new available influence + rank.
  Future<void> _updateNpcStats(
    String npcUuid,
    Map<String, dynamic> stats,
  ) async {
    for (final n in _npcs) {
      if (n is Map && n['npc_uuid'] == npcUuid) {
        n['stats'] = stats;
        break;
      }
    }
    await widget.store.writeSaveDocument(widget.saveName, _doc);
    if (!mounted) return;
    setState(() {});
  }

  File? _file(String relative) {
    final f = File('$_base/$relative');
    return f.existsSync() ? f : null;
  }

  /// ALL 7th Sea Villain-kind NPCs in the WHOLE adventure ([_npcs]), regardless
  /// of scene attachment — feeds the Play view's Villains tab. An
  /// `inactive` villain is INCLUDED (not filtered out) so its tile shows greyed
  /// instead of disappearing (unlike the scene-scoped NPC grid).
  List<PlayNpc> _villains(String? system) {
    final out = <PlayNpc>[];
    for (final npc in _npcs) {
      if (npc is! Map) continue;
      final villain = sevenSeaVillain(system, npc['stats']);
      if (villain?.kind != 'villain') continue;
      File? resolve(Object? uuid) => (uuid is String && uuid.isNotEmpty)
          ? _file('images/npcs/$uuid.png')
          : null;
      out.add((
        uuid: npc['npc_uuid'] is String ? npc['npc_uuid'] as String : '',
        name: npc['name'] is String ? npc['name'] as String : '',
        iconImage: resolve(npc['icon_image']),
        fullImage: resolve(npc['full_image']),
        description: npc['description'] is String
            ? npc['description'] as String
            : '',
        backstory: npc['backstory'] is String ? npc['backstory'] as String : '',
        state: npc['state'] is String ? npc['state'] as String : 'active',
        stats: const <({String label, String value})>[],
        villain: villain,
        sevenSeaStats: npc['stats'] is Map
            ? Map<String, dynamic>.from(npc['stats'] as Map)
            : <String, dynamic>{},
      ));
    }
    return out;
  }

  File? _noteImageFile(String reference) {
    final parsed = NoteMediaRef.parse(reference);
    if (parsed == null) return null;
    final (scope, uuid) = parsed;
    final base = scope == 'npc' ? 'images/npcs' : 'images/other';
    return _file('$base/$uuid.png');
  }

  List<SceneTileDisc> _discsFor(Scene t) => [
    for (final p in _paths)
      if (t.pathNames.contains(p.name))
        (
          colorId: p.colorId,
          color: pathColors
              .firstWhere(
                (c) => c.id == p.colorId,
                orElse: () => pathColors.first,
              )
              .color,
        ),
  ];

  List<String> _visibilityNames(Scene t) {
    final names = <String>[];
    for (final uuid in t.visibility.keyEvents) {
      for (final e in _keyEvents) {
        if (e.uuid == uuid) {
          names.add(e.name);
          break;
        }
      }
    }
    return names;
  }

  /// Moves the focused track onto [scene] (author OR ad-hoc — both carry a real
  /// uuid resolvable via [_sceneByUuid]). Must be called inside a setState.
  void _setCurrent(Scene scene) => _controller.moveFocusedTo(scene.uuid);

  /// Splits the focused track: [pcToNewTrack] move to a new track on the same
  /// scene; focus stays on the source. The new track then shows as a PiP
  /// thumbnail. Persists the tracks (gameplay only).
  void _split(Set<String> pcToNewTrack) {
    if (!_controller.canSplit) return;
    setState(() => _controller.split(pcToNewTrack: pcToNewTrack));
    _persistParty();
  }

  /// Switches focus to another track (tapping its PiP thumbnail): the view and
  /// the derived `next_scenes` recompute for its scene. Persists (gameplay only).
  void _switchFocus(String trackId) {
    setState(() => _controller.switchFocus(trackId));
    _persistParty();
  }

  /// The `bg_image` file of the scene a track stands on, for its PiP thumbnail
  /// (null -> flat colour; an ad-hoc scene, unresolved until 05b, has none).
  File? _pipBackground(Track track) {
    final s = _sceneByUuid(track.currentSceneUuid);
    if (s == null || s.bgImage.isEmpty) return null;
    return _file('images/bg_images/${s.bgImage}.png');
  }

  /// Whether a note/image visibility gate ([rulesJson]) is satisfied by [checked]
  /// (the checked key-event NAMES). An empty/absent rule is always visible.
  bool _rulesSatisfied(Object? rulesJson, Set<String> checked) {
    final rules = VisibilityRules.fromJson(rulesJson);
    if (rules.isEmpty) return true;
    final names = <String>[
      for (final uuid in rules.keyEvents)
        for (final ke in _keyEvents)
          if (ke.uuid == uuid) ke.name,
    ];
    return rules.op == VisibilityOp.and
        ? names.every(checked.contains)
        : names.any(checked.contains);
  }

  /// The scene's linked notes that are VISIBLE under [checked] (by `note_uuid`).
  Set<String> _visibleNoteUuids(Scene scene, Set<String> checked) => {
    for (final uuid in scene.noteUuids)
      for (final n in _notes)
        if (n is Map &&
            n['note_uuid'] == uuid &&
            _rulesSatisfied(n['visibility_rules'], checked))
          uuid,
  };

  /// The scene's linked images that are VISIBLE under [checked] (by `image_uuid`).
  Set<String> _visibleImageUuids(Scene scene, Set<String> checked) => {
    for (final uuid in scene.imageUuids)
      for (final im in _images)
        if (im is Map &&
            im['image_uuid'] == uuid &&
            _rulesSatisfied(im['visibility_rules'], checked))
          uuid,
  };

  /// Mirrors `seen = true` on the in-memory note/image maps (so the seen gallery
  /// updates immediately, matching the disk write of [commitSaveProgress]).
  void _markSeenInMemory(Set<String> noteUuids, Set<String> imageUuids) {
    for (final n in _notes) {
      if (n is Map && noteUuids.contains(n['note_uuid'])) n['seen'] = true;
    }
    for (final im in _images) {
      if (im is Map && imageUuids.contains(im['image_uuid'])) im['seen'] = true;
    }
  }

  void _goToScene(Scene? scene, Set<String> checked, Set<String> deactivated) {
    if (scene == null) return;
    final leaving = _scene;
    // The leaving scene's VISIBLE notes/images become "seen" (gameplay only).
    final seenNotes = (leaving != null && _gameplay)
        ? _visibleNoteUuids(leaving, checked)
        : const <String>{};
    final seenImages = (leaving != null && _gameplay)
        ? _visibleImageUuids(leaving, checked)
        : const <String>{};
    setState(() {
      // Remember where we came from (with the checked set as it was) so PREP
      // mode's Previous scene button can return to it.
      if (leaving != null) {
        _backStack.add((scene: leaving, checked: Set<String>.from(_checked)));
        // Gameplay: mirror commitSaveProgress' disk write IN MEMORY so the left
        // scene drops out of any later Next scenes row immediately — a visited
        // scene is never offered again. A `recurring` scene is never marked
        // visited (it stays available).
        if (_gameplay && leaving.sceneType != 'recurring') {
          leaving.extra['visited'] = true;
        }
        // Mirror seen=true in memory (a recurring scene's notes/images are still
        // seen), so the seen gallery reflects it without a reload.
        _markSeenInMemory(seenNotes, seenImages);
      }
      // Mirror the NPC deactivations in memory so a greyed NPC stays greyed
      // (inactive) in the scenes that follow, and its tile loses its button /
      // click. The disk write is done by [_commitOnNavigate] (gameplay only).
      if (deactivated.isNotEmpty) {
        for (final npc in _npcs) {
          if (npc is Map && deactivated.contains(npc['npc_uuid'])) {
            npc['state'] = 'inactive';
          }
        }
      }
      _checked = checked;
      _setCurrent(scene);
      // MERGE: if the focused track now shares its scene with another
      // active track, join them. The condition is pure uuid equality (author OR
      // a shared ad-hoc reached via a jump) — no author-vs-ad-hoc gate; two
      // independently created ad-hoc scenes have distinct uuids and never match.
      final target = _controller.mergeTargetFor(_controller.focused);
      if (target != null) {
        _controller.merge(_controller.focused, target);
      }
    });
    _commitOnNavigate(leaving, scene, deactivated, seenNotes, seenImages);
  }

  /// PREP mode Previous scene: pop the back-stack, returning to the scene (and
  /// the checked events) we arrived from.
  void _previousScene() {
    if (_backStack.isEmpty) return;
    final prev = _backStack.removeLast();
    setState(() {
      _setCurrent(prev.scene);
      _checked = prev.checked;
    });
  }

  /// On navigation to the next scene (gameplay only): persist the session state
  /// into the save's LivingScroll.json — commit the carried checked key events,
  /// mark the scene being left as visited (a `recurring` scene is never marked
  /// visited) and set every [deactivated] NPC's `npcs[].state` to "inactive" —
  /// then record the entered scene in the history. A dry run (preview) records
  /// nothing.
  Future<void> _commitOnNavigate(
    Scene? leaving,
    Scene entered,
    Set<String> deactivated,
    Set<String> seenNoteUuids,
    Set<String> seenImageUuids,
  ) async {
    if (!_gameplay) return;
    if (leaving != null) {
      await widget.store.commitSaveProgress(
        widget.saveName,
        checkedKeyEvents: _checked,
        visitedSceneUuid: leaving.uuid,
        inactiveNpcUuids: deactivated,
        seenNoteUuids: seenNoteUuids,
        seenImageUuids: seenImageUuids,
      );
    }
    await widget.store.appendSaveHistory(widget.saveName, entered.uuid);
    await _persistParty();
  }

  /// Persists the party tracks + runtime ad-hoc scenes to `party.json` after a
  /// mutation (gameplay only; a dry run writes nothing). Resume rebuilds both
  /// from this file (see [_load]).
  Future<void> _persistParty() async {
    if (!_gameplay) return;
    await widget.store.writePartyState(widget.saveName, {
      ..._controller.toJson(),
      'adhoc_scenes': [
        for (final s in _adhoc)
          {
            'scene_uuid': s.uuid,
            'name': s.name,
            'next_scenes': s.nextSceneUuids,
          },
      ],
    });
  }

  /// The end scene's **Finish adventure** action (gameplay): saves the current
  /// game state to the save's files, archives the whole save into `{Finished}`
  /// (with a move timestamp), then returns to Home.
  Future<void> _finishAdventure() async {
    final scene = _scene;
    if (scene != null) {
      await widget.store.commitSaveProgress(
        widget.saveName,
        checkedKeyEvents: _checked,
        visitedSceneUuid: scene.uuid,
        seenNoteUuids: _visibleNoteUuids(scene, _checked),
        seenImageUuids: _visibleImageUuids(scene, _checked),
      );
    }
    await widget.store.finishSave(widget.saveName);
    if (!mounted) return;
    _exitToHome();
  }

  /// Whether EVERY active track currently stands on an end scene — the condition
  /// that re-enables **Finish adventure** while the party is split.
  /// An ad-hoc scene is never an end scene.
  bool get _allTracksAtEnd => _controller.allTracksAtEnd(
    (uuid) => _sceneByUuid(uuid)?.sceneType == 'end',
  );

  /// Leave the playthrough and return to the Home view (NOT the launch screen) —
  /// used by both Finish adventure and Pause/exit, so ending OR interrupting a
  /// session lands on Home, whose Active sessions list is refreshed on arrival
  /// (home_shell `_exitToDestination`). Falls back to popping every
  /// pushed route when no Home callback is wired (standalone hosts).
  void _exitToHome() {
    if (widget.onHome != null) {
      widget.onHome!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Starts an ad-hoc scene named [name]: mints a `scene_uuid`, inherits the
  /// current scene's next_scenes verbatim, adds it to the runtime pool and
  /// navigates the focused track onto it (persisting the pool in gameplay). The
  /// scene has no other content — its Next scenes row mirrors the source.
  void _createAdHoc(String name, Set<String> checked, Set<String> deactivated) {
    final from = _scene;
    if (from == null) return;
    final scene = Scene(
      uuid: 'adhoc-${uuidV4()}',
      name: name,
      sceneType: Scene.defaultSceneType,
      nextSceneUuids: List<String>.from(from.nextSceneUuids),
    );
    _adhoc.add(scene);
    _goToScene(scene, checked, deactivated);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        key: ValueKey('playthrough.loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final scene = _scene;
    if (scene == null) {
      return Scaffold(
        key: const ValueKey('playthrough.empty'),
        body: Center(
          child: TextButton(
            key: const ValueKey('playthrough.exit'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).dialogClose),
          ),
        ),
      );
    }

    // The scene's background: its bg_image (images/bg_images/<uuid>.png), or none.
    final bgImage = scene.bgImage.isEmpty
        ? null
        : _file('images/bg_images/${scene.bgImage}.png');

    final keyEvents = [
      for (final n in scene.keyEventNames)
        (name: n, checked: _checked.contains(n)),
    ];
    // next_scenes store target scene_uuids; resolve each to its scene for the
    // label / discs / gate. A dangling uuid (target absent) is skipped.
    final nextScenes = <PlayNextScene>[
      for (final uuid in scene.nextSceneUuids)
        if (_sceneByUuid(uuid) case final t?)
          (
            uuid: uuid,
            name: t.name,
            discs: _discsFor(t),
            op: t.visibility.op,
            requiredEvents: _visibilityNames(t),
            visited: t.extra['visited'] == true,
            occupiedByOtherTrack: _occupiedByOtherTrack(uuid),
          ),
    ];
    final notes = <({String uuid, String name, String content})>[];
    for (final uuid in scene.noteUuids) {
      for (final n in _notes) {
        if (n is Map && n['note_uuid'] == uuid) {
          notes.add((
            uuid: uuid,
            name: n['note_name'] is String ? n['note_name'] as String : '',
            content: n['note_content'] is String
                ? n['note_content'] as String
                : '',
          ));
          break;
        }
      }
    }
    // The "seen" gallery (shown below a divider in the play view): every note /
    // image already SEEN this playthrough (its `seen` flag committed on leaving a
    // scene), EXCLUDING the current scene's own notes/images (shown above).
    final sceneNoteUuids = scene.noteUuids.toSet();
    final seenNotes = <({String uuid, String name, String content})>[
      for (final n in _notes)
        if (n is Map &&
            n['seen'] == true &&
            n['note_uuid'] is String &&
            !sceneNoteUuids.contains(n['note_uuid']))
          (
            uuid: n['note_uuid'] as String,
            name: n['note_name'] is String ? n['note_name'] as String : '',
            content: n['note_content'] is String
                ? n['note_content'] as String
                : '',
          ),
    ];
    final images = [
      for (final uuid in scene.imageUuids)
        File('$_base/images/other/$uuid.png'),
    ];
    final sceneImageUuids = scene.imageUuids.toSet();
    final seenImages = <File>[
      for (final im in _images)
        if (im is Map &&
            im['seen'] == true &&
            im['image_uuid'] is String &&
            !sceneImageUuids.contains(im['image_uuid']))
          File('$_base/images/other/${im['image_uuid']}.png'),
    ];
    final system = _doc['metadata'] is Map
        ? (_doc['metadata'] as Map)['system']
        : null;
    final npcs = <PlayNpc>[];
    for (final name in scene.npcNames) {
      for (final npc in _npcs) {
        if (npc is Map && npc['name'] == name) {
          File? resolve(Object? uuid) => (uuid is String && uuid.isNotEmpty)
              ? _file('images/npcs/$uuid.png')
              : null;
          npcs.add((
            uuid: npc['npc_uuid'] is String ? npc['npc_uuid'] as String : '',
            name: name,
            iconImage: resolve(npc['icon_image']),
            fullImage: resolve(npc['full_image']),
            description: npc['description'] is String
                ? npc['description'] as String
                : '',
            backstory: npc['backstory'] is String
                ? npc['backstory'] as String
                : '',
            state: npc['state'] is String ? npc['state'] as String : 'active',
            stats: const <({String label, String value})>[],
            villain: sevenSeaVillain(
              system is String ? system : null,
              npc['stats'],
            ),
            sevenSeaStats: npc['stats'] is Map
                ? Map<String, dynamic>.from(npc['stats'] as Map)
                : <String, dynamic>{},
          ));
          break;
        }
      }
    }
    final autoplay = SettingsScope.of(context).overrides.autoplayOn;

    return PlayScreen(
      // Include the focused track id so switching focus (even between two tracks
      // on the SAME scene) rebuilds the view cleanly for the newly focused track.
      key: ValueKey(
        'playthrough.scene.${_controller.focused.id}.${scene.uuid}',
      ),
      scene: scene,
      mode: widget.mode,
      backgroundImage: bgImage,
      keyEvents: keyEvents,
      nextScenes: nextScenes,
      npcs: npcs,
      villains: _villains(system is String ? system : null),
      notes: notes,
      images: images,
      seenNotes: seenNotes,
      seenImages: seenImages,
      gmNotes: _gmNotesFor(scene),
      autoplayMusic: autoplay,
      noteImageResolver: _noteImageFile,
      // Interrupting a session (Pause / exit) returns to Home, like Finish.
      onExit: _exitToHome,
      onSaveAndExit: _exitToHome,
      onFollowScene: (uuid, checked, deactivated) =>
          _goToScene(_sceneByUuid(uuid), checked, deactivated),
      onAdHoc: _createAdHoc,
      onFinishAdventure: _gameplay ? _finishAdventure : null,
      // Party split (gameplay + prep; the editor preview / replay never wire it).
      // Splitting moves the chosen PC to a new track on the same scene.
      onSplit: _split,
      canSplit: _controller.canSplit,
      focusedPcNames: _controller.focused.pcNames.toList(),
      // The un-focused tracks as PiP thumbnails; tapping one switches focus.
      pipTracks: [
        for (final t in _controller.tracks)
          if (!t.focused)
            (
              trackId: t.id,
              backgroundImage: _pipBackground(t),
              pcLabel: t.pcNames.join(', '),
            ),
      ],
      onFocusSwitch: _switchFocus,
      // Jump to scene — visible when split or in a dead end; a jump is a normal
      // navigation (so it also merges when it lands on another track's scene).
      isSplit: _controller.isSplit,
      // Finish adventure stays disabled while split until every track has reached
      // an end scene.
      allTracksAtEnd: _allTracksAtEnd,
      jumpTargets: _jumpTargets(),
      onJump: (uuid, checked, deactivated) =>
          _goToScene(_sceneByUuid(uuid), checked, deactivated),
      // PREP mode (preview) only, once there is somewhere to go back to.
      onPreviousScene: (!_gameplay && _backStack.isNotEmpty)
          ? _previousScene
          : null,
      onAddGmNote: _addGmNote,
      onDeleteGmNote: _deleteGmNote,
      // Gameplay: persist Villain scheme/influence changes to the save; prep
      // (preview) is session-only.
      onUpdateNpcStats: _gameplay ? _updateNpcStats : null,
      // Scene map disabled for now — kept for future work (see
      // docs/scene_map_widget.md). Re-enable by uncommenting this argument and
      // the helpers below (and their imports at the top of the file).
      // mapView: _buildSceneMap(),
    );
  }

  // --- Scene map ("Mapa") — DISABLED, kept for future work --------------------
  // Re-enable together with `mapView: _buildSceneMap()` above and the
  // scene_map imports at the top of the file. See docs/scene_map_widget.md.
  //
  // /// The whole-adventure scene map for the Play rail's "Mapa" item, built in
  // /// PLAY mode: gated scenes (unsatisfied visibility_rules) are hidden, and a
  // /// visited non-recurring scene is not offered as a next. Tapping a station
  // /// opens that scene's read-only detail (no game-state change).
  // Widget _buildSceneMap() {
  //   final paths = _mapPathRefs();
  //   return SceneMapView(
  //     model: buildSceneGraph(
  //       scenes: _scenes,
  //       paths: paths,
  //       mode: SceneMapMode.play,
  //       checkedKeyEvents: _checkedKeyEventUuids(),
  //     ),
  //     mode: SceneMapMode.play,
  //     paths: paths,
  //     onSceneTap: (uuid) {
  //       final s = _sceneByUuid(uuid);
  //       if (s == null) return;
  //       showDetailDialog(
  //         context,
  //         rootKey: 'play.map.scene.detail',
  //         title: s.name,
  //         titleKey: 'play.map.scene.detail.name',
  //         body: s.description,
  //         bodyKey: 'play.map.scene.detail.content',
  //         okKey: 'play.map.scene.detail.ok',
  //       );
  //     },
  //   );
  // }
  //
  // /// The save document's `paths` as (colourId + name) refs for the map legend
  // /// and per-scene colour resolution.
  // List<ScenePathRef> _mapPathRefs() {
  //   final out = <ScenePathRef>[];
  //   final paths = _doc['paths'];
  //   if (paths is List) {
  //     for (final p in paths) {
  //       if (p is Map && p['color'] is String && p['name'] is String) {
  //         out.add((colorId: p['color'] as String, name: p['name'] as String));
  //       }
  //     }
  //   }
  //   return out;
  // }
  //
  // /// The carried checked key events as `key_event_uuid`s (the session tracks
  // /// them by name; visibility_rules reference uuids).
  // Set<String> _checkedKeyEventUuids() => {
  //       for (final ke in _keyEvents)
  //         if (_checked.contains(ke.name)) ke.uuid,
  //     };
}
