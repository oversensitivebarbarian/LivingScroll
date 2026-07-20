import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../paths/path_colors.dart';
import '../paths/paths_controller.dart';

/// The path edit form: a narrow colour column on the
/// left (just the path's disc) and, on the right, the Name and a height-filling
/// Description field with a Save button pinned to the bottom.
///
/// Bound to the shared [PathsController] (owned by the game shell) so the shell's
/// navigation guard can read [PathsController.isDirty]. Save commits via
/// [onSave] and returns to the Paths grid — unless
/// [PathsController.nameRequiredButEmpty] rejects it first (a path
/// referenced by a scene cannot be saved with a blank name).
class PathsEditScreen extends StatefulWidget {
  const PathsEditScreen({
    super.key,
    required this.controller,
    required this.color,
    required this.onSave,
  });

  final PathsController controller;
  final PathColorDef color;
  final VoidCallback onSave;

  @override
  State<PathsEditScreen> createState() => _PathsEditScreenState();
}

class _PathsEditScreenState extends State<PathsEditScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.editName,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.controller.editDescription,
  );

  PathsController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  // Keep the fields in step when the model changes outside of typing (e.g. the
  // guard's Save/Abandon) and rebuild so Save enablement tracks isDirty().
  void _onModelChanged() {
    void sync(TextEditingController c, String v) {
      if (c.text != v) c.value = TextEditingValue(text: v);
    }

    sync(_name, _model.editName);
    sync(_description, _model.editDescription);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT — narrow column, just the path's colour disc at the top.
          SizedBox(
            width: 96,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                key: const ValueKey('game.paths.edit.swatch'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.color,
                  border: Border.all(
                    width: 3,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // RIGHT — name, then a height-filling description, then Save.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('game.paths.edit.field.name'),
                  controller: _name,
                  onChanged: (v) => _model.editName = v,
                  decoration: InputDecoration(
                    labelText: l10n.pathEditNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    key: const ValueKey('game.paths.edit.field.description'),
                    controller: _description,
                    onChanged: (v) => _model.editDescription = v,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: l10n.createNewDescriptionLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      key: const ValueKey('game.paths.edit.save'),
                      onPressed: _model.canSave ? _handleSave : null,
                      child: Text(l10n.settingsSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_model.nameRequiredButEmpty) {
      await showPathNameRequiredDialog(context);
      return;
    }
    widget.onSave();
  }
}

/// Warns that a path referenced by a scene's `path_names` needs a name.
/// Shared by the editor's Save and the rail guard's Save.
Future<void> showPathNameRequiredDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('paths.name.required.dialog'),
      content: Text(l10n.pathNameRequired),
      actions: [
        FilledButton(
          key: const ValueKey('paths.name.required.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}
