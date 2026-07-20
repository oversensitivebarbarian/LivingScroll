import 'package:flutter/material.dart' hide KeyEvent;

import '../keyevents/key_event.dart';
import '../keyevents/key_events_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/event_tile.dart';
import 'key_event_edit_screen.dart';

/// The in-game Key events section. A search bar pinned to the top filters the
/// list below live (matching the event name); row 0 is the "Add event"
/// action, the rest are [EventTile]s.
/// Tapping a tile opens the editor in place; the tile's delete icon asks for
/// confirmation, then cascade-deletes the event.
///
/// State lives on the shared [KeyEventsController] (owned by the game shell).
/// [onPersist] writes the events back to LivingScroll.json after a Save;
/// [onDeleteEvent] performs the on-disk cascade delete (and refresh). The search
/// query is local view state (it does not persist).
class KeyEventsScreen extends StatefulWidget {
  const KeyEventsScreen({
    super.key,
    required this.controller,
    required this.onPersist,
    required this.onDeleteEvent,
    this.readOnly = false,
  });

  /// Save-content editing: immutable base key events are frozen (no open, no
  /// delete); new ones stay editable.
  final bool readOnly;

  final KeyEventsController controller;
  final Future<void> Function() onPersist;
  final Future<void> Function(String name) onDeleteEvent;

  @override
  State<KeyEventsScreen> createState() => _KeyEventsScreenState();
}

class _KeyEventsScreenState extends State<KeyEventsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  KeyEventsController get controller => widget.controller;

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

  /// Events whose name contains the (trimmed, case-insensitive) query. An empty
  /// query matches everything.
  List<KeyEvent> get _visibleEvents {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return controller.events;
    return [
      for (final e in controller.events)
        if (e.name.toLowerCase().contains(q)) e,
    ];
  }

  Future<void> _confirmDelete(BuildContext context, KeyEvent event) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('event.delete.dialog'),
        title: Text(event.name),
        content: Text(l10n.keyEventsDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('event.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('event.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.keyEventsDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDeleteEvent(event.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEditing) {
          return KeyEventEditScreen(
            controller: controller,
            onSave: () async {
              if (controller.save()) await widget.onPersist();
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
            key: const ValueKey('event.search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.keyEventsSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('event.search.clear'),
                      icon: const Icon(Icons.cancel),
                      tooltip: l10n.keyEventsSearchClear,
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
    final scheme = Theme.of(context).colorScheme;
    final events = _visibleEvents;

    return ListView.separated(
      key: const ValueKey('event.list'),
      padding: const EdgeInsets.all(24),
      itemCount: events.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('event.new'),
              onTap: controller.beginNew,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Icon(Icons.add_task, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }
        final event = events[index - 1];
        return EventTile(
          name: event.name,
          onTap: () => controller.beginEdit(event.name),
          onDelete: () => _confirmDelete(context, event),
          locked: widget.readOnly && event.immutable,
        );
      },
    );
  }
}
