import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../notes/note.dart';
import '../notes/note_content.dart';
import '../notes/notes_controller.dart';
import '../widgets/note_tile.dart';
import 'notes_edit_screen.dart';

/// The in-game Notes section. Same shape as the Key events
/// section: a search bar pinned to the top filters the list below it live
/// (matching the note title or content); row 0 is the "Add note" action, the rest
/// are [NoteTile]s. Tapping a tile opens the note editor
/// in place; the tile's delete icon asks for confirmation before removing the note.
///
/// State lives on the shared [NotesController] (owned by the game shell);
/// [onPersist] writes the notes back to LivingScroll.json after a Save / delete.
/// The search query is local view state (it does not persist).
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.controller,
    required this.onPersist,
    this.readOnly = false,
  });

  final NotesController controller;
  final Future<void> Function() onPersist;

  /// Save-content editing: immutable base notes are frozen
  /// (no open, no delete); new notes stay editable.
  final bool readOnly;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  NotesController get controller => widget.controller;
  Future<void> Function() get onPersist => widget.onPersist;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Empties the search field and restores the full list.
  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  /// Notes whose title or content contains the (trimmed, case-insensitive)
  /// query. Content is matched on the note's visible plain text (the rich body
  /// is stored as a Quill Delta). An empty query matches everything.
  List<Note> get _visibleNotes {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return controller.notes;
    return [
      for (final n in controller.notes)
        if (n.name.toLowerCase().contains(q) ||
            plainTextFromStored(n.content).toLowerCase().contains(q))
          n,
    ];
  }

  Future<void> _confirmDelete(BuildContext context, Note note) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('note.delete.dialog'),
        title: Text(note.name),
        content: Text(l10n.notesDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('note.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('note.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.notesDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.delete(note.uuid);
      await onPersist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEditing) {
          return NotesEditScreen(
            controller: controller,
            onSave: () async {
              if (controller.save()) await onPersist();
            },
            onCancel: controller.cancelEdit,
          );
        }
        return _section(context);
      },
    );
  }

  /// The search bar pinned to the top, then the filtered list below it.
  Widget _section(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: TextField(
            key: const ValueKey('note.search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.notesSearchHint,
              border: const OutlineInputBorder(),
              // A clear button appears once there is something to clear.
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('note.search.clear'),
                      icon: const Icon(Icons.cancel),
                      tooltip: l10n.notesSearchClear,
                      onPressed: _clearSearch,
                    ),
            ),
          ),
        ),
        Expanded(child: _list(context)),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final notes = _visibleNotes;

    return ListView.separated(
      key: const ValueKey('note.list'),
      padding: const EdgeInsets.all(24),
      itemCount: notes.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('note.new'),
              onTap: controller.beginNew,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Tooltip(
                    message: l10n.notesAddLabel,
                    child: Icon(
                      Icons.note_add_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final note = notes[index - 1];
        return NoteTile(
          uuid: note.uuid,
          name: note.name,
          onTap: () => controller.beginEdit(note.uuid),
          onDelete: () => _confirmDelete(context, note),
          locked: widget.readOnly && note.immutable,
        );
      },
    );
  }
}
