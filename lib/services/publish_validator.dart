import '../notes/note.dart';
import '../npcs/npc.dart';
import '../scenes/scene.dart';
import '../visibility/visibility_rules.dart';
import 'living_scroll_validator.dart';

/// The kind of a publish-readiness problem. Each maps 1:1 to a localized message
/// and a stable widget key (`publish.issue.<name>`), so the UI can render it and
/// tests can assert it without depending on localized text.
enum PublishIssueCode {
  /// A required `metadata` field is empty ([PublishIssue.displaySubject] = field).
  adventureFieldMissing,

  /// An NPC lacks a name and/or one of its two portrait images (subject = name).
  npcIncomplete,

  /// A note has no name and/or no content.
  noteIncomplete,

  /// The adventure has no `start` scene.
  noStartScene,

  /// The adventure has no `end` scene.
  noEndScene,

  /// An `end` scene declares a next scene (subject = scene name).
  endSceneHasNext,

  /// A non-`end` scene declares no next scene (subject = scene name).
  nonEndSceneNoNext,

  /// A non-`end` scene's only next scenes are all conditional — if every gate is
  /// unsatisfied the player is stuck (subject = scene name).
  nonEndSceneOnlyConditionalNext,

  /// Following only always-available (unconditional) scenes from a start scene
  /// never reaches an end scene — the adventure can be unwinnable.
  noUnconditionalPathToEnd,

  /// A non-recurring scene lies on a `next_scenes` cycle — play would have to
  /// return to it after it has already been visited (a visited scene is hidden
  /// from the Next scenes row, so the loop is a dead end). Only a `recurring`
  /// scene may be re-entered (subject = scene name).
  blindLoop,

  /// A named story path (`paths[]`, tagged onto scenes via `path_names`) has no
  /// scene of its own tagged `start` (subject = path name).
  pathNoStartScene,

  /// A named story path has no scene of its own tagged `end` (subject = path
  /// name).
  pathNoEndScene,

  /// Following only always-available (or forced) scenes THAT ARE TAGGED WITH
  /// this path never reaches one of the path's own end scenes from one of its
  /// own start scenes — same unconditional-route rule as
  /// [noUnconditionalPathToEnd], scoped to the path's own scenes (subject =
  /// path name).
  pathNoUnconditionalRouteToEnd,
}

/// The lenient gate for the "Export elements" action (a partial `.lse` export):
/// it requires ONLY the adventure's name and system — enough to identify the
/// file — not the full publish-readiness set. Reuses [PublishIssueCode.adventureFieldMissing]
/// so the result renders in the same dialog as the full export.
class PartExportValidator {
  const PartExportValidator();

  /// The two fields a partial export must have.
  static const List<String> requiredFields = ['name', 'system'];

  List<PublishIssue> validate(Object? decoded) {
    final metadata = decoded is Map ? decoded['metadata'] : null;
    return [
      for (final field in requiredFields)
        if ((metadata is Map ? metadata[field] : null) is! String ||
            (metadata is Map ? metadata[field] as String : '').isEmpty)
          PublishIssue(PublishIssueCode.adventureFieldMissing,
              keySubject: field, displaySubject: field),
    ];
  }

  bool isValid(Object? decoded) => validate(decoded).isEmpty;
}

/// One publish-readiness problem.
class PublishIssue {
  const PublishIssue(this.code, {this.keySubject, this.displaySubject});

  final PublishIssueCode code;

  /// Disambiguates the widget key when a code can repeat (e.g. one per scene);
  /// null for singleton codes.
  final String? keySubject;

  /// Interpolated into the localized message (e.g. the scene/field name).
  final String? displaySubject;

  /// Stable widget key for the issue row in the publish dialog.
  String get keyId => keySubject == null
      ? 'publish.issue.${code.name}'
      : 'publish.issue.${code.name}.$keySubject';

  @override
  String toString() => keyId;
}

/// Validates that a decoded `LivingScroll.json` is READY TO PUBLISH. This is the
/// strictest level: on top of the published-metadata + structural schema
/// ([PublishedAdventureValidator]) it requires every NPC / location / note to
/// have its form-required fields, and enforces the scene-graph rules that make an
/// adventure playable to an ending even when every conditional scene is hidden.
///
/// Pure and synchronous; returns a list of structured [PublishIssue]s (empty when
/// the adventure is publishable).
class PublishValidator {
  const PublishValidator();

  /// A scene is "conditional" when it carries a non-empty visibility gate (it can
  /// be hidden from the player); an "unconditional" scene is always available.
  static bool _isConditional(Scene s) => !s.visibility.isEmpty;
  static bool _isEnd(Scene s) => s.sceneType == 'end';

  List<PublishIssue> validate(Object? decoded) {
    final issues = <PublishIssue>[];
    if (decoded is! Map) {
      // The app always writes a JSON object; guard anyway.
      issues.add(const PublishIssue(PublishIssueCode.adventureFieldMissing,
          keySubject: 'metadata', displaySubject: 'metadata'));
      return issues;
    }

    _validateMetadata(decoded['metadata'], issues);
    _validateNpcs(decoded['npcs'], issues);
    _validateNotes(decoded['notes'], issues);
    _validateScenes(
        decoded['scenes'], decoded['key_events'], decoded['paths'], issues);
    return issues;
  }

  bool isValid(Object? decoded) => validate(decoded).isEmpty;

  // --- metadata: the complete published set is required --------------------

  void _validateMetadata(Object? metadata, List<PublishIssue> issues) {
    // `content_warnings` is optional (not mandatory to publish); every other
    // published-metadata field must be present and non-empty.
    for (final field in LivingScrollValidator.publishedRequiredMetadata) {
      final value = metadata is Map ? metadata[field] : null;
      if (value is! String || value.isEmpty) {
        issues.add(PublishIssue(PublishIssueCode.adventureFieldMissing,
            keySubject: field, displaySubject: field));
      }
    }
  }

  // --- entities: their form-required fields --------------------------------

  void _validateNpcs(Object? raw, List<PublishIssue> issues) {
    if (raw is! List) return;
    for (final e in raw) {
      if (e is! Map) continue;
      final npc = Npc.fromJson(e);
      // Required (mirrors the NPC form's canSave): name + both portrait images.
      if (npc.name.isEmpty || npc.fullImage == null || npc.iconImage == null) {
        issues.add(PublishIssue(PublishIssueCode.npcIncomplete,
            keySubject: npc.uuid, displaySubject: npc.name));
      }
    }
  }

  void _validateNotes(Object? raw, List<PublishIssue> issues) {
    if (raw is! List) return;
    for (final e in raw) {
      if (e is! Map) continue;
      final note = Note.fromJson(e);
      // Required: both a name AND content.
      if (note.name.isEmpty || note.content.isEmpty) {
        issues.add(PublishIssue(PublishIssueCode.noteIncomplete,
            keySubject: note.uuid));
      }
    }
  }

  // --- scenes: the playability graph --------------------------------------

  void _validateScenes(Object? raw, Object? rawKeyEvents, Object? rawPaths,
      List<PublishIssue> issues) {
    if (raw is! List) return;
    final scenes = [
      for (final e in raw)
        if (e is Map) Scene.fromJson(e),
    ];
    if (scenes.isEmpty) {
      // No scenes => neither a start nor an end exists.
      issues.add(const PublishIssue(PublishIssueCode.noStartScene));
      issues.add(const PublishIssue(PublishIssueCode.noEndScene));
      return;
    }

    // next_scenes link by scene_uuid, so the whole graph is keyed by uuid (a
    // target rename never breaks reachability). Issue subjects stay the OWNING
    // scene's name (user-facing label / nav key).
    final byUuid = <String, Scene>{for (final s in scenes) s.uuid: s};
    final starts = [for (final s in scenes) if (s.sceneType == 'start') s];
    final ends = [for (final s in scenes) if (_isEnd(s)) s];

    // scene_uuid -> its visibility gate's key-event NAMES (the gate stores
    // key_event_uuids; map them through the adventure's key_events[]).
    final keyEventNameByUuid = <String, String>{};
    if (rawKeyEvents is List) {
      for (final e in rawKeyEvents) {
        if (e is Map && e['key_event_uuid'] is String && e['name'] is String) {
          keyEventNameByUuid[e['key_event_uuid'] as String] =
              e['name'] as String;
        }
      }
    }
    // scene_uuid -> the DISTINCT scenes that list it in their next_scenes.
    final predecessorUuids = <String, Set<String>>{};
    for (final s in scenes) {
      for (final u in s.nextSceneUuids) {
        (predecessorUuids[u] ??= <String>{}).add(s.uuid);
      }
    }

    // A conditional scene is treated as EFFECTIVELY UNCONDITIONAL when it is
    // FORCED: its single predecessor's only next scene is this scene, and that
    // predecessor holds the key event(s) that unlock its gate — the player must
    // pass through it and can satisfy the gate there, so it is guaranteed.
    bool effectivelyUnconditional(Scene c) {
      if (!_isConditional(c)) return true;
      final preds = predecessorUuids[c.uuid];
      if (preds == null || preds.length != 1) return false;
      final p = byUuid[preds.first];
      if (p == null) return false;
      if (p.nextSceneUuids.length != 1 || p.nextSceneUuids.first != c.uuid) {
        return false;
      }
      return _predecessorSatisfiesGate(p, c, keyEventNameByUuid);
    }

    if (starts.isEmpty) issues.add(const PublishIssue(PublishIssueCode.noStartScene));
    if (ends.isEmpty) issues.add(const PublishIssue(PublishIssueCode.noEndScene));

    for (final s in scenes) {
      if (_isEnd(s)) {
        // An end scene must terminate the adventure.
        if (s.nextSceneUuids.isNotEmpty) {
          issues.add(PublishIssue(PublishIssueCode.endSceneHasNext,
              keySubject: s.name, displaySubject: s.name));
        }
        continue;
      }
      // Every non-end scene must lead somewhere...
      if (s.nextSceneUuids.isEmpty) {
        issues.add(PublishIssue(PublishIssueCode.nonEndSceneNoNext,
            keySubject: s.name, displaySubject: s.name));
        continue;
      }
      // ...and at least one of those next scenes must be always available (or
      // forced), or the player can get stuck once every conditional gate is
      // unsatisfied.
      final hasUnconditionalNext = s.nextSceneUuids.any((u) {
        final t = byUuid[u];
        return t != null && effectivelyUnconditional(t);
      });
      if (!hasUnconditionalNext) {
        issues.add(PublishIssue(
            PublishIssueCode.nonEndSceneOnlyConditionalNext,
            keySubject: s.name,
            displaySubject: s.name));
      }
    }

    // BLIND LOOPS: a non-recurring, non-end scene that lies on a next_scenes
    // cycle (it is reachable from itself) is a dead loop — play would have to
    // return to it once it is already visited, but a visited scene is hidden
    // from the Next scenes row. Only a `recurring` scene may be re-entered, so
    // it never triggers this. This is a hard breaker.
    for (final s in scenes) {
      if (s.sceneType == 'recurring' || _isEnd(s)) continue;
      if (_reachesSelf(s.uuid, byUuid)) {
        issues.add(PublishIssue(PublishIssueCode.blindLoop,
            keySubject: s.name, displaySubject: s.name));
      }
    }

    // There must be a route to an end using ONLY always-available (or forced)
    // scenes (i.e. as if every genuinely conditional scene were hidden).
    // Traverse from the unconditional start scenes, entering only such scenes.
    bool hasUnconditionalRoute({
      required Iterable<Scene> from,
      required Set<String> toUuids,
      bool Function(Scene)? within,
    }) {
      final visited = <String>{};
      final queue = [
        for (final s in from)
          if ((within == null || within(s)) && effectivelyUnconditional(s))
            s.uuid
      ];
      while (queue.isNotEmpty) {
        final uuid = queue.removeLast();
        if (!visited.add(uuid)) continue;
        if (toUuids.contains(uuid)) return true;
        final s = byUuid[uuid];
        if (s == null) continue;
        for (final u in s.nextSceneUuids) {
          final t = byUuid[u];
          if (t != null &&
              (within == null || within(t)) &&
              effectivelyUnconditional(t) &&
              !visited.contains(t.uuid)) {
            queue.add(t.uuid);
          }
        }
      }
      return false;
    }

    if (starts.isNotEmpty && ends.isNotEmpty) {
      final endUuids = {for (final e in ends) e.uuid};
      if (!hasUnconditionalRoute(from: starts, toUuids: endUuids)) {
        issues.add(const PublishIssue(PublishIssueCode.noUnconditionalPathToEnd));
      }
    }

    // PER-PATH: every NAMED story path (`paths[]`, tagged onto scenes via
    // `path_names` — an unnamed path can never be tagged, matching the scene
    // editor's own path multi-select, so it is skipped here too) must have its
    // OWN start scene and end scene, and a route between them using ONLY
    // scenes tagged onto that same path — same unconditional/forced rule as
    // the adventure-wide check above, just scoped to the path's own scenes.
    if (rawPaths is List) {
      for (final p in rawPaths) {
        if (p is! Map) continue;
        final pathName = p['name'];
        if (pathName is! String || pathName.isEmpty) continue;
        final pathColor = p['color'];
        final subject =
            pathColor is String && pathColor.isNotEmpty ? pathColor : pathName;
        bool onPath(Scene s) => s.pathNames.contains(pathName);

        final pathScenes = [for (final s in scenes) if (onPath(s)) s];
        final pathStarts = [
          for (final s in pathScenes) if (s.sceneType == 'start') s
        ];
        final pathEnds = [for (final s in pathScenes) if (_isEnd(s)) s];

        if (pathStarts.isEmpty) {
          issues.add(PublishIssue(PublishIssueCode.pathNoStartScene,
              keySubject: subject, displaySubject: pathName));
        }
        if (pathEnds.isEmpty) {
          issues.add(PublishIssue(PublishIssueCode.pathNoEndScene,
              keySubject: subject, displaySubject: pathName));
        }
        if (pathStarts.isNotEmpty && pathEnds.isNotEmpty) {
          final endUuids = {for (final e in pathEnds) e.uuid};
          if (!hasUnconditionalRoute(
              from: pathStarts, toUuids: endUuids, within: onPath)) {
            issues.add(PublishIssue(
                PublishIssueCode.pathNoUnconditionalRouteToEnd,
                keySubject: subject,
                displaySubject: pathName));
          }
        }
      }
    }
  }

  /// Whether the predecessor [p] holds the key event(s) that unlock conditional
  /// scene [c]'s visibility gate. The gate stores key_event_uuids; [nameByUuid]
  /// maps them to the names that scenes reference in their `key_events`. `or`
  /// needs ANY gating event present in [p]; `and` needs EVERY gating event
  /// present (an unresolved uuid can never be satisfied for `and`).
  static bool _predecessorSatisfiesGate(
      Scene p, Scene c, Map<String, String> nameByUuid) {
    final gateUuids = c.visibility.keyEvents;
    if (gateUuids.isEmpty) return true;
    final requiredNames = <String>[
      for (final u in gateUuids) ?nameByUuid[u],
    ];
    final has = p.keyEventNames.toSet();
    if (c.visibility.op == VisibilityOp.and) {
      if (requiredNames.length != gateUuids.length) return false;
      return requiredNames.every(has.contains);
    }
    return requiredNames.any(has.contains);
  }

  /// Whether scene [start] is reachable from itself by following next_scenes
  /// (i.e. it lies on a directed cycle). Used for blind-loop detection.
  static bool _reachesSelf(String start, Map<String, Scene> byUuid) {
    final seen = <String>{};
    final stack = <String>[...?byUuid[start]?.nextSceneUuids];
    while (stack.isNotEmpty) {
      final u = stack.removeLast();
      if (u == start) return true;
      if (!seen.add(u)) continue;
      final s = byUuid[u];
      if (s != null) stack.addAll(s.nextSceneUuids);
    }
    return false;
  }
}
