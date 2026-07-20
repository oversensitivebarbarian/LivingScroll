import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

/// A Sugiyama layout tailored to the scene map.
///
/// It keeps Sugiyama's vertical layering (depth `Y`) but post-processes the
/// horizontal positions so the map reads as a set of metro LINES:
/// - **terminus rows** — every START scene sits in one row across the TOP and
///   every END scene in one row across the BOTTOM, each spread symmetrically
///   around the graph's horizontal centre at a fixed [rowSpacing];
/// - **path columns (variant 1)** — every BODY scene is snapped to the COLUMN of
///   its primary path colour ([columnOrder] gives the column order; spacing is
///   [columnSpacing]), so each storyline path forms a coherent vertical track.
///   Body scenes that would overlap (same column + same layer) are spread apart.
///
/// graphview's `SugiyamaAlgorithm.run` copies the graph but keeps the SAME [Node]
/// objects, so the positions it writes are visible on the graph we then
/// post-process; we move the nodes and re-normalise the canvas size.
class SceneMapLayout extends SugiyamaAlgorithm {
  SceneMapLayout(
    super.configuration, {
    required this.startUuids,
    required this.endUuids,
    this.columnOrder = const [],
    this.primaryColorByUuid = const {},
    this.rowSpacing = 150,
    this.columnSpacing = 180,
  });

  /// `scene_uuid`s of the start scenes (top row) and end scenes (bottom row).
  final Set<String> startUuids;
  final Set<String> endUuids;

  /// In-use path colour ids in declared order — one column each (variant 1). Empty
  /// disables column grouping (the body keeps Sugiyama's horizontal layout).
  final List<String> columnOrder;

  /// `scene_uuid` → its primary path colour id (the first line it sits on). Scenes
  /// absent here have no path and go to a trailing neutral column.
  final Map<String, String> primaryColorByUuid;

  /// Fixed centre-to-centre gap between adjacent termini in a row.
  final double rowSpacing;

  /// Fixed centre-to-centre gap between adjacent path columns.
  final double columnSpacing;

  static const String _neutralColumn = '__neutral__';

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    super.run(graph, shiftX, shiftY);
    if (graph == null) return const Size(0, 0);
    _groupByPath(graph);
    _arrangeTerminals(graph);
    return _normalize(graph);
  }

  /// Variant 1: snap each body scene onto the column of its primary path colour,
  /// keeping Sugiyama's `Y`. Body scenes sharing a column AND a layer are spread
  /// horizontally so they never overlap.
  void _groupByPath(Graph graph) {
    if (columnOrder.isEmpty) return;

    bool isTerminal(Node n) {
      final id = n.key?.value;
      return id is String && (startUuids.contains(id) || endUuids.contains(id));
    }

    final body = [for (final n in graph.nodes) if (!isTerminal(n)) n];
    if (body.isEmpty) return;

    String columnOf(Node n) {
      final id = n.key?.value;
      final c = id is String ? primaryColorByUuid[id] : null;
      return c != null && columnOrder.contains(c) ? c : _neutralColumn;
    }

    final columns = <String>[...columnOrder];
    if (body.any((n) => columnOf(n) == _neutralColumn)) {
      columns.add(_neutralColumn);
    }
    final index = {for (var i = 0; i < columns.length; i++) columns[i]: i};
    final k = columns.length;
    double centerOf(String col) => (index[col]! - (k - 1) / 2) * columnSpacing;

    for (final n in body) {
      n.position = Offset(centerOf(columnOf(n)) - n.width / 2, n.y);
    }

    // Overlap resolution: within a column, nodes on the same layer (same Y) get
    // fanned out around the column centre.
    final byColumn = <String, List<Node>>{};
    for (final n in body) {
      (byColumn[columnOf(n)] ??= []).add(n);
    }
    for (final entry in byColumn.entries) {
      final lanes = <int, List<Node>>{};
      for (final n in entry.value) {
        (lanes[n.y.round()] ??= []).add(n);
      }
      for (final group in lanes.values) {
        if (group.length < 2) continue;
        group.sort((a, b) => a.x.compareTo(b.x));
        final center = centerOf(entry.key);
        for (var i = 0; i < group.length; i++) {
          final cx = center + (i - (group.length - 1) / 2) * columnSpacing;
          group[i].position = Offset(cx - group[i].width / 2, group[i].y);
        }
      }
    }
  }

  void _arrangeTerminals(Graph graph) {
    final starts = <Node>[];
    final ends = <Node>[];
    final body = <Node>[];
    for (final n in graph.nodes) {
      final id = n.key?.value;
      if (id is String && startUuids.contains(id)) {
        starts.add(n);
      } else if (id is String && endUuids.contains(id)) {
        ends.add(n);
      } else {
        body.add(n);
      }
    }
    if (starts.isEmpty && ends.isEmpty) return;

    // Horizontal centre + vertical extent come from the body when present, else
    // from the termini themselves (Sugiyama's own positions).
    final basis = body.isNotEmpty ? body : [...starts, ...ends];
    var minCx = double.infinity, maxCx = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final n in basis) {
      final cx = n.x + n.width / 2;
      minCx = math.min(minCx, cx);
      maxCx = math.max(maxCx, cx);
      minY = math.min(minY, n.y);
      maxY = math.max(maxY, n.y + n.height);
    }
    final centerX = (minCx + maxCx) / 2;
    final gap = configuration.levelSeparation.toDouble();
    final startH = starts.isEmpty
        ? 0.0
        : starts.map((n) => n.height).fold(0.0, math.max);

    if (starts.isNotEmpty) {
      starts.sort((a, b) => a.x.compareTo(b.x));
      _layoutRow(starts, centerX, body.isNotEmpty ? minY - gap - startH : 0.0);
    }
    if (ends.isNotEmpty) {
      ends.sort((a, b) => a.x.compareTo(b.x));
      _layoutRow(ends, centerX, body.isNotEmpty ? maxY + gap : startH + gap);
    }
  }

  void _layoutRow(List<Node> row, double centerX, double y) {
    final n = row.length;
    for (var i = 0; i < n; i++) {
      final node = row[i];
      final cx = centerX + (i - (n - 1) / 2) * rowSpacing;
      node.position = Offset(cx - node.width / 2, y);
    }
  }

  /// Shifts every node so the graph starts at (0, 0) and returns the new size,
  /// so the moved terminus rows are never clipped by the InteractiveViewer canvas.
  Size _normalize(Graph graph) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final n in graph.nodes) {
      minX = math.min(minX, n.x);
      minY = math.min(minY, n.y);
      maxX = math.max(maxX, n.x + n.width);
      maxY = math.max(maxY, n.y + n.height);
    }
    if (minX == double.infinity) return const Size(0, 0);
    final dx = -minX, dy = -minY;
    if (dx != 0 || dy != 0) {
      for (final n in graph.nodes) {
        n.position = Offset(n.x + dx, n.y + dy);
      }
    }
    return Size(maxX - minX, maxY - minY);
  }
}
