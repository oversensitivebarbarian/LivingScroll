import '../../scenes/scene.dart';
import '../../scenes/scenes_controller.dart' show ScenePathRef;
import '../../visibility/visibility_rules.dart';

/// Which view the map is built for. `game` (the editor) shows the WHOLE graph
/// regardless of play state; `play` respects the save's visibility / visited
/// state. The difference lives entirely in [buildSceneGraph]'s `mode` parameter.
enum SceneMapMode { game, play }

/// A station shape, derived from `scenes[].scene_type`.
enum SceneShape { start, standard, recurring, end }

/// How a connecting segment is drawn: [neutral] (no shared line — a thin grey
/// connector), [single] (one shared line) or [parallel] (≥2 shared lines, drawn
/// as offset ribbons).
enum SceneEdgeKind { neutral, single, parallel }

/// One station in the scene map (a `scenes[]` entry projected for display).
class SceneNode {
  const SceneNode({
    required this.uuid,
    required this.name,
    required this.shape,
    required this.pathColorIds,
    required this.interchange,
    required this.inactive,
    required this.conditional,
  });

  /// `scene_uuid` — the stable node key (never the name).
  final String uuid;
  final String name;
  final SceneShape shape;

  /// The colour ids of the lines this station sits on, in declared `path_names`
  /// order (unknown path names are dropped).
  final List<String> pathColorIds;

  /// On ≥2 lines — rendered as an interchange (large hollow ring).
  final bool interchange;

  /// `state == "inactive"` — drawn greyed in both modes.
  final bool inactive;

  /// Has a non-empty `visibility_rules` — in game mode it is marked discreetly
  /// (the author still sees it); in play mode a hidden scene is removed entirely.
  final bool conditional;
}

/// One directed segment between two stations (`scenes[].next_scenes[]`).
class SceneEdge {
  const SceneEdge({
    required this.fromUuid,
    required this.toUuid,
    required this.colorIds,
    required this.kind,
  });

  final String fromUuid;
  final String toUuid;

  /// The lines shared by BOTH endpoints, in the source's declared order. Empty
  /// for a [SceneEdgeKind.neutral] connector.
  final List<String> colorIds;
  final SceneEdgeKind kind;
}

/// The display projection of an adventure's scene graph: the [nodes] and [edges]
/// to render, the [pathColorIdsInUse] (for the line legend, in declared order)
/// and any [warnings] (e.g. dangling `next_scenes`) gathered defensively.
class SceneGraphModel {
  const SceneGraphModel({
    required this.nodes,
    required this.edges,
    required this.pathColorIdsInUse,
    required this.warnings,
  });

  final List<SceneNode> nodes;
  final List<SceneEdge> edges;
  final List<String> pathColorIdsInUse;
  final List<String> warnings;

  bool get isEmpty => nodes.isEmpty;

  SceneNode? nodeFor(String uuid) {
    for (final n in nodes) {
      if (n.uuid == uuid) return n;
    }
    return null;
  }
}

/// Whether a scene's [rules] are satisfied by the currently [checkedKeyEvents]
/// (a set of `key_event_uuid`s). An empty rule is always visible; `and` needs
/// every listed event checked, `or` needs at least one. Pure — shared by both
/// modes (only play consults it).
bool isSceneVisible(VisibilityRules rules, Set<String> checkedKeyEvents) {
  if (rules.isEmpty) return true;
  if (rules.op == VisibilityOp.and) {
    return rules.keyEvents.every(checkedKeyEvents.contains);
  }
  return rules.keyEvents.any(checkedKeyEvents.contains);
}

SceneShape _shapeOf(String sceneType) => switch (sceneType) {
      'start' => SceneShape.start,
      'recurring' => SceneShape.recurring,
      'end' => SceneShape.end,
      _ => SceneShape.standard,
    };

/// Builds the [SceneGraphModel] for the given [scenes].
///
/// [paths] maps each path NAME to its colour id (`ScenesController.paths`).
/// In [SceneMapMode.play] a scene whose own `visibility_rules` is not satisfied
/// by [checkedKeyEvents] is removed (node + edges), and an edge into an
/// already-`visited` non-`recurring` scene is dropped (it is never offered as a
/// next scene). [SceneMapMode.game] shows everything and only flags conditional
/// scenes. A `next_scenes` link to an unknown scene is skipped and recorded in
/// [SceneGraphModel.warnings] — the build never throws.
SceneGraphModel buildSceneGraph({
  required List<Scene> scenes,
  required List<ScenePathRef> paths,
  required SceneMapMode mode,
  Set<String> checkedKeyEvents = const {},
}) {
  final colorByName = {for (final p in paths) p.name: p.colorId};
  final byUuid = {for (final s in scenes) s.uuid: s};

  List<String> colorsOf(Scene s) {
    final out = <String>[];
    for (final n in s.pathNames) {
      final c = colorByName[n];
      if (c != null && !out.contains(c)) out.add(c);
    }
    return out;
  }

  bool isRecurring(Scene s) => s.sceneType == 'recurring';
  bool isVisited(Scene s) => s.extra['visited'] == true;

  bool present(Scene s) =>
      mode == SceneMapMode.game ||
      isSceneVisible(s.visibility, checkedKeyEvents);

  final presentScenes = [for (final s in scenes) if (present(s)) s];
  final presentUuids = {for (final s in presentScenes) s.uuid};

  final usedColors = <String>{};
  final nodes = <SceneNode>[];
  for (final s in presentScenes) {
    final colors = colorsOf(s);
    usedColors.addAll(colors);
    nodes.add(SceneNode(
      uuid: s.uuid,
      name: s.name,
      shape: _shapeOf(s.sceneType),
      pathColorIds: colors,
      interchange: colors.length >= 2,
      inactive: s.extra['state'] == 'inactive',
      conditional: !s.visibility.isEmpty,
    ));
  }

  final edges = <SceneEdge>[];
  final warnings = <String>[];
  for (final s in presentScenes) {
    final sourceColors = colorsOf(s);
    for (final targetUuid in s.nextSceneUuids) {
      final target = byUuid[targetUuid];
      if (target == null) {
        warnings.add('Scene "${s.uuid}" links a missing next scene '
            '"$targetUuid" — segment skipped.');
        continue;
      }
      if (!presentUuids.contains(targetUuid)) continue; // gated / hidden
      if (mode == SceneMapMode.play &&
          isVisited(target) &&
          !isRecurring(target)) {
        continue; // a visited scene is never offered as a next scene
      }
      final targetColors = colorsOf(target).toSet();
      final shared = [for (final c in sourceColors) if (targetColors.contains(c)) c];
      edges.add(SceneEdge(
        fromUuid: s.uuid,
        toUuid: targetUuid,
        colorIds: shared,
        kind: shared.isEmpty
            ? SceneEdgeKind.neutral
            : (shared.length >= 2
                ? SceneEdgeKind.parallel
                : SceneEdgeKind.single),
      ));
    }
  }

  final inUse = [
    for (final p in paths)
      if (usedColors.contains(p.colorId)) p.colorId,
  ];

  return SceneGraphModel(
    nodes: nodes,
    edges: edges,
    pathColorIdsInUse: inUse,
    warnings: warnings,
  );
}
