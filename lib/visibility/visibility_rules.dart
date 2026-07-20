import 'package:flutter/foundation.dart';

/// How the listed key_events are combined.
enum VisibilityOp { and, or }

/// One adventure key_event offered by the rule editor: its durable [uuid]
/// (`key_event_uuid`, stored in the rule) paired with its [name] (shown to the
/// author). The form works in names; the rule stores uuids.
typedef KeyEventRef = ({String uuid, String name});

/// A GM-only visibility gate (`visibility_rules`): a flat set of
/// key_events combined by a single [op]. The host object appears in a scene when
/// the rule is satisfied; an empty rule means "always visible".
@immutable
class VisibilityRules {
  const VisibilityRules({
    this.op = VisibilityOp.and,
    this.keyEvents = const [],
  });

  final VisibilityOp op;

  /// key_event_uuids that participate in the rule, in selection order.
  /// References are by uuid (durable across renames), not by name.
  final List<String> keyEvents;

  /// No selected events => the object is always visible.
  bool get isEmpty => keyEvents.isEmpty;

  bool contains(String uuid) => keyEvents.contains(uuid);

  /// Parses a decoded `visibility_rules` value (a Map, or null/absent).
  factory VisibilityRules.fromJson(Object? json) {
    if (json is! Map) return const VisibilityRules();
    final op = json['op'] == 'or' ? VisibilityOp.or : VisibilityOp.and;
    final events = <String>[];
    final list = json['key_events'];
    if (list is List) {
      for (final e in list) {
        if (e is String) events.add(e);
      }
    }
    return VisibilityRules(op: op, keyEvents: List.unmodifiable(events));
  }

  /// The value written back to LivingScroll.json, or `null` when empty (the
  /// field is then omitted).
  Map<String, dynamic>? toJson() =>
      keyEvents.isEmpty ? null : {'op': op.name, 'key_events': keyEvents};

  VisibilityRules withOp(VisibilityOp newOp) =>
      VisibilityRules(op: newOp, keyEvents: keyEvents);

  /// Adds [uuid] to the rule when absent, removes it when present.
  VisibilityRules toggle(String uuid) {
    final next = [...keyEvents];
    if (!next.remove(uuid)) next.add(uuid);
    return VisibilityRules(op: op, keyEvents: List.unmodifiable(next));
  }

  @override
  bool operator ==(Object other) =>
      other is VisibilityRules &&
      other.op == op &&
      listEquals(other.keyEvents, keyEvents);

  @override
  int get hashCode => Object.hash(op, Object.hashAll(keyEvents));
}
