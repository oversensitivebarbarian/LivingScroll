import 'dart:io';

import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../notes/note_media.dart';
import '../scenes/scene.dart';
import '../settings/settings_scope.dart';
import '../widgets/npc_tile.dart' show sevenSeaVillain;
import 'play_screen.dart';

/// Replays a FINISHED session (`{Finished}/<dir>`): a read-only playback of the
/// Play view (`PlayMode.replay`) that steps through the scenes in the order the
/// session recorded them (`history.json`).
///
/// Differences from a live play: GM notes cannot be ADDED;
/// key events are DISABLED but show their recorded state; the Next scenes row has
/// only **Previous scene** / **Next scene**, walking the recorded chronology.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({
    super.key,
    required this.finishedDir,
    this.store = const ProjectsStore(),
  });

  /// The directory under `{Finished}` holding the archived session.
  final String finishedDir;
  final ProjectsStore store;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  bool _loaded = false;
  String _base = '';
  final List<Scene> _scenes = [];
  List<String> _history = const [];
  List<dynamic> _npcs = const [];
  String? _system;
  List<dynamic> _notes = const [];
  List<dynamic> _gmNotes = const [];
  Map<String, bool> _keyEventChecked = const {};

  /// Position in the recorded chronology ([_history]).
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final base = await widget.store.finishedPath(widget.finishedDir);
    final doc = await widget.store.readFinished(widget.finishedDir);
    final history = await widget.store.readFinishedHistory(widget.finishedDir);
    // Runtime ad-hoc scenes recorded during the session (party.json). The
    // chronology (history.json) references them by uuid, so they must join the
    // resolvable scene list for replay.
    final party = await widget.store.readFinishedPartyState(widget.finishedDir);
    if (!mounted) return;
    final scenes = <Scene>[
      if (doc?['scenes'] is List)
        for (final s in doc!['scenes'] as List)
          if (s is Map) Scene.fromJson(s),
      if (party?['adhoc_scenes'] is List)
        for (final e in party!['adhoc_scenes'] as List)
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
    final keyEventChecked = <String, bool>{
      if (doc?['key_events'] is List)
        for (final e in doc!['key_events'] as List)
          if (e is Map && e['name'] is String)
            e['name'] as String: e['state'] == 'checked',
    };
    setState(() {
      _base = base;
      _scenes
        ..clear()
        ..addAll(scenes);
      _history = history;
      _npcs = (doc?['npcs'] is List) ? doc!['npcs'] as List : const [];
      _system =
          (doc?['metadata'] is Map && doc!['metadata']['system'] is String)
          ? doc['metadata']['system'] as String
          : null;
      _notes = (doc?['notes'] is List) ? doc!['notes'] as List : const [];
      _gmNotes = (doc?['gm_notes'] is List)
          ? doc!['gm_notes'] as List
          : const [];
      _keyEventChecked = keyEventChecked;
      _index = 0;
      _loaded = true;
    });
  }

  Scene? _sceneByUuid(String uuid) {
    for (final s in _scenes) {
      if (s.uuid == uuid) return s;
    }
    return null;
  }

  /// The scene at the current chronology position (resolved by uuid — author or
  /// ad-hoc; the ad-hoc scenes were folded into [_scenes] on load).
  Scene? get _scene {
    if (_history.isNotEmpty && _index >= 0 && _index < _history.length) {
      final byUuid = _sceneByUuid(_history[_index]);
      if (byUuid != null) return byUuid;
    }
    return _scenes.isNotEmpty ? _scenes.first : null;
  }

  File? _file(String relative) {
    final f = File('$_base/$relative');
    return f.existsSync() ? f : null;
  }

  /// ALL 7th Sea Villain-kind NPCs in the WHOLE adventure ([_npcs]), regardless
  /// of scene attachment — feeds the Play view's Villains tab. An
  /// `inactive` villain is INCLUDED (not filtered out) so its tile shows greyed
  /// instead of disappearing (unlike the scene-scoped NPC grid).
  List<PlayNpc> _villains() {
    final out = <PlayNpc>[];
    for (final npc in _npcs) {
      if (npc is! Map) continue;
      final villain = sevenSeaVillain(_system, npc['stats']);
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
    final dir = scope == 'npc' ? 'images/npcs' : 'images/other';
    return _file('$dir/$uuid.png');
  }

  List<({String uuid, String content})> _gmNotesFor(Scene scene) {
    final links = scene.extra['gmnotes'];
    if (links is! List) return const [];
    final out = <({String uuid, String content})>[];
    for (final uuid in links) {
      if (uuid is! String) continue;
      for (final g in _gmNotes) {
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
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        key: ValueKey('replay.loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final scene = _scene;
    if (scene == null) {
      return Scaffold(
        key: const ValueKey('replay.empty'),
        body: Center(
          child: TextButton(
            key: const ValueKey('replay.exit'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      );
    }

    // The scene's background: its bg_image (images/bg_images/<uuid>.png), or none.
    final bgImage = scene.bgImage.isEmpty
        ? null
        : _file('images/bg_images/${scene.bgImage}.png');

    // Key events: ALL of the scene's events, with their RECORDED state. The play
    // view renders them disabled in replay mode.
    final keyEvents = [
      for (final n in scene.keyEventNames)
        (name: n, checked: _keyEventChecked[n] ?? false),
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
    final images = [
      for (final uuid in scene.imageUuids)
        File('$_base/images/other/$uuid.png'),
    ];
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
            villain: sevenSeaVillain(_system, npc['stats']),
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
      key: ValueKey('replay.scene.$_index'),
      scene: scene,
      mode: PlayMode.replay,
      backgroundImage: bgImage,
      keyEvents: keyEvents,
      nextScenes: const [],
      npcs: npcs,
      villains: _villains(),
      notes: notes,
      images: images,
      gmNotes: _gmNotesFor(scene),
      autoplayMusic: autoplay,
      noteImageResolver: _noteImageFile,
      onExit: () => Navigator.of(context).pop(),
      onReplayPrevious: _index > 0 ? () => setState(() => _index--) : null,
      onReplayNext: _index < _history.length - 1
          ? () => setState(() => _index++)
          : null,
    );
  }
}
