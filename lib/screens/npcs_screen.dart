import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../npcs/npc.dart';
import '../npcs/npcs_controller.dart';
import '../widgets/npc_tile.dart';
import 'npc_7thsea_screen.dart';
import 'npc_basicrpg_screen.dart';

/// The in-game NPC section. Same look as the Create grid: a
/// grid of portrait tiles (1:1.43), cell 0 being the "add NPC" action and the
/// rest one [NpcTile] per NPC (full image as background, a Clone / Delete context
/// menu). Tapping a tile opens the system-specific editor in place (Basic RPG ->
/// [NpcBasicRpgScreen]).
///
/// State lives on the shared [NpcsController] (owned by the game shell). [onSave]
/// commits the open editor (writes images + npcs[]); [onClone] and [onDelete]
/// perform their on-disk work in the store and reload the controller.
class NpcsScreen extends StatefulWidget {
  const NpcsScreen({
    super.key,
    required this.controller,
    required this.imagesBasePath,
    required this.onSave,
    required this.onClone,
    required this.onDelete,
    this.readOnly = false,
  });

  /// Save-content editing: immutable base NPCs are frozen
  /// (no open, no delete — Clone stays, it makes a new mutable NPC).
  final bool readOnly;

  final NpcsController controller;
  final String imagesBasePath;
  final Future<void> Function() onSave;
  final Future<void> Function(Npc npc) onClone;
  final Future<void> Function(Npc npc) onDelete;

  @override
  State<NpcsScreen> createState() => _NpcsScreenState();
}

class _NpcsScreenState extends State<NpcsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  NpcsController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  /// NPCs whose name, backstory or description contains the (trimmed,
  /// case-insensitive) query. An empty query matches everything.
  List<Npc> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return controller.npcs;
    return [
      for (final n in controller.npcs)
        if (n.name.toLowerCase().contains(q) ||
            n.backstory.toLowerCase().contains(q) ||
            n.description.toLowerCase().contains(q))
          n,
    ];
  }

  File? _iconImage(Npc npc) {
    final uuid = npc.iconImage;
    if (uuid == null) return null;
    final f = File('${widget.imagesBasePath}/$uuid.png');
    return f.existsSync() ? f : null;
  }

  /// The 7th Sea Villain badge values for [npc], or null when the adventure is
  /// not 7th Sea or the NPC is not a Villain (then the tile stays plain).
  /// Shared with the Play view via [sevenSeaVillain].
  NpcVillainStats? _villainStats(Npc npc) =>
      sevenSeaVillain(controller.systemId, npc.extra['stats']);

  Future<void> _confirmDelete(BuildContext context, Npc npc) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('game.npc.delete.dialog'),
        title: Text(npc.name),
        content: Text(l10n.npcsDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('game.npc.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('game.npc.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.npcsDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(npc);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEditing) {
          // System-specific editor: Basic RPG (empty template) keeps the simple
          // form; any other system (7th Sea 2e) gets its kind-driven form.
          if (controller.template.isEmpty) {
            return NpcBasicRpgScreen(
              controller: controller,
              imagesBasePath: widget.imagesBasePath,
              onSave: widget.onSave,
              onCancel: controller.cancelEdit,
            );
          }
          return Npc7thSeaScreen(
            controller: controller,
            imagesBasePath: widget.imagesBasePath,
            onSave: widget.onSave,
            onCancel: controller.cancelEdit,
          );
        }
        return _section(context);
      },
    );
  }

  /// The search bar pinned to the top, then the filtered grid below it.
  Widget _section(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: TextField(
            key: const ValueKey('game.npc.search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.npcsSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('game.npc.search.clear'),
                      icon: const Icon(Icons.cancel),
                      tooltip: l10n.npcsSearchClear,
                      onPressed: _clearSearch,
                    ),
            ),
          ),
        ),
        Expanded(child: _grid(context)),
      ],
    );
  }

  Widget _grid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final npcs = _visible;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        key: const ValueKey('game.npc.grid'),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: NpcTile.maxExtent,
          childAspectRatio: NpcTile.aspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: npcs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('game.npc.add'),
                onTap: controller.beginNew,
                child: Center(
                  child: Icon(
                    Icons.person_add_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final npc = npcs[index - 1];
          return NpcTile(
            uuid: npc.uuid,
            image: _iconImage(npc),
            villain: _villainStats(npc),
            onTap: () => controller.beginEdit(npc.uuid),
            onClone: () => widget.onClone(npc),
            onDelete: () => _confirmDelete(context, npc),
            locked: widget.readOnly && npc.immutable,
          );
        },
      ),
    );
  }
}
