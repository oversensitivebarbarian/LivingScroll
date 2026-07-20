import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/visibility/visibility_rules.dart';
import 'package:living_scroll/widgets/visibility_rules_editor.dart';

/// Stateful host so the controlled editor reflects its emitted value.
class _Host extends StatefulWidget {
  const _Host({required this.events, this.initial = const VisibilityRules()});

  final List<KeyEventRef> events;
  final VisibilityRules initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late VisibilityRules value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: VisibilityRulesEditor(
          value: value,
          availableKeyEvents: widget.events,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    );
  }
}

// Events whose uuid differs from their name, so the test can prove the row is
// keyed/labelled by NAME while the rule stores the UUID.
const _events = <KeyEventRef>[
  (uuid: 'u-a', name: 'A'),
  (uuid: 'u-b', name: 'B'),
  (uuid: 'u-c', name: 'C'),
];

void main() {
  _HostState host(WidgetTester tester) =>
      tester.state<_HostState>(find.byType(_Host));

  testWidgets('renders the operator and one checkbox per key event',
      (tester) async {
    await tester.pumpWidget(const _Host(events: _events));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vis.op.all')), findsOneWidget);
    expect(find.byKey(const ValueKey('vis.op.any')), findsOneWidget);
    // Rows are keyed by NAME (the form works in names).
    for (final name in ['A', 'B', 'C']) {
      expect(find.byKey(ValueKey('vis.event.$name')), findsOneWidget);
    }
    // Nothing selected -> the "always visible" hint, no "no events" hint.
    expect(find.byKey(const ValueKey('vis.empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('vis.no_events')), findsNothing);
  });

  testWidgets('ticking an event (by name) stores its UUID in the rule',
      (tester) async {
    await tester.pumpWidget(const _Host(events: _events));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vis.event.B')));
    await tester.pumpAndSettle();

    // The rule stores the UUID, not the name.
    expect(host(tester).value.keyEvents, ['u-b']);
    expect(find.byKey(const ValueKey('vis.empty')), findsNothing);

    // The checkbox (found by name) now reflects the selection.
    final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('vis.event.B')));
    expect(tile.value, isTrue);
  });

  testWidgets('a rule of UUIDs ticks the matching rows (looked up by uuid)',
      (tester) async {
    await tester.pumpWidget(const _Host(
        events: _events, initial: VisibilityRules(keyEvents: ['u-a'])));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('vis.event.A')))
            .value,
        isTrue);
    expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('vis.event.B')))
            .value,
        isFalse);
  });

  testWidgets('selecting OR updates the operator', (tester) async {
    await tester.pumpWidget(const _Host(
        events: _events, initial: VisibilityRules(keyEvents: ['u-a'])));
    await tester.pumpAndSettle();

    expect(host(tester).value.op, VisibilityOp.and);
    await tester.tap(find.byKey(const ValueKey('vis.op.any')));
    await tester.pumpAndSettle();
    expect(host(tester).value.op, VisibilityOp.or);
    expect(host(tester).value.keyEvents, ['u-a']); // events preserved
  });

  testWidgets('with no key events, shows the hint and no checkboxes',
      (tester) async {
    await tester.pumpWidget(const _Host(events: []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vis.no_events')), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const ValueKey('vis.empty')), findsNothing);
  });
}
