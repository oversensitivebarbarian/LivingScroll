import 'dart:io';

import 'package:flutter/material.dart';

import '../images/images_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/file_picker_service.dart';
import '../widgets/visibility_rules_editor.dart';

/// The Images add/edit form. Two columns over an actions bar:
///   - ADD mode (new image): the left is a REQUIRED, active image picker; the
///     commit button is [Add] (`game.images.edit.add`), enabled once an image is
///     picked.
///   - EDIT mode (existing image): the left shows the current image DISABLED (no
///     picker); only the visibility gate is editable; the commit button is [Save]
///     (`game.images.edit.save`).
///
/// Bound to the shared [ImagesController]. Commit goes through [onCommit] (the
/// game shell writes a staged image / updates the rule and persists); Cancel
/// discards via [onCancel].
class ImageFormScreen extends StatefulWidget {
  const ImageFormScreen({
    super.key,
    required this.controller,
    required this.imagesBasePath,
    required this.onCommit,
    required this.onCancel,
  });

  final ImagesController controller;

  /// Absolute path to `images/other/` (to show the current image in EDIT mode).
  final String imagesBasePath;

  final Future<void> Function() onCommit;
  final VoidCallback onCancel;

  @override
  State<ImageFormScreen> createState() => _ImageFormScreenState();
}

class _ImageFormScreenState extends State<ImageFormScreen> {
  ImagesController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    super.dispose();
  }

  void _onModelChanged() => setState(() {});

  Future<void> _pick() async {
    final path = await FilePickerService.instance.pickImage();
    if (path == null) return;
    _model.pickImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isNew = _model.isNew;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT — the image (active picker in ADD, read-only in EDIT).
                Expanded(child: _imageColumn(context, l10n, scheme, isNew)),
                const SizedBox(width: 24),
                // RIGHT — the visibility gate.
                Expanded(
                  child: SingleChildScrollView(
                    child: VisibilityRulesEditor(
                      value: _model.editVisibility,
                      availableKeyEvents: _model.keyEvents,
                      onChanged: (v) => _model.editVisibility = v,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Actions bar spanning both columns: commit then Cancel.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              isNew
                  ? FilledButton(
                      key: const ValueKey('game.images.edit.add'),
                      onPressed: _model.canSave ? widget.onCommit : null,
                      child: Text(l10n.imagesAddButton),
                    )
                  : FilledButton(
                      key: const ValueKey('game.images.edit.save'),
                      onPressed: _model.canSave ? widget.onCommit : null,
                      child: Text(l10n.settingsSave),
                    ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const ValueKey('game.images.edit.cancel'),
                onPressed: widget.onCancel,
                child: Text(l10n.unsavedCancel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageColumn(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    bool isNew,
  ) {
    Widget card(Widget child) => Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (!isNew) {
      // EDIT — the current image, read-only (no picker).
      final file = File('${widget.imagesBasePath}/${_model.editingUuid}.png');
      return card(
        Image.file(
          file,
          key: const ValueKey('game.images.edit.image.preview'),
          fit: BoxFit.contain,
        ),
      );
    }

    // ADD — the active picker.
    final source = _model.editImageSource;
    return card(
      InkWell(
        key: const ValueKey('game.images.edit.image'),
        onTap: _pick,
        child: source == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.imagesPickLabel,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : Image.file(
                File(source),
                key: const ValueKey('game.images.edit.image.preview'),
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
