import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/widgets/scene_map/metro_edge_renderer.dart';

bool _isOctolinear(List<Offset> route) {
  for (var i = 1; i < route.length; i++) {
    final d = route[i] - route[i - 1];
    if (d.distance < 0.001) continue;
    final deg = atan2(d.dy.abs(), d.dx.abs()) * 180 / pi;
    final ok = deg < 0.5 || (deg - 45).abs() < 0.5 || (deg - 90).abs() < 0.5;
    if (!ok) return false;
  }
  return true;
}

void main() {
  test('sibling edges leave the source with an identical stub', () {
    const src = Offset(100, 0);
    final left = metroRoute(src, const Offset(40, 120));
    final right = metroRoute(src, const Offset(240, 120));

    // Both start at the source...
    expect(left.first, src);
    expect(right.first, src);
    // ...and share the SAME divergence point (the stub end), regardless of how
    // far apart the two targets are horizontally.
    expect(left[1], right[1]);
    // The stub is vertical (same x as the source) and goes downward.
    expect(left[1].dx, closeTo(src.dx, 0.001));
    expect(left[1].dy, greaterThan(src.dy));
  });

  test('the divergence point does not drift with horizontal distance', () {
    const src = Offset(0, 0);
    final near = metroRoute(src, const Offset(10, 200));
    final far = metroRoute(src, const Offset(300, 200));
    expect(near[1].dy, closeTo(far[1].dy, 0.001)); // same branch height
  });

  test('a straight-down edge has no horizontal jog', () {
    final r = metroRoute(const Offset(50, 0), const Offset(50, 120));
    expect(r.every((p) => (p.dx - 50).abs() < 0.001), isTrue);
  });

  test('all segments are octolinear (0/45/90 degrees)', () {
    expect(_isOctolinear(metroRoute(const Offset(0, 0), const Offset(60, 200))),
        isTrue);
    expect(_isOctolinear(metroRoute(const Offset(0, 0), const Offset(300, 80))),
        isTrue);
    expect(
        _isOctolinear(metroRoute(const Offset(200, 0), const Offset(0, 150))),
        isTrue);
  });

  test('the route reaches the target', () {
    final r = metroRoute(const Offset(10, 10), const Offset(180, 260));
    expect(r.last, const Offset(180, 260));
  });

  group('obstacle avoidance', () {
    test('a route detours around a node that blocks the direct path', () {
      // Source above, target below, an unrelated node sitting right between them
      // on the straight vertical line.
      const s = Offset(0, 0);
      const t = Offset(0, 300);
      final blocker = Rect.fromCenter(
          center: const Offset(0, 150), width: 120, height: 40);

      // The direct route would cross the blocker...
      expect(routeHitsRect(metroRoute(s, t), blocker), isTrue);
      // ...but with the blocker as an obstacle the route avoids it.
      final route = metroRoute(s, t, obstacles: [blocker], laneStep: 180);
      expect(routeHitsRect(route, blocker), isFalse);
      // Still connects source to target.
      expect(route.first, s);
      expect(route.last, t);
    });

    test('the detour clears several stacked blockers', () {
      const s = Offset(0, 0);
      const t = Offset(0, 400);
      final blockers = [
        Rect.fromCenter(center: const Offset(0, 120), width: 120, height: 40),
        Rect.fromCenter(center: const Offset(0, 260), width: 120, height: 40),
      ];
      final route = metroRoute(s, t, obstacles: blockers, laneStep: 180);
      expect(routeHitsAny(route, blockers), isFalse);
      expect(route.last, t);
    });

    test('an unobstructed route is left as the clean direct route', () {
      const s = Offset(0, 0);
      const t = Offset(0, 200);
      final far = Rect.fromCenter(
          center: const Offset(400, 100), width: 120, height: 40);
      final route = metroRoute(s, t, obstacles: [far], laneStep: 180);
      // No detour: identical to the direct route.
      expect(route, metroRoute(s, t));
    });
  });
}
