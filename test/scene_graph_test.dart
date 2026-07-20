import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/scenes/scenes_controller.dart' show ScenePathRef;
import 'package:living_scroll/visibility/visibility_rules.dart';
import 'package:living_scroll/widgets/scene_map/scene_graph.dart';

/// Scene uuids used by the fixture, for readable assertions.
const s1 = '00000000-0000-0000-0000-000000000001'; // start, Red
const s2 = '00000000-0000-0000-0000-000000000002'; // Red+Blue interchange
const s3 = '00000000-0000-0000-0000-000000000003'; // Red+Blue interchange
const s4 = '00000000-0000-0000-0000-000000000004'; // end, Blue, vis(and ke1)
const s5 = '00000000-0000-0000-0000-000000000005'; // Green, inactive, visited
const s6 = '00000000-0000-0000-0000-000000000006'; // recurring, Green+Yellow
const s7 = '00000000-0000-0000-0000-000000000007'; // Green
const s8 = '00000000-0000-0000-0000-000000000008'; // Yellow, vis(or ke1,ke2)
const s9 = '00000000-0000-0000-0000-000000000009'; // Yellow
const s10 = '00000000-0000-0000-0000-000000000010'; // end, Yellow
const dangling = '00000000-0000-0000-0000-0000000000ff';

const ke1 = '000000ke-0000-0000-0000-0000000000e1';
const ke2 = '000000ke-0000-0000-0000-0000000000e2';

(List<Scene>, List<ScenePathRef>) _load() {
  final doc = jsonDecode(
          File('test/fixtures/scene_map/adventure.json').readAsStringSync())
      as Map<String, dynamic>;
  final scenes = [
    for (final s in (doc['scenes'] as List)) Scene.fromJson(s as Map),
  ];
  final paths = <ScenePathRef>[
    for (final p in (doc['paths'] as List))
      (colorId: (p as Map)['color'] as String, name: p['name'] as String),
  ];
  return (scenes, paths);
}

SceneNode _node(SceneGraphModel m, String uuid) =>
    m.nodes.firstWhere((n) => n.uuid == uuid);

bool _hasEdge(SceneGraphModel m, String from, String to) =>
    m.edges.any((e) => e.fromUuid == from && e.toUuid == to);

SceneEdge _edge(SceneGraphModel m, String from, String to) =>
    m.edges.firstWhere((e) => e.fromUuid == from && e.toUuid == to);

void main() {
  late List<Scene> scenes;
  late List<ScenePathRef> paths;

  setUp(() {
    final loaded = _load();
    scenes = loaded.$1;
    paths = loaded.$2;
  });

  group('graph construction (game mode)', () {
    test('node count == scene count and keys are scene_uuids', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(m.nodes.length, scenes.length);
      expect(
        m.nodes.map((n) => n.uuid).toSet(),
        scenes.map((s) => s.uuid).toSet(),
      );
    });

    test('every valid next_scenes link has a matching directed edge', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(_hasEdge(m, s1, s2), isTrue);
      expect(_hasEdge(m, s3, s4), isTrue);
      expect(_hasEdge(m, s3, s5), isTrue);
      expect(_hasEdge(m, s7, s6), isTrue); // back-edge into recurring
      expect(_hasEdge(m, s9, s10), isTrue);
      // 11 next_scenes entries listed, one of them dangling -> 10 real edges.
      expect(m.edges.length, 10);
    });
  });

  group('edge colour classification', () {
    test('single shared line -> single, coloured by the shared path', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      final e = _edge(m, s1, s2);
      expect(e.kind, SceneEdgeKind.single);
      expect(e.colorIds, ['red']);
    });

    test('two shared lines -> parallel', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      final e = _edge(m, s2, s3);
      expect(e.kind, SceneEdgeKind.parallel);
      expect(e.colorIds.toSet(), {'red', 'blue'});
    });

    test('no shared line -> neutral with no colours', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      final e = _edge(m, s3, s5); // Red+Blue -> Green
      expect(e.kind, SceneEdgeKind.neutral);
      expect(e.colorIds, isEmpty);
    });
  });

  group('station shape from scene_type', () {
    test('start / standard / recurring / end', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(_node(m, s1).shape, SceneShape.start);
      expect(_node(m, s2).shape, SceneShape.standard);
      expect(_node(m, s6).shape, SceneShape.recurring);
      expect(_node(m, s4).shape, SceneShape.end);
      expect(_node(m, s10).shape, SceneShape.end);
    });
  });

  group('interchange detection (>=2 lines)', () {
    test('nodes on two lines are interchanges, single-line ones are not', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(_node(m, s2).interchange, isTrue); // Red+Blue
      expect(_node(m, s3).interchange, isTrue); // Red+Blue
      expect(_node(m, s6).interchange, isTrue); // Green+Yellow
      expect(_node(m, s1).interchange, isFalse); // Red only
      expect(_node(m, s9).interchange, isFalse); // Yellow only
    });
  });

  group('inactive state', () {
    test('state:inactive is flagged on the node', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(_node(m, s5).inactive, isTrue);
      expect(_node(m, s1).inactive, isFalse);
    });
  });

  group('visibility filter (pure)', () {
    test('empty rule is always visible', () {
      expect(isSceneVisible(const VisibilityRules(), const {}), isTrue);
    });

    test('AND requires all listed key events checked', () {
      const rule = VisibilityRules(op: VisibilityOp.and, keyEvents: [ke1, ke2]);
      expect(isSceneVisible(rule, const {}), isFalse);
      expect(isSceneVisible(rule, {ke1}), isFalse);
      expect(isSceneVisible(rule, {ke1, ke2}), isTrue);
    });

    test('OR requires at least one listed key event checked', () {
      const rule = VisibilityRules(op: VisibilityOp.or, keyEvents: [ke1, ke2]);
      expect(isSceneVisible(rule, const {}), isFalse);
      expect(isSceneVisible(rule, {ke2}), isTrue);
    });
  });

  group('play mode: visibility hides scenes', () {
    test('unsatisfied rules drop the node and its edges; satisfied keep them',
        () {
      final hidden = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.play,
          checkedKeyEvents: const {});
      // s4 (AND ke1) and s8 (OR ke1/ke2) are gated -> hidden with nothing checked.
      expect(hidden.nodes.any((n) => n.uuid == s4), isFalse);
      expect(hidden.nodes.any((n) => n.uuid == s8), isFalse);
      expect(_hasEdge(hidden, s3, s4), isFalse);
      expect(_hasEdge(hidden, s8, s9), isFalse);

      final shown = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.play,
          checkedKeyEvents: const {ke1});
      expect(shown.nodes.any((n) => n.uuid == s4), isTrue);
      expect(shown.nodes.any((n) => n.uuid == s8), isTrue);
    });
  });

  group('play mode: visited / recurring', () {
    test('a visited non-recurring scene is not offered as a next scene', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.play,
          checkedKeyEvents: const {ke1, ke2});
      // s5 is visited -> the s3 -> s5 "next" edge is dropped.
      expect(_hasEdge(m, s3, s5), isFalse);
      // No edge anywhere targets a visited non-recurring scene.
      expect(m.edges.any((e) => e.toUuid == s5), isFalse);
    });

    test('a recurring scene never disappears and stays a valid next target', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.play,
          checkedKeyEvents: const {ke1, ke2});
      expect(m.nodes.any((n) => n.uuid == s6), isTrue);
      expect(_hasEdge(m, s7, s6), isTrue);
    });
  });

  group('game mode: ignores visibility/visited, marks conditional', () {
    test('all scenes shown regardless of gates or visited', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(m.nodes.length, 10);
      expect(m.nodes.any((n) => n.uuid == s4), isTrue);
      expect(m.nodes.any((n) => n.uuid == s8), isTrue);
      expect(_hasEdge(m, s3, s5), isTrue); // visited target still shown
    });

    test('scenes with a visibility rule are flagged conditional', () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(_node(m, s4).conditional, isTrue);
      expect(_node(m, s8).conditional, isTrue);
      expect(_node(m, s1).conditional, isFalse);
    });
  });

  group('defensive: dangling next_scenes', () {
    test('a next link to a non-existent scene never crashes and is recorded',
        () {
      final m = buildSceneGraph(
          scenes: scenes, paths: paths, mode: SceneMapMode.game);
      expect(m.edges.any((e) => e.toUuid == dangling), isFalse);
      expect(m.warnings, isNotEmpty);
      expect(m.warnings.any((w) => w.contains(dangling)), isTrue);
    });
  });

  group('empty input', () {
    test('no scenes -> empty model', () {
      final m = buildSceneGraph(
          scenes: const [], paths: const [], mode: SceneMapMode.game);
      expect(m.isEmpty, isTrue);
      expect(m.nodes, isEmpty);
      expect(m.edges, isEmpty);
    });
  });
}
