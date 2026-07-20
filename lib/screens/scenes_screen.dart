import 'package:flutter/material.dart';

import '../images/bg_images_controller.dart';
import '../images/images_controller.dart';
import '../keyevents/key_events_controller.dart';
import '../l10n/app_localizations.dart';
import '../notes/notes_controller.dart';
import '../npcs/npcs_controller.dart';
import '../paths/path_colors.dart';
import '../scenes/scene.dart';
import '../scenes/scenes_controller.dart';
import '../soundtracks/soundtracks_controller.dart';
import '../widgets/scene_tile.dart';
import 'scene_edit_screen.dart';

/// The in-game Scenes section. Same shape as the Notes /
/// Key events section: a search bar filters the list live (by scene name or
/// location); row 0 is the "Add scene" action, the rest are [SceneTile]s. Tapping
/// a tile opens the scene editor in place via the shared
/// [ScenesController]; the tile's delete icon confirms then removes the scene.
///
/// The other section controllers are injected so the editor's picker sub-screens
/// reuse their data. [onPersist] writes the scenes back to LivingScroll.json.
class ScenesScreen extends StatefulWidget {
  const ScenesScreen({
    super.key,
    required this.controller,
    required this.onPersist,
    required this.onPreview,
    required this.npcs,
    required this.notes,
    required this.keyEvents,
    required this.images,
    required this.soundtracks,
    required this.bgImages,
    required this.npcsImagesPath,
    required this.imagesOtherPath,
    required this.bgImagesPath,
    this.onCreateNpc,
    this.onCreateNote,
    this.onCreateKeyEvent,
    this.onCreateImage,
    this.onCreateBgImage,
    this.onCreateSoundtrack,
    this.readOnly = false,
  });

  final ScenesController controller;
  final Future<void> Function() onPersist;

  /// Save-content editing: an immutable base scene is not
  /// deletable (a lock badge replaces its delete) but STILL opens — the scene
  /// editor then restricts it to its `next_scenes` list. New scenes are fully
  /// editable + deletable.
  final bool readOnly;

  /// Opens a scene in the Play view (preview mode) — the tile's Preview glyph.
  final void Function(Scene scene) onPreview;

  final NpcsController npcs;
  final NotesController notes;
  final KeyEventsController keyEvents;
  final ImagesController images;
  final SoundtracksController soundtracks;
  final BgImagesController bgImages;
  final String npcsImagesPath;
  final String imagesOtherPath;
  final String bgImagesPath;

  final CreateAndSelect? onCreateNpc;
  final CreateAndSelect? onCreateNote;
  final CreateAndSelect? onCreateKeyEvent;
  final CreateAndSelect? onCreateImage;
  final CreateAndSelect? onCreateBgImage;
  final CreateAndSelect? onCreateSoundtrack;

  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Sentinel entry in [_pathFilter] for the EMPTY disc — filters to scenes that
  /// belong to NO path. (Real path ids are the six colour ids.)
  static const String _noPathId = 'none';

  /// One filter-disc slot: the 36px disc + its 8px left gap.
  static const double _discSlot = 44;

  /// FIXED width of the path-filter container — always 7 slots (the six possible
  /// path colours + the empty disc), so the search field width is stable
  /// regardless of how many paths are currently used.
  static const double _pathFilterWidth = 7 * _discSlot;

  /// The selected path-filter disc ids (colour ids, plus [_noPathId] for the empty
  /// disc). Empty => no path filter. When non-empty, the scene list shows only
  /// scenes matching a selected path (or, for [_noPathId], scenes with no path).
  final Set<String> _pathFilter = {};

  ScenesController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  List<Scene> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty && _pathFilter.isEmpty) return controller.scenes;
    return [
      for (final s in controller.scenes)
        if ((q.isEmpty || s.name.toLowerCase().contains(q)) &&
            _matchesPathFilter(s))
          s,
    ];
  }

  /// The colour ids of the paths a scene belongs to (its resolved discs).
  Set<String> _scenePathColorIds(Scene s) => {
    for (final p in controller.paths)
      if (s.pathNames.contains(p.name)) p.colorId,
  };

  /// Whether [s] passes the current path filter: no filter => all pass; otherwise
  /// keep a scene that matches ANY selected path colour, OR (empty disc selected)
  /// a scene that belongs to NO path.
  bool _matchesPathFilter(Scene s) {
    if (_pathFilter.isEmpty) return true;
    final ids = _scenePathColorIds(s);
    if (_pathFilter.contains(_noPathId) && ids.isEmpty) return true;
    return ids.any((id) => _pathFilter.contains(id));
  }

  /// The path-filter discs to show: one per USED path (a path some scene belongs
  /// to), in `controller.paths` order. The empty disc is added by the top bar.
  List<({String id, Color color})> _usedPathDiscs() {
    final used = <String>{};
    for (final s in controller.scenes) {
      for (final p in controller.paths) {
        if (s.pathNames.contains(p.name)) used.add(p.colorId);
      }
    }
    return [
      for (final p in controller.paths)
        if (used.contains(p.colorId))
          (
            id: p.colorId,
            color: pathColors
                .firstWhere(
                  (c) => c.id == p.colorId,
                  orElse: () => pathColors.first,
                )
                .color,
          ),
    ];
  }

  void _togglePathFilter(String id) => setState(() {
    if (!_pathFilter.remove(id)) _pathFilter.add(id);
  });

  List<SceneTileDisc> _discs(Scene s) => [
    for (final p in controller.paths)
      if (s.pathNames.contains(p.name))
        (
          colorId: p.colorId,
          color: pathColors
              .firstWhere(
                (c) => c.id == p.colorId,
                orElse: () => pathColors.first,
              )
              .color,
        ),
  ];

  Future<void> _confirmDelete(BuildContext context, Scene scene) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('scene.delete.dialog'),
        title: Text(scene.name),
        content: Text(l10n.scenesDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('scene.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('scene.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.scenesDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.delete(scene.uuid);
      await widget.onPersist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEditing) {
          return SceneEditScreen(
            controller: controller,
            onSave: () async {
              if (controller.save()) await widget.onPersist();
            },
            onCancel: controller.cancelEdit,
            npcs: widget.npcs,
            notes: widget.notes,
            keyEvents: widget.keyEvents,
            images: widget.images,
            soundtracks: widget.soundtracks,
            bgImages: widget.bgImages,
            npcsImagesPath: widget.npcsImagesPath,
            imagesOtherPath: widget.imagesOtherPath,
            bgImagesPath: widget.bgImagesPath,
            onCreateNpc: widget.onCreateNpc,
            onCreateNote: widget.onCreateNote,
            onCreateKeyEvent: widget.onCreateKeyEvent,
            onCreateImage: widget.onCreateImage,
            onCreateBgImage: widget.onCreateBgImage,
            onCreateSoundtrack: widget.onCreateSoundtrack,
            readOnly: widget.readOnly,
          );
        }
        return _section(context);
      },
    );
  }

  Widget _section(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The used-path list is recomputed on EVERY build (== every entry into the
    // Scenes view), so it always reflects the current scenes/paths. Drop any
    // selected filter whose path is no longer available (e.g. a scene was
    // deleted), so a stale selection can't get stuck.
    final usedDiscs = _usedPathDiscs();
    final availableIds = {for (final d in usedDiscs) d.id, _noPathId};
    _pathFilter.removeWhere((id) => !availableIds.contains(id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SEARCH — stretches over ALL available width (the path filter to
              // its right has a fixed width).
              Expanded(
                child: TextField(
                  key: const ValueKey('scene.search'),
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.scenesSearchHint,
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('scene.search.clear'),
                            icon: const Icon(Icons.cancel),
                            tooltip: l10n.scenesSearchClear,
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // PATH FILTER — FIXED width (7 discs: the six possible path colours
              // + the empty disc), right-aligned. Shows a disc per USED path (in
              // paths[] colour order) plus the empty ("no path") disc; selecting
              // discs filters the list.
              SizedBox(
                key: const ValueKey('scene.pathfilter'),
                width: _pathFilterWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final d in usedDiscs)
                      _filterDisc(
                        keyId: 'scene.pathfilter.${d.id}',
                        id: d.id,
                        color: d.color,
                      ),
                    _filterDisc(
                      keyId: 'scene.pathfilter.none',
                      id: _noPathId,
                      color: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _list(context)),
      ],
    );
  }

  /// One path-filter disc. [color] null => the EMPTY disc ("no path"). Selected
  /// discs get a visible surrounding border (`colorScheme.primary` ring); tapping
  /// toggles the selection. Keyed [keyId] (`scene.pathfilter.<id>`).
  Widget _filterDisc({
    required String keyId,
    required String id,
    required Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _pathFilter.contains(id);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        key: ValueKey(keyId),
        customBorder: const CircleBorder(),
        onTap: () => _togglePathFilter(id),
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Selected => visible surrounding border; unselected => none.
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // A path disc is filled with its colour; the empty disc is a hollow
              // ring (surface fill) so it reads as "no path".
              color: color ?? scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.onSurfaceVariant, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  /// Leading "Add scene" cell — the SAME in both the reorderable and the search
  /// (plain) list.
  Widget _addTile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('scene.new'),
        onTap: controller.beginNew,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Tooltip(
              message: l10n.scenesAddLabel,
              child: Icon(
                Icons.video_call_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  SceneTile _sceneTile(BuildContext context, Scene scene, int? dragIndex) =>
      SceneTile(
        uuid: scene.uuid,
        name: scene.name,
        sceneType: scene.sceneType,
        discs: _discs(scene),
        onTap: () => controller.beginEdit(scene.uuid),
        onDelete: () => _confirmDelete(context, scene),
        onPreview: () => widget.onPreview(scene),
        locked: widget.readOnly && scene.immutable,
        dragIndex: dragIndex,
      );

  Widget _list(BuildContext context) {
    final scenes = _visible;
    // Reordering is offered only on the FULL, unfiltered list — a filtered subset
    // has ambiguous indices. When the search OR the path filter is active fall
    // back to a plain list with no drag handles. (Reorder IS allowed in save-edit
    // — it changes only the scenes[] order, not the next_scenes graph.)
    final reorderable = _query.trim().isEmpty && _pathFilter.isEmpty;

    if (!reorderable) {
      return ListView.separated(
        key: const ValueKey('scene.list'),
        padding: const EdgeInsets.all(24),
        itemCount: scenes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _addTile(context);
          return _sceneTile(context, scenes[index - 1], null);
        },
      );
    }

    // Reorderable: the Add cell is a fixed header ABOVE the reorderable scene
    // list; each scene tile carries the swap_vert drag handle (dragIndex).
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _addTile(context),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              key: const ValueKey('scene.list'),
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: scenes.length,
              itemBuilder: (context, i) => Padding(
                key: ValueKey('scene.reorder.${scenes[i].uuid}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _sceneTile(context, scenes[i], i),
              ),
              // onReorderItem (not the deprecated onReorder): newIndex already
              // accounts for removing the item at oldIndex.
              onReorderItem: (oldIndex, newIndex) async {
                controller.reorder(oldIndex, newIndex);
                await widget.onPersist();
              },
            ),
          ),
        ],
      ),
    );
  }
}
