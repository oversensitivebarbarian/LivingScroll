import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import 'scene_graph.dart';

/// Draws the scene graph's edges in a schematic "metro" style: thick, round-capped
/// coloured polylines (one per shared line), parallel offset ribbons when a
/// segment carries ≥2 lines, octolinear corners (0°/45°/90°) and a directional
/// arrowhead in the line colour (the graph is DIRECTED — unlike a real metro map).
/// A segment with no shared line is a thin neutral connector.
///
/// A line only ever touches its own stations: if a straight route would cross a
/// node that is NOT one of the edge's endpoints, the edge is rerouted through a
/// clear vertical channel (the gutter between columns) so it never runs over /
/// "right next to" an unrelated station (which made membership ambiguous).
///
/// graphview 1.5.1 paints edges per-edge via [renderEdge]; this subclass looks
/// up the matching [SceneEdge] by the source/destination node ids
/// (`Node.key.value`, set from `scene_uuid`).
class MetroEdgeRenderer extends EdgeRenderer {
  MetroEdgeRenderer({
    required this.edgeByPair,
    required this.resolveColor,
    required this.neutralColor,
    this.nodesProvider,
    this.activeColorId,
    this.laneStep = 180,
    this.obstacleMargin = 6,
  });

  /// Keyed `"<fromUuid>->{toUuid}"` → the model edge (colours + kind).
  final Map<String, SceneEdge> edgeByPair;
  final Color Function(String colorId) resolveColor;
  final Color neutralColor;

  /// Returns every laid-out node, so an edge can avoid crossing the ones that are
  /// not its own endpoints. Null disables obstacle avoidance.
  final List<Node> Function()? nodesProvider;

  /// When non-null, only this line is drawn at full opacity; others dim.
  String? activeColorId;

  /// Horizontal step used to pick detour channels (matches the column spacing).
  final double laneStep;

  /// How far node rectangles are inflated when testing for crossings — keeps the
  /// line a clear gap away, not "right next to" the node.
  final double obstacleMargin;

  static const double _lineWidth = 6;
  static const double _ribbonGap = 5;
  static const double _neutralWidth = 2;
  static const double _arrow = 9;

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final from = edge.source.key?.value;
    final to = edge.destination.key?.value;
    final model = (from is String && to is String)
        ? edgeByPair['$from->$to']
        : null;

    final c1 = getNodeCenter(edge.source);
    final c2 = getNodeCenter(edge.destination);

    // Obstacles = every OTHER node's (inflated) rectangle.
    final obstacles = <Rect>[];
    final provider = nodesProvider;
    if (provider != null) {
      for (final n in provider()) {
        if (identical(n, edge.source) || identical(n, edge.destination)) {
          continue;
        }
        final p = getNodePosition(n);
        obstacles.add(
            Rect.fromLTWH(p.dx, p.dy, n.width, n.height).inflate(obstacleMargin));
      }
    }

    final route = metroRoute(c1, c2, obstacles: obstacles, laneStep: laneStep);

    if (model == null || model.kind == SceneEdgeKind.neutral) {
      _drawRibbon(canvas, route, neutralColor, _neutralWidth, 0,
          dim: activeColorId != null);
      return;
    }

    final colors = model.colorIds;
    final n = colors.length;
    for (var i = 0; i < n; i++) {
      final colorId = colors[i];
      final offset = (i - (n - 1) / 2) * _ribbonGap;
      final dim = activeColorId != null && activeColorId != colorId;
      _drawRibbon(canvas, route, resolveColor(colorId), _lineWidth, offset,
          dim: dim);
    }
  }

  /// Draws one ribbon along [route], shifted perpendicular by [offset] (for
  /// parallel lines), with a round join and an arrowhead at the destination.
  void _drawRibbon(Canvas canvas, List<Offset> route, Color color, double width,
      double offset,
      {required bool dim}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = dim ? color.withValues(alpha: 0.2) : color;

    final perp = _perp(route.first, route.last) * offset;
    final shifted = [for (final p in route) p + perp];

    final path = Path()..moveTo(shifted.first.dx, shifted.first.dy);
    for (var i = 1; i < shifted.length; i++) {
      path.lineTo(shifted[i].dx, shifted[i].dy);
    }
    canvas.drawPath(path, paint);

    _drawArrow(canvas, shifted[shifted.length - 2], shifted.last,
        paint..style = PaintingStyle.fill);
  }

  Offset _perp(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return Offset.zero;
    return Offset(-d.dy / len, d.dx / len);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset tip, Paint paint) {
    final dir = tip - from;
    final len = dir.distance;
    if (len == 0) return;
    final u = Offset(dir.dx / len, dir.dy / len);
    // Pull the tip back to the node edge a touch so the head is not hidden.
    final t = tip - u * 2;
    final left = Offset(-u.dy, u.dx);
    final p1 = t;
    final p2 = t - u * _arrow + left * (_arrow * 0.55);
    final p3 = t - u * _arrow - left * (_arrow * 0.55);
    canvas.drawPath(
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close(),
      paint,
    );
  }
}

/// Octolinear route from [s] to [t] for the metro look. Pure (no canvas) so it
/// can be unit-tested.
///
/// The map is laid out top→bottom, so an edge leaves the source with a SHORT,
/// FIXED-LENGTH vertical [stub] first. Because the stub depends only on the
/// source (never on the target's horizontal distance), every edge fanning out of
/// the same node shares an identical trunk and DIVERGES AT THE SAME POINT. After
/// the stub comes a single 45° diagonal that absorbs the horizontal offset, then
/// a straight run into the target. All segments are 0° / 45° / 90°.
///
/// If that direct route would cross any rectangle in [obstacles] (other nodes),
/// the edge is rerouted through a clear vertical CHANNEL in the gutter between
/// columns — candidate channels are tried at increasing multiples of [laneStep]
/// to either side of the mid-line — so a line never runs over / beside a station
/// that is not its own. Falls back to the direct route if nothing is clear.
List<Offset> metroRoute(
  Offset s,
  Offset t, {
  double stub = 16,
  List<Rect> obstacles = const [],
  double laneStep = 180,
}) {
  final direct = _directRoute(s, t, stub);
  if (!routeHitsAny(direct, obstacles)) return direct;

  // The direct route is blocked: detour vertically through a clear channel.
  if ((t.dy - s.dy).abs() > stub * 2) {
    final mid = (s.dx + t.dx) / 2;
    for (final mag in const [0.5, 1.0, 1.5, 2.0, 2.5]) {
      for (final sign in const [1, -1]) {
        final route = _channelRoute(s, t, mid + sign * mag * laneStep, stub);
        if (!routeHitsAny(route, obstacles)) return route;
      }
    }
  }
  return direct; // nothing clear — keep the direct route rather than nothing
}

/// The direct stub → 45° diagonal → straight route (no obstacle handling).
List<Offset> _directRoute(Offset s, Offset t, double stub) {
  final dx = t.dx - s.dx;
  final dy = t.dy - s.dy;
  if (dx.abs() < 0.5 && dy.abs() < 0.5) return [s, t];

  if (dy.abs() >= 0.5) {
    final s2 = math.min(stub, dy.abs() / 2);
    final p1 = Offset(s.dx, s.dy + dy.sign * s2); // fixed vertical stub
    final remV = t.dy - p1.dy;
    final diag = math.min(dx.abs(), remV.abs());
    final p2 = Offset(s.dx + dx.sign * diag, p1.dy + remV.sign * diag);
    final pts = <Offset>[s, p1];
    if (p2 != p1) pts.add(p2);
    if (t != pts.last) pts.add(t);
    return pts;
  }

  final s2 = math.min(stub, dx.abs() / 2);
  final p1 = Offset(s.dx + dx.sign * s2, s.dy); // fixed horizontal stub
  final remH = t.dx - p1.dx;
  final diag = math.min(dy.abs(), remH.abs());
  final p2 = Offset(p1.dx + remH.sign * diag, s.dy + dy.sign * diag);
  final pts = <Offset>[s, p1];
  if (p2 != p1) pts.add(p2);
  if (t != pts.last) pts.add(t);
  return pts;
}

/// An orthogonal detour whose long vertical leg runs at [vx] (a gutter between
/// columns): short stub out of the source, across to the channel, down the
/// channel, across to the target column, short stub into the target.
List<Offset> _channelRoute(Offset s, Offset t, double vx, double stub) {
  final sy = (t.dy - s.dy).sign;
  final p1 = Offset(s.dx, s.dy + sy * stub);
  final p2 = Offset(vx, p1.dy);
  final p3 = Offset(vx, t.dy - sy * stub);
  final p4 = Offset(t.dx, p3.dy);
  final pts = <Offset>[s, p1, p2, p3, p4, t];
  // Drop any consecutive duplicate points (e.g. vx == a column x).
  final out = <Offset>[pts.first];
  for (final p in pts.skip(1)) {
    if ((p - out.last).distance > 0.001) out.add(p);
  }
  return out;
}

/// Whether any segment of [route] crosses [rect].
bool routeHitsRect(List<Offset> route, Rect rect) {
  for (var i = 1; i < route.length; i++) {
    if (_segmentHitsRect(route[i - 1], route[i], rect)) return true;
  }
  return false;
}

/// Whether [route] crosses any rectangle in [rects].
bool routeHitsAny(List<Offset> route, List<Rect> rects) {
  for (final r in rects) {
    if (routeHitsRect(route, r)) return true;
  }
  return false;
}

/// Liang–Barsky segment/rectangle overlap test (true if the segment enters the
/// rectangle at all).
bool _segmentHitsRect(Offset a, Offset b, Rect r) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final p = [-dx, dx, -dy, dy];
  final q = [a.dx - r.left, r.right - a.dx, a.dy - r.top, r.bottom - a.dy];
  var t0 = 0.0, t1 = 1.0;
  for (var i = 0; i < 4; i++) {
    if (p[i] == 0) {
      if (q[i] < 0) return false; // parallel and outside this edge
    } else {
      final tt = q[i] / p[i];
      if (p[i] < 0) {
        if (tt > t1) return false;
        if (tt > t0) t0 = tt;
      } else {
        if (tt < t0) return false;
        if (tt < t1) t1 = tt;
      }
    }
  }
  return t0 <= t1;
}
