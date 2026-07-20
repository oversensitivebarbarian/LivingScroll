import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import 'adventure_tile.dart';

/// The Create destination grid: cell 0 is the "new adventure"
/// button; the remaining cells list `{Projects}`, one [AdventureTile] each.
class CreateGridScreen extends StatefulWidget {
  const CreateGridScreen({
    super.key,
    required this.onNew,
    required this.onOpen,
    this.store = const ProjectsStore(),
  });

  /// Tapped the empty "new adventure" cell.
  final VoidCallback onNew;

  /// Open / edit an existing adventure (navigates to the game screen).
  final ValueChanged<String> onOpen;

  final ProjectsStore store;

  @override
  State<CreateGridScreen> createState() => _CreateGridScreenState();
}

class _CreateGridScreenState extends State<CreateGridScreen> {
  List<AdventureSummary> _adventures = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.store.list();
    if (!mounted) return;
    setState(() => _adventures = list);
  }

  Future<void> _confirmDelete(AdventureSummary adventure) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('create.delete.dialog'),
        title: Text(adventure.name),
        content: Text(l10n.adventureDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('create.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('create.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adventureDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.delete(adventure.slug);
      await _load();
    }
  }

  /// Clones an adventure (the tile's Clone menu): the store copies its directory
  /// to a new unique slug and renames the copy; then reload so the grid shows it.
  Future<void> _cloneAdventure(AdventureSummary adventure) async {
    await widget.store.cloneAdventure(adventure.slug);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        key: const ValueKey('create.grid'),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 1 / 1.43,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _adventures.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('create.new'),
                onTap: widget.onNew,
                child: Center(
                  child: Icon(
                    Icons.note_add_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final adventure = _adventures[index - 1];
          return AdventureTile(
            adventure: adventure,
            onOpen: () => widget.onOpen(adventure.slug),
            onClone: () => _cloneAdventure(adventure),
            onDelete: () => _confirmDelete(adventure),
          );
        },
      ),
    );
  }
}
