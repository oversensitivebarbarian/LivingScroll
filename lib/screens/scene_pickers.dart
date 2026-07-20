import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/scene_npc_image_tile.dart';

/// One row/cell in a scene picker. [keyId] drives the widget key (so tiles stay
/// stable across renames), [selectId] is the value stored in the selection /
/// returned on tap, [label] is the displayed text and [image] (when set) is a
/// thumbnail for grid pickers.
class ScenePickEntry {
  const ScenePickEntry({
    required this.keyId,
    required this.selectId,
    this.label = '',
    this.image,
  });

  final String keyId;
  final String selectId;
  final String label;
  final File? image;
}

/// A single-select scene picker (Location / Soundtracks / Background image).
/// Tapping a tile pops the route returning that tile's [ScenePickEntry.selectId];
/// the add action runs [onAdd] and, when it yields a non-null id, pops with it
/// (create-and-select). A plain Back pops null (no change). The search bar filters
/// live (when [searchable]). When [grid] is true it renders a picture grid
/// (Background image) instead of a list.
///
/// Keys follow `scene.<entity>.select`: `<prefix>.root`, `.search`,
/// `.search.clear`, `.list` (or `.grid`), the add control [addKey], and
/// `.tile.<keyId>`.
class SceneSinglePicker extends StatefulWidget {
  const SceneSinglePicker({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.controller,
    required this.itemsOf,
    required this.leadingIcon,
    required this.addIcon,
    required this.addKey,
    this.searchHint,
    this.onAdd,
    this.grid = false,
    this.searchable = true,
    this.gridMaxExtent = 220,
    this.gridAspectRatio = 1,
  });

  final String keyPrefix;
  final String title;
  final Listenable controller;
  final List<ScenePickEntry> Function(String query) itemsOf;
  final IconData leadingIcon;
  final IconData addIcon;
  final String addKey;
  final String? searchHint;
  final Future<String?> Function(BuildContext context)? onAdd;

  /// When true the tiles are laid out as a picture grid (each tile shows
  /// [ScenePickEntry.image]); otherwise a vertical list. Grid tap-and-return.
  final bool grid;

  /// Whether to show the search field (the picture grid passes false).
  final bool searchable;
  final double gridMaxExtent;
  final double gridAspectRatio;

  @override
  State<SceneSinglePicker> createState() => _SceneSinglePickerState();
}

class _SceneSinglePickerState extends State<SceneSinglePicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final items = widget.itemsOf(_query);
        return Scaffold(
          key: ValueKey('${widget.keyPrefix}.root'),
          appBar: AppBar(title: Text(widget.title)),
          body: Column(
            children: [
              if (widget.searchable)
                _SearchField(
                  keyPrefix: widget.keyPrefix,
                  controller: _search,
                  hint: widget.searchHint,
                  query: _query,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
              Expanded(child: widget.grid ? _grid(items) : _list(items)),
            ],
          ),
        );
      },
    );
  }

  /// Opens the add form and, when it yields a new id, pops with it (create +
  /// select in one step).
  Future<void> _addAndSelect(BuildContext context) async {
    final added = await widget.onAdd?.call(context);
    if (added != null && context.mounted) Navigator.of(context).pop(added);
  }

  Widget _list(List<ScenePickEntry> items) => ListView.separated(
    key: ValueKey('${widget.keyPrefix}.list'),
    padding: const EdgeInsets.all(24),
    itemCount: items.length + 1,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      if (index == 0) {
        return _AddRow(
          addKey: widget.addKey,
          icon: widget.addIcon,
          onTap: () => _addAndSelect(context),
        );
      }
      final e = items[index - 1];
      return Card(
        child: ListTile(
          key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}'),
          leading: Icon(widget.leadingIcon),
          title: Text(
            e.label,
            key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}.label'),
          ),
          onTap: () => Navigator.of(context).pop(e.selectId),
        ),
      );
    },
  );

  /// A picture grid (Background image): cell 0 adds a new image, the rest are
  /// image tiles; tapping one pops with its id.
  Widget _grid(List<ScenePickEntry> items) => GridView.builder(
    key: ValueKey('${widget.keyPrefix}.grid'),
    padding: const EdgeInsets.all(24),
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: widget.gridMaxExtent,
      childAspectRatio: widget.gridAspectRatio,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
    ),
    itemCount: items.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return _AddRow(
          addKey: widget.addKey,
          icon: widget.addIcon,
          onTap: () => _addAndSelect(context),
        );
      }
      final e = items[index - 1];
      final scheme = Theme.of(context).colorScheme;
      return Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}'),
          onTap: () => Navigator.of(context).pop(e.selectId),
          child: (e.image != null && e.image!.existsSync())
              ? Image.file(e.image!, fit: BoxFit.cover)
              : Center(child: Icon(widget.leadingIcon, size: 40)),
        ),
      );
    },
  );
}

/// A multi-select scene picker (NPC / Notes / Key events / Images). Each tile has
/// a circle/check_circle toggle; the bottom bar's Save pops the selected
/// `Set<selectId>`, Cancel/Back pops null. The add action runs [onAdd] and, when
/// it yields a non-null id, adds it to the selection (create-and-select).
///
/// Keys follow `scene.<entity>.select`: `<prefix>.root`, the add control
/// [addKey], `.tile.<keyId>` + `.tile.<keyId>.toggle`, `.save`, `.cancel`, and —
/// for searchable pickers — `.search` / `.search.clear`.
class SceneMultiPicker extends StatefulWidget {
  const SceneMultiPicker({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.controller,
    required this.itemsOf,
    required this.initialSelected,
    required this.grid,
    required this.leadingIcon,
    required this.addIcon,
    required this.addKey,
    this.searchHint,
    this.searchable = true,
    this.onAdd,
    this.showAdd = true,
    this.npcTiles = false,
    this.gridMaxExtent = 220,
    this.gridAspectRatio = 1,
  });

  final String keyPrefix;
  final String title;
  final Listenable controller;
  final List<ScenePickEntry> Function(String query) itemsOf;
  final Set<String> initialSelected;
  final bool grid;
  final IconData leadingIcon;
  final IconData addIcon;
  final String addKey;
  final String? searchHint;
  final bool searchable;
  final Future<String?> Function(BuildContext context)? onAdd;

  /// Whether to show the leading "create new" action cell. Pickers with no
  /// create flow (e.g. Next scenes) pass false.
  final bool showAdd;

  /// When true the grid renders [SceneNpcImageTile]s — the SAME tile as the
  /// new_scene NPC carousel — with a select toggle in place of the delete button.
  final bool npcTiles;

  /// Grid cell sizing (defaults to a 220-wide square; the NPC picker passes the
  /// portrait NpcTile profile so its tiles match the new_scene tiles).
  final double gridMaxExtent;
  final double gridAspectRatio;

  @override
  State<SceneMultiPicker> createState() => _SceneMultiPickerState();
}

class _SceneMultiPickerState extends State<SceneMultiPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final items = widget.itemsOf(_query);
        return Scaffold(
          key: ValueKey('${widget.keyPrefix}.root'),
          appBar: AppBar(title: Text(widget.title)),
          body: Column(
            children: [
              if (widget.searchable)
                _SearchField(
                  keyPrefix: widget.keyPrefix,
                  controller: _search,
                  hint: widget.searchHint,
                  query: _query,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
              Expanded(child: widget.grid ? _grid(items) : _list(items)),
              _SaveCancelBar(
                keyPrefix: widget.keyPrefix,
                onCancel: () => Navigator.of(context).pop(),
                onSave: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _addRow() => _AddRow(
    addKey: widget.addKey,
    icon: widget.addIcon,
    onTap: () async {
      final added = await widget.onAdd?.call(context);
      if (added != null) setState(() => _selected.add(added));
    },
  );

  Widget _list(List<ScenePickEntry> items) {
    final addOffset = widget.showAdd ? 1 : 0;
    return ListView.separated(
      key: ValueKey('${widget.keyPrefix}.list'),
      padding: const EdgeInsets.all(24),
      itemCount: items.length + addOffset,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (widget.showAdd && index == 0) return _addRow();
        final e = items[index - addOffset];
        final selected = _selected.contains(e.selectId);
        return Card(
          child: ListTile(
            key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}'),
            leading: Icon(widget.leadingIcon),
            title: Text(e.label),
            trailing: IconButton(
              key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}.toggle'),
              icon: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
              onPressed: () => _toggle(e.selectId),
            ),
            onTap: () => _toggle(e.selectId),
          ),
        );
      },
    );
  }

  Widget _grid(List<ScenePickEntry> items) => GridView.builder(
    key: ValueKey('${widget.keyPrefix}.grid'),
    padding: const EdgeInsets.all(24),
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: widget.gridMaxExtent,
      childAspectRatio: widget.gridAspectRatio,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
    ),
    itemCount: items.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _addRow();
      final e = items[index - 1];
      final selected = _selected.contains(e.selectId);
      final scheme = Theme.of(context).colorScheme;
      final toggle = IconButton(
        key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}.toggle'),
        icon: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: widget.npcTiles
              ? scheme.onSecondaryContainer
              : (selected ? scheme.primary : scheme.onSurface),
        ),
        onPressed: () => _toggle(e.selectId),
      );
      if (widget.npcTiles) {
        // The SAME tile as the new_scene NPC carousel, with a select toggle
        // in place of the carousel's delete button. The toggle sits on a
        // round secondaryContainer backdrop (the adventure-tile overlaid-
        // control treatment) so the glyph stays legible over the NPC image.
        return SceneNpcImageTile(
          key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}'),
          image: e.image,
          onTap: () => _toggle(e.selectId),
          trailing: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer,
            ),
            child: toggle,
          ),
        );
      }
      return Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('${widget.keyPrefix}.tile.${e.keyId}'),
          onTap: () => _toggle(e.selectId),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (e.image != null && e.image!.existsSync())
                Image.file(e.image!, fit: BoxFit.cover)
              else
                Center(child: Icon(widget.leadingIcon, size: 40)),
              Positioned(top: 4, right: 4, child: toggle),
            ],
          ),
        ),
      );
    },
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.keyPrefix,
    required this.controller,
    required this.hint,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String keyPrefix;
  final TextEditingController controller;
  final String? hint;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: TextField(
        key: ValueKey('$keyPrefix.search'),
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  key: ValueKey('$keyPrefix.search.clear'),
                  icon: const Icon(Icons.cancel),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.addKey,
    required this.icon,
    required this.onTap,
  });

  final String addKey;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(addKey),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: Icon(icon, color: scheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _SaveCancelBar extends StatelessWidget {
  const _SaveCancelBar({
    required this.keyPrefix,
    required this.onCancel,
    required this.onSave,
  });

  final String keyPrefix;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              key: ValueKey('$keyPrefix.cancel'),
              onPressed: onCancel,
              child: Text(l10n.unsavedCancel),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: ValueKey('$keyPrefix.save'),
              onPressed: onSave,
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }
}
