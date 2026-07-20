import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';
import 'package:living_scroll/widgets/scene_map/scene_map_layout.dart';

SceneMapLayout _layout(Set<String> starts, Set<String> ends) => SceneMapLayout(
      SugiyamaConfiguration()
        ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
        ..nodeSeparation = 30
        ..levelSeparation = 60,
      startUuids: starts,
      endUuids: ends,
      rowSpacing: 150,
    );

double _cx(Node n) => n.x + n.width / 2;

void main() {
  test('start scenes form a top row, end scenes a bottom row, both centred', () {
    final graph = Graph();
    Node mk(String id) {
      final n = Node.Id(id)..size = const Size(120, 40);
      graph.addNode(n);
      return n;
    }

    final a = mk('start-A');
    final b = mk('start-B');
    final c = mk('body-C');
    final d = mk('body-D');
    final e = mk('end-E');
    final f = mk('end-F');
    graph.addEdge(a, c);
    graph.addEdge(b, c);
    graph.addEdge(c, d);
    graph.addEdge(d, e);
    graph.addEdge(d, f);

    _layout({'start-A', 'start-B'}, {'end-E', 'end-F'}).run(graph, 0, 0);

    // Each terminus group shares one row (same Y).
    expect(a.y, closeTo(b.y, 0.001));
    expect(e.y, closeTo(f.y, 0.001));

    // Starts are above the whole body; ends are below it.
    expect(a.y, lessThan(c.y));
    expect(a.y, lessThan(d.y));
    expect(e.y, greaterThan(c.y));
    expect(e.y, greaterThan(d.y));

    // Fixed centre-to-centre spacing within each row.
    final starts = [a, b]..sort((x, y) => x.x.compareTo(y.x));
    expect(_cx(starts[1]) - _cx(starts[0]), closeTo(150, 0.001));
    final ends = [e, f]..sort((x, y) => x.x.compareTo(y.x));
    expect(_cx(ends[1]) - _cx(ends[0]), closeTo(150, 0.001));

    // Both rows are centred on the same vertical axis.
    final startMid = (_cx(starts[0]) + _cx(starts[1])) / 2;
    final endMid = (_cx(ends[0]) + _cx(ends[1])) / 2;
    expect(startMid, closeTo(endMid, 0.001));
  });

  test('variant 1: body scenes group into one column per path colour', () {
    // start -> r1 -> r2 -> end  (red line)
    // start -> b1 -> b2 -> end  (blue line)
    final graph = Graph();
    Node mk(String id) {
      final n = Node.Id(id)..size = const Size(120, 40);
      graph.addNode(n);
      return n;
    }

    final s = mk('start');
    final r1 = mk('r1');
    final r2 = mk('r2');
    final b1 = mk('b1');
    final b2 = mk('b2');
    final e = mk('end');
    graph.addEdge(s, r1);
    graph.addEdge(r1, r2);
    graph.addEdge(r2, e);
    graph.addEdge(s, b1);
    graph.addEdge(b1, b2);
    graph.addEdge(b2, e);

    SceneMapLayout(
      SugiyamaConfiguration()
        ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
        ..nodeSeparation = 30
        ..levelSeparation = 60,
      startUuids: {'start'},
      endUuids: {'end'},
      columnOrder: const ['red', 'blue'],
      primaryColorByUuid: const {
        'r1': 'red',
        'r2': 'red',
        'b1': 'blue',
        'b2': 'blue',
      },
      columnSpacing: 180,
    ).run(graph, 0, 0);

    // Same path -> same column (identical X); different paths -> different columns.
    expect(_cx(r1), closeTo(_cx(r2), 0.001));
    expect(_cx(b1), closeTo(_cx(b2), 0.001));
    expect(_cx(r1), isNot(closeTo(_cx(b1), 0.001)));
    // Fixed spacing between the two columns.
    expect((_cx(b1) - _cx(r1)).abs(), closeTo(180, 0.001));
  });

  test('variant 1: same-column same-layer scenes are spread, not overlapped', () {
    // start -> a, start -> b (both red, both on layer 1 -> same Y).
    final graph = Graph();
    Node mk(String id) {
      final n = Node.Id(id)..size = const Size(120, 40);
      graph.addNode(n);
      return n;
    }

    final s = mk('start');
    final a = mk('a');
    final b = mk('b');
    final e = mk('end');
    graph.addEdge(s, a);
    graph.addEdge(s, b);
    graph.addEdge(a, e);
    graph.addEdge(b, e);

    SceneMapLayout(
      SugiyamaConfiguration()
        ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
        ..levelSeparation = 60,
      startUuids: {'start'},
      endUuids: {'end'},
      columnOrder: const ['red'],
      primaryColorByUuid: const {'a': 'red', 'b': 'red'},
      columnSpacing: 180,
    ).run(graph, 0, 0);

    expect(a.y, closeTo(b.y, 0.001)); // same layer
    expect((_cx(a) - _cx(b)).abs(), greaterThan(1)); // but spread apart
  });

  test('an end scene reachable early is still pinned to the bottom row', () {
    // A -> earlyEnd, A -> B -> lateEnd. Without the override the early end would
    // sit on layer 1 (mid-graph); it must land on the same bottom row as lateEnd.
    final graph = Graph();
    Node mk(String id) {
      final n = Node.Id(id)..size = const Size(120, 40);
      graph.addNode(n);
      return n;
    }

    final a = mk('start');
    final b = mk('body');
    final early = mk('end-early');
    final late = mk('end-late');
    graph.addEdge(a, early);
    graph.addEdge(a, b);
    graph.addEdge(b, late);

    _layout({'start'}, {'end-early', 'end-late'}).run(graph, 0, 0);

    expect(early.y, closeTo(late.y, 0.001));
    expect(early.y, greaterThan(b.y));
    expect(a.y, lessThan(b.y));
  });
}
