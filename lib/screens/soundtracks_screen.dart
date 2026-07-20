import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../soundtracks/soundtrack.dart';
import '../soundtracks/soundtracks_controller.dart';
import '../widgets/soundtrack_tile.dart';

/// Warns that a soundtrack's derived display name must be unique. Shown by the
/// Add flow when the picked file's name duplicates an existing track.
Future<void> showSoundtrackNameNotUniqueDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('sound.name.not.unique.dialog'),
      content: Text(l10n.soundtracksNameNotUnique),
      actions: [
        FilledButton(
          key: const ValueKey('sound.name.not.unique.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

/// The in-game Soundtracks section. A search bar
/// pinned to the top filters the list below live (matching the track name);
/// row 0 is the "Add soundtrack" action ([onAdd]), the rest are [SoundtrackTile]s.
/// A tile is not clickable but carries a Play/Stop button ([onTogglePlay]) and a
/// delete button that confirms before [onDelete].
///
/// State lives on the shared [SoundtracksController] (owned by the game shell);
/// the search query is local view state (it does not persist).
class SoundtracksScreen extends StatefulWidget {
  const SoundtracksScreen({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
    required this.onTogglePlay,
    this.readOnly = false,
  });

  /// Save-content editing: immutable base soundtracks are
  /// frozen (no delete); new ones stay deletable.
  final bool readOnly;

  final SoundtracksController controller;

  /// Pick an audio file, derive its name, copy it in and persist (or reject a
  /// duplicate name). No navigation.
  final Future<void> Function() onAdd;

  /// Remove the track (and its file) after the delete confirmation.
  final Future<void> Function(Soundtrack track) onDelete;

  /// Start this track from the beginning, or stop it if already playing.
  final Future<void> Function(Soundtrack track) onTogglePlay;

  @override
  State<SoundtracksScreen> createState() => _SoundtracksScreenState();
}

class _SoundtracksScreenState extends State<SoundtracksScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  SoundtracksController get controller => widget.controller;

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

  /// Tracks whose name contains the (trimmed, case-insensitive) query. An empty
  /// query matches everything.
  List<Soundtrack> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return controller.items;
    return [
      for (final s in controller.items)
        if (s.name.toLowerCase().contains(q)) s,
    ];
  }

  Future<void> _confirmDelete(BuildContext context, Soundtrack track) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('sound.delete.dialog'),
        title: Text(track.name),
        content: Text(l10n.soundtracksDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('sound.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('sound.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.soundtracksDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(track);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _section(context),
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
            key: const ValueKey('sound.search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.soundtracksSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('sound.search.clear'),
                      icon: const Icon(Icons.cancel),
                      tooltip: l10n.soundtracksSearchClear,
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
    final items = _visible;

    return ListView.separated(
      key: const ValueKey('sound.list'),
      padding: const EdgeInsets.all(24),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('sound.new'),
              onTap: () => widget.onAdd(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Tooltip(
                    message: l10n.soundtracksAddLabel,
                    child: Icon(
                      Symbols.music_note_add,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final track = items[index - 1];
        return SoundtrackTile(
          name: track.name,
          isPlaying: controller.isPlaying(track.uuid),
          onPlayStop: () => widget.onTogglePlay(track),
          onDelete: () => _confirmDelete(context, track),
          locked: widget.readOnly && track.immutable,
        );
      },
    );
  }
}
