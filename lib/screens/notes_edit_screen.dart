import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../l10n/app_localizations.dart';
import '../notes/note_content.dart';
import '../notes/note_image_embed.dart';
import '../notes/notes_controller.dart';
import '../widgets/visibility_rules_editor.dart';
import 'note_image_picker_dialog.dart';

/// Warns that a note's title must be unique. Shared by the editor's Save and the
/// rail guard's Save so both reject a duplicate title with the same prompt.
Future<void> showNotesNameNotUniqueDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('notes.name.not.unique.dialog'),
      content: Text(l10n.notesNameNotUnique),
      actions: [
        FilledButton(
          key: const ValueKey('notes.name.not.unique.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

/// The note edit form: note name + a height-filling
/// rich-text content editor on the left, the visibility_rules editor on the
/// right, and Cancel / Save pinned to the bottom.
///
/// The content is authored with `flutter_quill`: a formatting toolbar plus an
/// "insert image" button that embeds an adventure image or NPC portrait. The
/// body is stored as a Quill Delta (see [storedFromDocument]).
///
/// Bound to the shared [NotesController] (owned by the game shell). Save commits
/// via [onSave]; Cancel discards via [onCancel].
class NotesEditScreen extends StatefulWidget {
  const NotesEditScreen({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final NotesController controller;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  State<NotesEditScreen> createState() => _NotesEditScreenState();
}

class _NotesEditScreenState extends State<NotesEditScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.editName,
  );
  late final QuillController _content = QuillController(
    document: documentFromStored(widget.controller.editContent),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final FocusNode _contentFocus = FocusNode();
  final ScrollController _contentScroll = ScrollController();

  NotesController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
    // Mirror every edit of the rich body back into the model (Delta JSON), so
    // dirty tracking and Save see the latest content.
    _content.document.changes.listen((_) {
      _model.editContent = storedFromDocument(_content.document);
    });
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _name.dispose();
    _content.dispose();
    _contentFocus.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  // Rebuild so Save enablement and the visibility editor track the model.
  void _onModelChanged() => setState(() {});

  Future<void> _handleSave() async {
    if (!_model.isNameUnique(_model.editName)) {
      await showNotesNameNotUniqueDialog(context);
      return;
    }
    await widget.onSave();
  }

  /// Opens the image picker (adventure images + NPC portraits) and inserts the
  /// chosen image as an embed at the current cursor position.
  Future<void> _insertImage() async {
    final picked = await showNoteImagePicker(context, _model.media);
    if (picked == null) return;
    final index = _content.selection.baseOffset.clamp(
      0,
      _content.document.length,
    );
    final length =
        (_content.selection.extentOffset - _content.selection.baseOffset).clamp(
          0,
          _content.document.length,
        );
    _content.replaceText(
      index,
      length,
      BlockEmbed.image(picked.reference),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT — note name then a height-filling rich-text editor.
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey('game.notes.edit.field.name'),
                        controller: _name,
                        onChanged: (v) => _model.editName = v,
                        decoration: InputDecoration(
                          labelText: l10n.notesNameLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Formatting toolbar + an "insert image" button.
                      Row(
                        children: [
                          Expanded(
                            child: QuillSimpleToolbar(
                              controller: _content,
                              config: const QuillSimpleToolbarConfig(
                                showFontFamily: false,
                                showFontSize: false,
                                showSearchButton: false,
                                multiRowsDisplay: false,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey(
                              'game.notes.edit.content.image',
                            ),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            tooltip: l10n.notesInsertImage,
                            onPressed: _insertImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          key: const ValueKey('game.notes.edit.field.content'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outline),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: QuillEditor(
                            controller: _content,
                            focusNode: _contentFocus,
                            scrollController: _contentScroll,
                            config: QuillEditorConfig(
                              placeholder: l10n.notesContentLabel,
                              embedBuilders: [
                                NoteImageEmbedBuilder(_model.mediaFile),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('game.notes.edit.cancel'),
                onPressed: widget.onCancel,
                child: Text(l10n.unsavedCancel),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('game.notes.edit.save'),
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
