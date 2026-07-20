import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visibility/visibility_rules.dart';

/// Reusable `visibility_rules` editor: an All/Any
/// (AND/OR) operator over a flat, multi-select set of the adventure's
/// key_events.
///
/// Controlled: it renders [value] and emits a new [VisibilityRules] through
/// [onChanged]; the host entity owns the value and persists it via its own Save.
class VisibilityRulesEditor extends StatelessWidget {
  const VisibilityRulesEditor({
    super.key,
    required this.value,
    required this.availableKeyEvents,
    required this.onChanged,
    this.showTitle = true,
  });

  final VisibilityRules value;

  /// Whether to render the built-in "Visibility rules" heading. Hosts that
  /// already label the section (e.g. the scene editor's section divider) pass
  /// false to avoid duplicating the text.
  final bool showTitle;

  /// The adventure's key_events (uuid + name), in document order. Rows are shown
  /// and keyed by name; ticking one stores its uuid in the rule.
  final List<KeyEventRef> availableKeyEvents;

  final ValueChanged<VisibilityRules> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('vis.root'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          Text(
            l10n.visibilityRulesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        // Operator radio: All satisfied (AND) / Any satisfied (OR).
        RadioGroup<VisibilityOp>(
          groupValue: value.op,
          onChanged: (op) {
            if (op != null) onChanged(value.withOp(op));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile<VisibilityOp>(
                key: const ValueKey('vis.op.all'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: VisibilityOp.and,
                title: Text(l10n.visibilityRulesAnd),
              ),
              RadioListTile<VisibilityOp>(
                key: const ValueKey('vis.op.any'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: VisibilityOp.or,
                title: Text(l10n.visibilityRulesOr),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (availableKeyEvents.isEmpty)
          Text(
            l10n.visibilityRulesNoEvents,
            key: const ValueKey('vis.no_events'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (final event in availableKeyEvents)
            CheckboxListTile(
              key: ValueKey('vis.event.${event.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: value.contains(event.uuid),
              onChanged: (_) => onChanged(value.toggle(event.uuid)),
              title: Text(event.name),
            ),
          if (value.isEmpty)
            Text(
              l10n.visibilityRulesAlwaysVisible,
              key: const ValueKey('vis.empty'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}
