import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/visibility/visibility_rules.dart';

void main() {
  test('defaults to AND, empty, and serializes to null', () {
    const rules = VisibilityRules();
    expect(rules.op, VisibilityOp.and);
    expect(rules.isEmpty, isTrue);
    expect(rules.toJson(), isNull); // empty collapses to null on save
  });

  test('fromJson parses op and key_events; tolerates junk', () {
    final rules = VisibilityRules.fromJson({
      'op': 'or',
      'key_events': ['Met the duke', 'Found the map', 42],
    });
    expect(rules.op, VisibilityOp.or);
    expect(rules.keyEvents, ['Met the duke', 'Found the map']); // 42 dropped
  });

  test('fromJson on null/absent or bad shape yields the default', () {
    expect(VisibilityRules.fromJson(null), const VisibilityRules());
    expect(VisibilityRules.fromJson('nope'), const VisibilityRules());
    // Unknown op falls back to AND.
    expect(VisibilityRules.fromJson({'op': 'xor'}).op, VisibilityOp.and);
  });

  test('toJson round-trips a non-empty rule', () {
    const rules = VisibilityRules(
        op: VisibilityOp.or, keyEvents: ['A', 'B']);
    final json = rules.toJson();
    expect(json, {'op': 'or', 'key_events': ['A', 'B']});
    expect(VisibilityRules.fromJson(json), rules);
  });

  test('toggle adds then removes an event, preserving order', () {
    const rules = VisibilityRules();
    final withA = rules.toggle('A');
    final withAB = withA.toggle('B');
    expect(withAB.keyEvents, ['A', 'B']);

    final withoutA = withAB.toggle('A');
    expect(withoutA.keyEvents, ['B']);
    expect(withoutA.contains('A'), isFalse);
  });

  test('withOp changes the operator and keeps the events', () {
    const rules = VisibilityRules(keyEvents: ['A']);
    final or = rules.withOp(VisibilityOp.or);
    expect(or.op, VisibilityOp.or);
    expect(or.keyEvents, ['A']);
  });
}
