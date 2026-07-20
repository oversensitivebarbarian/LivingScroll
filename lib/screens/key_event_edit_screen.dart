import 'package:flutter/material.dart';

import '../keyevents/key_events_controller.dart';
import '../l10n/app_localizations.dart';

/// Warns that a key_event's name must be unique. Shared by the editor's Save and
/// the rail guard's Save so both reject a duplicate name with the same prompt.
Future<void> showKeyEventNameNotUniqueDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('keyevents.name.not.unique.dialog'),
      content: Text(l10n.keyEventsNameNotUnique),
      actions: [
        FilledButton(
          key: const ValueKey('keyevents.name.not.unique.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

/// The key-event edit form: just the event name,
/// with Cancel / Save pinned to the bottom. (name is the only authored field;
/// `state` is app-managed and not edited here.)
///
/// Bound to the shared [KeyEventsController] (owned by the game shell). Save
/// commits via [onSave] (only when the name is unique); Cancel discards via
/// [onCancel].
class KeyEventEditScreen extends StatefulWidget {
  const KeyEventEditScreen({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final KeyEventsController controller;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  State<KeyEventEditScreen> createState() => _KeyEventEditScreenState();
}

class _KeyEventEditScreenState extends State<KeyEventEditScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.editName,
  );

  KeyEventsController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _name.dispose();
    super.dispose();
  }

  // Rebuild so Save enablement tracks the model.
  void _onModelChanged() => setState(() {});

  Future<void> _handleSave() async {
    if (!_model.isNameUnique(_model.editName)) {
      await showKeyEventNameNotUniqueDialog(context);
      return;
    }
    await widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('game.keyevents.edit.field.name'),
            controller: _name,
            onChanged: (v) => _model.editName = v,
            decoration: InputDecoration(
              labelText: l10n.keyEventsNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('game.keyevents.edit.cancel'),
                onPressed: widget.onCancel,
                child: Text(l10n.unsavedCancel),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('game.keyevents.edit.save'),
                onPressed: _model.canSave ? _handleSave : null,
                child: Text(l10n.settingsSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
