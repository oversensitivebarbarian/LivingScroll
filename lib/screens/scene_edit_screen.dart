import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../images/images_controller.dart';
import '../images/bg_images_controller.dart';
import '../keyevents/key_events_controller.dart';
import '../l10n/app_localizations.dart';
import '../notes/note_content.dart';
import '../notes/notes_controller.dart';
import '../npcs/npcs_controller.dart';
import '../paths/path_colors.dart';
import '../soundtracks/soundtracks_controller.dart';
import '../scenes/scenes_controller.dart';
import '../widgets/npc_tile.dart';
import '../widgets/scene_npc_image_tile.dart';
import '../widgets/scene_type_icon.dart';
import '../widgets/visibility_rules_editor.dart';
import 'scene_pickers.dart';

/// Optional create-and-select hook: opens an entity's create form and resolves
/// to the new item's select-id (a name or uuid) to auto-select, or null when the
/// user cancelled / nothing was created.
typedef CreateAndSelect = Future<String?> Function(BuildContext context);

/// The scene editor form. Bound to the shared
/// [ScenesController]; the other section controllers are injected so the picker
/// sub-screens reuse their existing data. Save commits via [onSave]; Cancel
/// discards via [onCancel].
class SceneEditScreen extends StatefulWidget {
  const SceneEditScreen({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
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
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  /// Save-content editing: when the scene being edited is
  /// immutable base content, the whole form is frozen EXCEPT its `next_scenes`
  /// list — links may be added, and removed only when the target scene is
  /// non-immutable. A mutable (new) scene is fully editable.
  final bool readOnly;

  final NpcsController npcs;
  final NotesController notes;
  final KeyEventsController keyEvents;
  final ImagesController images;
  final SoundtracksController soundtracks;

  /// The scene BACKGROUND-image pool (files under [bgImagesPath]).
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
  State<SceneEditScreen> createState() => _SceneEditScreenState();
}

class _SceneEditScreenState extends State<SceneEditScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.editName,
  );
  late final TextEditingController _narration = TextEditingController(
    text: widget.controller.editDescription,
  );

  ScenesController get _model => widget.controller;

  /// True when the scene being edited is immutable base content in save-edit —
  /// every field is frozen except `next_scenes`.
  bool get _restricted =>
      widget.readOnly && (_model.editing?.immutable ?? false);

  /// Whether the scene [uuid] is immutable base content (used to block removing
  /// a next-scenes link that points at it).
  bool _isSceneImmutable(String uuid) {
    for (final s in _model.scenes) {
      if (s.uuid == uuid) return s.immutable;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _name.dispose();
    _narration.dispose();
    super.dispose();
  }

  void _onModelChanged() => setState(() {});

  // --- picker launchers ---------------------------------------------------

  /// The Background image field: a single-select picture picker over the
  /// dedicated background-image pool (files under `images/bg_images/`) that ALSO
  /// offers "add a new image" (pick a file -> convert -> select). Background
  /// images have NO visibility rules and no metadata. Returns the chosen
  /// image_uuid, stored as scenes.bg_image.
  Future<void> _pickBgImage() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SceneSinglePicker(
          keyPrefix: 'scene.bgimage.select',
          title: AppLocalizations.of(context).scenePickBackgroundTitle,
          controller: widget.bgImages,
          grid: true,
          searchable: false,
          leadingIcon: Icons.image_outlined,
          addIcon: Icons.add_photo_alternate_outlined,
          addKey: 'scene.bgimage.select.add',
          onAdd: widget.onCreateBgImage,
          itemsOf: (_) => [
            for (final uuid in widget.bgImages.uuids)
              ScenePickEntry(
                keyId: uuid,
                selectId: uuid,
                image: File('${widget.bgImagesPath}/$uuid.png'),
              ),
          ],
        ),
      ),
    );
    if (result != null) _model.editBgImage = result;
  }

  Future<void> _pickSoundtrack() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SceneSinglePicker(
          keyPrefix: 'scene.soundtracks.select',
          title: AppLocalizations.of(context).scenePickSoundtrackTitle,
          controller: widget.soundtracks,
          leadingIcon: Icons.audio_file,
          addIcon: Icons.library_add,
          addKey: 'scene.soundtracks.select.new',
          onAdd: widget.onCreateSoundtrack,
          itemsOf: (q) {
            final query = q.trim().toLowerCase();
            return [
              for (final s in widget.soundtracks.items)
                if (query.isEmpty || s.name.toLowerCase().contains(query))
                  ScenePickEntry(
                    keyId: s.uuid,
                    selectId: s.uuid,
                    label: s.name,
                  ),
            ];
          },
        ),
      ),
    );
    if (result != null) _model.editAudioUuids = [result];
  }

  /// The scene name for a next-scene chip, resolved from the target's scene_uuid
  /// (next_scenes store uuids). Falls back to the raw uuid for a dangling link
  /// whose target no longer exists.
  String _nextSceneLabel(String uuid) {
    for (final s in _model.scenes) {
      if (s.uuid == uuid) return s.name;
    }
    return uuid;
  }

  Future<void> _pickNextScenes() async {
    // On a FROZEN scene in save-edit only NON-immutable scenes may be added as
    // next_scenes; existing links to immutable scenes are
    // PRESERVED — the picker never lists them, so it cannot toggle them off (that
    // is what protects the original graph; the list shows them locked too).
    final restricted = _restricted;
    final immutableLinks = restricted
        ? _model.editNextSceneUuids.where(_isSceneImmutable).toList()
        : const <String>[];
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SceneMultiPicker(
          keyPrefix: 'scene.nextscenes.select',
          title: AppLocalizations.of(context).scenePickNextScenesTitle,
          controller: _model,
          grid: false,
          // No create-new here.
          showAdd: false,
          leadingIcon: Icons.videocam,
          addIcon: Icons.videocam,
          addKey: 'scene.nextscenes.select.add',
          initialSelected: restricted
              ? {
                  for (final u in _model.editNextSceneUuids)
                    if (!_isSceneImmutable(u)) u,
                }
              : {..._model.editNextSceneUuids},
          itemsOf: (q) {
            final query = q.trim().toLowerCase();
            return [
              for (final s in _model.scenes)
                // Embedded logic: starting scenes never appear, and a scene
                // cannot follow itself.
                if (s.sceneType != 'start' && s.uuid != _model.editingUuid)
                  // Save-edit on a frozen scene: only non-immutable candidates.
                  if (!restricted || !s.immutable)
                    if (query.isEmpty || s.name.toLowerCase().contains(query))
                      ScenePickEntry(
                        keyId: s.uuid,
                        selectId: s.uuid,
                        label: _nextSceneLabel(s.uuid),
                      ),
            ];
          },
        ),
      ),
    );
    if (result != null) {
      // Restricted: keep the preserved immutable links + the picked non-immutable
      // ones. Unrestricted: the picker result is the full selection.
      _model.editNextSceneUuids = restricted
          ? [...immutableLinks, ...result]
          : result.toList();
    }
  }

  Future<void> _pickNpcs() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SceneMultiPicker(
          keyPrefix: 'scene.npc.select',
          title: AppLocalizations.of(context).scenePickNpcTitle,
          controller: widget.npcs,
          grid: true,
          // Tiles identical to the new_scene NPC carousel (portrait NpcTile).
          npcTiles: true,
          gridMaxExtent: NpcTile.maxExtent,
          gridAspectRatio: NpcTile.aspectRatio,
          leadingIcon: Icons.person,
          addIcon: Icons.person_add_outlined,
          addKey: 'scene.npc.select.add',
          initialSelected: {..._model.editNpcNames},
          onAdd: widget.onCreateNpc,
          itemsOf: (q) {
            final query = q.trim().toLowerCase();
            return [
              for (final n in widget.npcs.npcs)
                if (query.isEmpty || n.name.toLowerCase().contains(query))
                  ScenePickEntry(
                    keyId: n.uuid,
                    selectId: n.name,
                    label: n.name,
                    image: n.iconImage == null
                        ? null
                        : File('${widget.npcsImagesPath}/${n.iconImage}.png'),
                  ),
            ];
          },
        ),
      ),
    );
    if (result != null) _model.editNpcNames = result.toList();
  }

  Future<void> _pickNotes() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SceneMultiPicker(
          keyPrefix: 'scene.notes.select',
          title: AppLocalizations.of(context).scenePickNotesTitle,
          controller: widget.notes,
          grid: false,
          leadingIcon: Icons.note_outlined,
          addIcon: Icons.note_add_outlined,
          addKey: 'scene.notes.select.new',
          initialSelected: {..._model.editNoteUuids},
          onAdd: widget.onCreateNote,
          itemsOf: (q) {
            final query = q.trim().toLowerCase();
            return [
              for (final n in widget.notes.notes)
                if (query.isEmpty ||
                    n.name.toLowerCase().contains(query) ||
                    plainTextFromStored(
                      n.content,
                    ).toLowerCase().contains(query))
                  ScenePickEntry(
                    keyId: n.uuid,
                    selectId: n.uuid,
                    label: n.name,
                  ),
            ];
          },
        ),
      ),
    );
    if (result != null) _model.editNoteUuids = result.toList();
  }

  Future<void> _pickKeyEvents() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SceneMultiPicker(
          keyPrefix: 'scene.keyevents.select',
          title: AppLocalizations.of(context).scenePickKeyEventsTitle,
          controller: widget.keyEvents,
          grid: false,
          leadingIcon: Icons.check_circle,
          addIcon: Icons.add_task,
          addKey: 'scene.keyevents.select.new',
          initialSelected: {..._model.editKeyEventNames},
          onAdd: widget.onCreateKeyEvent,
          itemsOf: (q) {
            final query = q.trim().toLowerCase();
            return [
              for (final e in widget.keyEvents.events)
                if (query.isEmpty || e.name.toLowerCase().contains(query))
                  ScenePickEntry(
                    keyId: e.name,
                    selectId: e.name,
                    label: e.name,
                  ),
            ];
          },
        ),
      ),
    );
    if (result != null) _model.editKeyEventNames = result.toList();
  }

  Future<void> _pickImages() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SceneMultiPicker(
          keyPrefix: 'scene.images.select',
          title: AppLocalizations.of(context).scenePickImagesTitle,
          controller: widget.images,
          grid: true,
          searchable: false,
          leadingIcon: Icons.image_outlined,
          addIcon: Icons.add_photo_alternate_outlined,
          addKey: 'scene.images.select.add',
          initialSelected: {..._model.editImageUuids},
          onAdd: widget.onCreateImage,
          itemsOf: (_) => [
            for (final im in widget.images.images)
              ScenePickEntry(
                keyId: im.uuid,
                selectId: im.uuid,
                label: im.name,
                image: File('${widget.imagesOtherPath}/${im.uuid}.png'),
              ),
          ],
        ),
      ),
    );
    if (result != null) _model.editImageUuids = result.toList();
  }

  /// Section buttons (Location / Notes / Key events / Soundtrack) are 20% taller
  /// than the 40px button default so the enlarged icon sits comfortably.
  static const _sectionButtonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      key: const ValueKey('game.scenes.edit.root'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Everything BEFORE Next scenes is frozen when the scene is
                  // immutable base content (only next_scenes stays editable).
                  // Scrolling still works (Scrollable is
                  // above this IgnorePointer).
                  IgnorePointer(
                    ignoring: _restricted,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // NAME
                        TextField(
                          key: const ValueKey('game.scenes.edit.field.name'),
                          controller: _name,
                          onChanged: (v) => _model.editName = v,
                          decoration: InputDecoration(
                            labelText: l10n.sceneNameLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // NARRATION
                        TextField(
                          key: const ValueKey(
                            'game.scenes.edit.field.narration',
                          ),
                          controller: _narration,
                          onChanged: (v) => _model.editDescription = v,
                          minLines: 4,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            labelText: l10n.sceneNarrationLabel,
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // SCENE TYPE — a 4-way radio (start/standard/recurring/end).
                        _Divider(
                          label: l10n.sceneSectionType,
                          keyId: 'game.scenes.edit.section.type',
                        ),
                        _sceneTypeRow(l10n),
                        // NPC
                        _Divider(
                          label: l10n.sceneSectionNpc,
                          keyId: 'game.scenes.edit.section.npc',
                        ),
                        SizedBox(
                          // One game.npc grid-tile tall: the add button and every
                          // carousel tile are the same size as a NpcTile (220 wide,
                          // portrait 1:1.43).
                          height: NpcTile.maxExtent / NpcTile.aspectRatio,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: NpcTile.maxExtent,
                                child: _AddTileButton(
                                  keyId: 'game.scenes.edit.npc.add',
                                  icon: Symbols.person_check,
                                  onTap: _pickNpcs,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _npcCarousel()),
                            ],
                          ),
                        ),
                        // NOTES
                        _Divider(
                          label: l10n.sceneSectionNotes,
                          keyId: 'game.scenes.edit.section.notes',
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('game.scenes.edit.notes.add'),
                          style: _sectionButtonStyle,
                          onPressed: _pickNotes,
                          icon: const Icon(
                            Icons.note_add_outlined,
                            size: 18 * 1.7,
                          ),
                          label: Text(l10n.sceneAddNotes),
                        ),
                        _SelectedColumn(
                          keyId: 'game.scenes.edit.notes.list',
                          tilePrefix: 'game.scenes.edit.notes.tile',
                          icon: Icons.note_outlined,
                          entries: [
                            for (final n in widget.notes.notes)
                              if (_model.editNoteUuids.contains(n.uuid))
                                (id: n.uuid, label: n.name),
                          ],
                          onDelete: (id) => _model.editNoteUuids = _model
                              .editNoteUuids
                              .where((u) => u != id)
                              .toList(),
                          // Frozen scene: notes are base content — all locked.
                          lockedIds: _restricted
                              ? {..._model.editNoteUuids}
                              : const {},
                        ),
                        // KEY EVENTS
                        _Divider(
                          label: l10n.sceneSectionKeyEvents,
                          keyId: 'game.scenes.edit.section.keyevents',
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('game.scenes.edit.keyevents.add'),
                          style: _sectionButtonStyle,
                          onPressed: _pickKeyEvents,
                          icon: const Icon(Icons.adjust, size: 18 * 1.7),
                          label: Text(l10n.sceneSectionKeyEvents),
                        ),
                        _SelectedColumn(
                          keyId: 'game.scenes.edit.keyevents.list',
                          tilePrefix: 'game.scenes.edit.keyevents.tile',
                          icon: Icons.check_circle,
                          entries: [
                            for (final e in widget.keyEvents.events)
                              if (_model.editKeyEventNames.contains(e.name))
                                (id: e.name, label: e.name),
                          ],
                          onDelete: (id) => _model.editKeyEventNames = _model
                              .editKeyEventNames
                              .where((n) => n != id)
                              .toList(),
                          // Frozen scene: key events are base content — all locked.
                          lockedIds: _restricted
                              ? {..._model.editKeyEventNames}
                              : const {},
                        ),
                        // IMAGES
                        _Divider(
                          label: l10n.sceneSectionImages,
                          keyId: 'game.scenes.edit.section.images',
                        ),
                        SizedBox(
                          // Square image tiles, 50% larger than before (96 -> 144).
                          height: 144,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 144,
                                height: 144,
                                child: _AddTileButton(
                                  keyId: 'game.scenes.edit.images.add',
                                  icon: Symbols.hallway,
                                  onTap: _pickImages,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _imagesCarousel()),
                            ],
                          ),
                        ),
                        // BACKGROUND IMAGE — directly under Images. A single-select
                        // background (scenes.bg_image) shown as the scene background in
                        // play/game; pick from images/bg_images/ or add a new one.
                        _Divider(
                          label: l10n.sceneSectionBackground,
                          keyId: 'game.scenes.edit.section.bgimage',
                        ),
                        SizedBox(
                          height: 144,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 144,
                                height: 144,
                                child: _AddTileButton(
                                  keyId: 'game.scenes.edit.bgimage.add',
                                  icon: Icons.wallpaper,
                                  onTap: _pickBgImage,
                                ),
                              ),
                              if (_model.editBgImage.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                _BgImageTile(
                                  uuid: _model.editBgImage,
                                  image: File(
                                    '${widget.bgImagesPath}/${_model.editBgImage}.png',
                                  ),
                                  onDelete: () => _model.editBgImage = '',
                                  locked: _restricted,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // SOUNDTRACKS
                        _Divider(
                          label: l10n.sceneSectionAudio,
                          keyId: 'game.scenes.edit.section.audio',
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('game.scenes.edit.audio.button'),
                          style: _sectionButtonStyle,
                          onPressed: _pickSoundtrack,
                          icon: const Icon(Icons.queue_music, size: 18 * 1.7),
                          label: Text(_audioLabel(l10n)),
                        ),
                        _SelectedColumn(
                          keyId: 'game.scenes.edit.audio.list',
                          tilePrefix: 'game.scenes.edit.audio.tile',
                          icon: Icons.audio_file,
                          entries: [
                            for (final s in widget.soundtracks.items)
                              if (_model.editAudioUuids.contains(s.uuid))
                                (id: s.uuid, label: s.name),
                          ],
                          onDelete: (id) => _model.editAudioUuids = _model
                              .editAudioUuids
                              .where((u) => u != id)
                              .toList(),
                          // Frozen scene: the soundtrack is base content — locked.
                          lockedIds: _restricted
                              ? {..._model.editAudioUuids}
                              : const {},
                        ),
                      ],
                    ),
                  ),
                  // NEXT SCENES — editable even for a frozen scene (add any link;
                  // remove only links to non-immutable target scenes).
                  _Divider(
                    label: l10n.sceneSectionNextScenes,
                    keyId: 'game.scenes.edit.section.nextscenes',
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('game.scenes.edit.nextscenes.add'),
                    style: _sectionButtonStyle,
                    // An ending scene has no next scenes -> the button is disabled.
                    onPressed: _model.editSceneType == 'end'
                        ? null
                        : _pickNextScenes,
                    icon: const Icon(Icons.videocam, size: 18 * 1.7),
                    label: Text(l10n.sceneSectionNextScenes),
                  ),
                  _SelectedColumn(
                    keyId: 'game.scenes.edit.nextscenes.list',
                    tilePrefix: 'game.scenes.edit.nextscenes.tile',
                    icon: Icons.videocam,
                    entries: [
                      for (final uuid in _model.editNextSceneUuids)
                        (id: uuid, label: _nextSceneLabel(uuid)),
                    ],
                    // In a frozen scene a link to an IMMUTABLE target scene may
                    // not be removed (it protects the running graph); a link to a
                    // new (mutable) scene stays removable.
                    lockedIds: _restricted
                        ? {
                            for (final uuid in _model.editNextSceneUuids)
                              if (_isSceneImmutable(uuid)) uuid,
                          }
                        : const {},
                    onDelete: (id) => _model.editNextSceneUuids = _model
                        .editNextSceneUuids
                        .where((n) => n != id)
                        .toList(),
                  ),
                  // PATHS + VISIBILITY (two columns) — frozen for an immutable
                  // scene (only next_scenes above stays editable).
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: _restricted,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Divider(
                                label: l10n.sceneSectionPaths,
                                keyId: 'game.scenes.edit.section.paths',
                              ),
                              _pathsMultiSelect(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Divider(
                                label: l10n.visibilityRulesTitle,
                                keyId: 'game.scenes.edit.section.visibility',
                              ),
                              VisibilityRulesEditor(
                                // The section divider above already shows the
                                // heading; don't duplicate it inside the editor.
                                showTitle: false,
                                value: _model.editVisibility,
                                availableKeyEvents: _model.keyEvents,
                                onChanged: (v) => _model.editVisibility = v,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // SAVE / CANCEL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: const ValueKey('game.scenes.edit.cancel'),
                    onPressed: widget.onCancel,
                    child: Text(l10n.unsavedCancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const ValueKey('game.scenes.edit.save'),
                    onPressed: _model.canSave ? _handleSave : null,
                    child: Text(l10n.settingsSave),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Removes [name] from the scene's selected NPCs (the carousel delete button).
  void _removeNpc(String name) {
    _model.editNpcNames = _model.editNpcNames.where((n) => n != name).toList();
  }

  /// The horizontal strip of selected-NPC tiles, each an icon-image tile with an
  /// inset delete button that drops it from scenes.npcs[].
  Widget _npcCarousel() {
    final selected = [
      for (final n in widget.npcs.npcs)
        if (_model.editNpcNames.contains(n.name)) n,
    ];
    return ListView.separated(
      key: const ValueKey('game.scenes.edit.npc.carousel'),
      scrollDirection: Axis.horizontal,
      itemCount: selected.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final n = selected[i];
        return _NpcCarouselTile(
          uuid: n.uuid,
          image: n.iconImage == null || n.iconImage!.isEmpty
              ? null
              : File('${widget.npcsImagesPath}/${n.iconImage}.png'),
          onDelete: () => _removeNpc(n.name),
          locked: _restricted,
        );
      },
    );
  }

  void _removeImage(String uuid) {
    _model.editImageUuids = _model.editImageUuids
        .where((u) => u != uuid)
        .toList();
  }

  /// The horizontal strip of selected-image tiles: SQUARE previews of the current
  /// image, each with an inset delete button that drops it from scenes.images[].
  Widget _imagesCarousel() {
    final selected = [
      for (final im in widget.images.images)
        if (_model.editImageUuids.contains(im.uuid)) im,
    ];
    return ListView.separated(
      key: const ValueKey('game.scenes.edit.images.carousel'),
      scrollDirection: Axis.horizontal,
      itemCount: selected.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final im = selected[i];
        return _ImageCarouselTile(
          uuid: im.uuid,
          image: File('${widget.imagesOtherPath}/${im.uuid}.png'),
          onDelete: () => _removeImage(im.uuid),
          locked: _restricted,
        );
      },
    );
  }

  String _audioLabel(AppLocalizations l10n) {
    final ids = _model.editAudioUuids;
    if (ids.isEmpty) return l10n.sceneChooseSoundtrack;
    final id = ids.first;
    for (final s in widget.soundtracks.items) {
      if (s.uuid == id) return s.name;
    }
    return l10n.sceneChooseSoundtrack;
  }

  Future<void> _handleSave() async {
    if (!_model.isNameUnique(_model.editName)) {
      await showSceneNameNotUniqueDialog(context);
      return;
    }
    await widget.onSave();
  }

  /// The full-width 4-way scene-type radio (start/standard/recurring/end). Only
  /// one is selected; tapping one writes scenes.scene_type.
  Widget _sceneTypeRow(AppLocalizations l10n) {
    final current = _model.editSceneType;
    // The same glyphs the scene tile shows (sceneTypeIcon), so form and tile
    // never diverge.
    final types = <({String id, String label, IconData icon})>[
      (id: 'start', label: l10n.sceneTypeStart, icon: sceneTypeIcon('start')),
      (
        id: 'standard',
        label: l10n.sceneTypeStandard,
        icon: sceneTypeIcon('standard'),
      ),
      (
        id: 'recurring',
        label: l10n.sceneTypeRecurring,
        icon: sceneTypeIcon('recurring'),
      ),
      (id: 'end', label: l10n.sceneTypeEnd, icon: sceneTypeIcon('end')),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in types)
          _SceneTypeButton(
            keyId: 'game.scenes.edit.scenetype.${t.id}',
            label: t.label,
            icon: t.icon,
            selected: current == t.id,
            // Frozen scene: the type is read-only — grey the buttons out.
            onTap: _restricted ? null : () => _model.editSceneType = t.id,
          ),
      ],
    );
  }

  /// The 18px Material checkbox visual; the path-colour disc below it is 200% of
  /// this (36px).
  static const double _pathCheckboxSize = 18;

  Widget _pathsMultiSelect() {
    final selected = _model.editPathNames;
    return Column(
      key: const ValueKey('game.scenes.edit.paths'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in _model.paths)
          // The whole row toggles the path; the checkbox is purely visual
          // (IgnorePointer) so a tap anywhere counts once. Row order: the
          // path-colour disc on the LEFT, then the checkbox, then the name.
          InkWell(
            key: ValueKey('game.scenes.edit.paths.${p.colorId}'),
            onTap: () => _model.togglePath(p.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _pathDisc(p.colorId),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: _pathCheckboxSize,
                    height: _pathCheckboxSize,
                    child: IgnorePointer(
                      child: Checkbox(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        value: selected.contains(p.name),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The path-colour disc shown at the LEFT of each row — 200% of the checkbox.
  Widget _pathDisc(String colorId) {
    final color = pathColors
        .firstWhere((c) => c.id == colorId, orElse: () => pathColors.first)
        .color;
    return Container(
      key: ValueKey('game.scenes.edit.paths.$colorId.disc'),
      width: _pathCheckboxSize * 2,
      height: _pathCheckboxSize * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Warns that a scene's name must be unique. Shared by the editor's Save and the
/// rail guard's Save.
Future<void> showSceneNameNotUniqueDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('scenes.name.not.unique.dialog'),
      content: Text(l10n.scenesNameNotUnique),
      actions: [
        FilledButton(
          key: const ValueKey('scenes.name.not.unique.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label, required this.keyId});

  final String label;
  final String keyId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(keyId),
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          // Flexible so a long label ellipsises in a narrow column (e.g. the
          // two-column Paths / Visibility row) instead of overflowing.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// One scene-type radio button. Selected -> FilledButton, otherwise
/// OutlinedButton; both carry the same key so a test taps by id regardless of
/// state. SINGLE-ROW: a clearly-visible icon next to a single-line label, in a
/// button tall enough to read the glyph. Sized to its content so a Wrap can flow
/// the four buttons and break onto a second line when the screen is narrow.
class _SceneTypeButton extends StatelessWidget {
  const _SceneTypeButton({
    required this.keyId,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String keyId;
  final String label;
  final IconData icon;
  final bool selected;

  /// Tap handler; `null` disables (greys out) the button — a frozen scene's type
  /// is read-only in save-content editing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(keyId);
    // Taller than the default so the icon reads clearly. The icon's LEFT margin
    // (start) is half its top/bottom (5 vs 10) to tuck the icon in; only the end
    // keeps extra room after the label.
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 52)),
      padding: WidgetStatePropertyAll(
        EdgeInsetsDirectional.fromSTEB(5, 10, 16, 10),
      ),
    );
    // Icon enlarged 70% over the 24px default so the glyph reads clearly.
    final iconWidget = Icon(icon, size: 24 * 1.7);
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return selected
        ? FilledButton.icon(
            key: key,
            style: style,
            onPressed: onTap,
            icon: iconWidget,
            label: labelWidget,
          )
        : OutlinedButton.icon(
            key: key,
            style: style,
            onPressed: onTap,
            icon: iconWidget,
            label: labelWidget,
          );
  }
}

class _AddTileButton extends StatelessWidget {
  const _AddTileButton({
    required this.keyId,
    required this.icon,
    required this.onTap,
  });

  final String keyId;
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
        key: ValueKey(keyId),
        onTap: onTap,
        child: Center(child: Icon(icon, color: scheme.onSurfaceVariant)),
      ),
    );
  }
}

/// One selected-NPC tile in the scene editor's NPC carousel: the NPC icon image
/// (adventure_tile proportions) with an inset round delete button that removes it
/// from the scene. Delete treatment matches the scene / note tile.
/// The round delete button shared by the scene editor's selected tiles (NPC /
/// Notes / Key events / Soundtrack): an onSecondaryContainer circle behind a
/// secondaryContainer Close glyph — the same treatment as the NPC tile.
class _TileDeleteButton extends StatelessWidget {
  const _TileDeleteButton({
    required this.keyValue,
    required this.onPressed,
    this.locked = false,
    this.lockedKey,
  });

  final Key keyValue;
  final VoidCallback onPressed;

  /// When true the item is immutable base content in save-content editing:
  /// a non-interactive lock replaces the delete button.
  final bool locked;

  /// Key of the lock glyph when [locked] (e.g. `<prefix>.tile.<id>.locked`).
  final Key? lockedKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: Container(
        alignment: locked ? Alignment.center : null,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.onSecondaryContainer,
        ),
        child: locked
            ? Icon(
                Icons.lock,
                key: lockedKey,
                size: 16,
                color: scheme.secondaryContainer,
              )
            : IconButton(
                key: keyValue,
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(Icons.close, color: scheme.secondaryContainer),
                onPressed: onPressed,
              ),
      ),
    );
  }
}

class _NpcCarouselTile extends StatelessWidget {
  const _NpcCarouselTile({
    required this.uuid,
    required this.image,
    required this.onDelete,
    this.locked = false,
  });

  final String uuid;
  final File? image;
  final VoidCallback onDelete;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SceneNpcImageTile(
      key: ValueKey('game.scenes.edit.npc.carousel.tile.$uuid'),
      image: image,
      trailing: _TileDeleteButton(
        keyValue: ValueKey('game.scenes.edit.npc.carousel.tile.$uuid.delete'),
        onPressed: onDelete,
        locked: locked,
        lockedKey: ValueKey('game.scenes.edit.npc.carousel.tile.$uuid.locked'),
      ),
    );
  }
}

/// One selected-image tile in the scene editor's Images carousel: a SQUARE
/// preview of the current image (or a placeholder) with an inset top-right delete
/// button (the same treatment as the NPC tile) that drops it from scenes.images[].
class _ImageCarouselTile extends StatelessWidget {
  const _ImageCarouselTile({
    required this.uuid,
    required this.image,
    required this.onDelete,
    this.locked = false,
  });

  final String uuid;
  final File image;
  final VoidCallback onDelete;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        key: ValueKey('game.scenes.edit.images.carousel.tile.$uuid'),
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.existsSync())
              Image.file(image, fit: BoxFit.cover)
            else
              Center(
                child: Icon(
                  Icons.image_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: _TileDeleteButton(
                keyValue: ValueKey(
                  'game.scenes.edit.images.carousel.tile.$uuid.delete',
                ),
                onPressed: onDelete,
                locked: locked,
                lockedKey: ValueKey(
                  'game.scenes.edit.images.carousel.tile.$uuid.locked',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected Background image preview: a SQUARE preview of the chosen image
/// (or a placeholder) with an inset top-right delete button (the same treatment
/// as the NPC tile) that clears scenes.bg_image.
class _BgImageTile extends StatelessWidget {
  const _BgImageTile({
    required this.uuid,
    required this.image,
    required this.onDelete,
    this.locked = false,
  });

  final String uuid;
  final File image;
  final VoidCallback onDelete;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        key: ValueKey('game.scenes.edit.bgimage.tile.$uuid'),
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.existsSync())
              Image.file(image, fit: BoxFit.cover)
            else
              Center(
                child: Icon(
                  Icons.image_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: _TileDeleteButton(
                keyValue: ValueKey(
                  'game.scenes.edit.bgimage.tile.$uuid.delete',
                ),
                onPressed: onDelete,
                locked: locked,
                lockedKey: ValueKey(
                  'game.scenes.edit.bgimage.tile.$uuid.locked',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical list of selected-item tiles (Notes / Key events / Soundtrack).
/// Each tile carries a delete button (the same treatment as the NPC tile) that
/// drops the item from the scene via [onDelete].
class _SelectedColumn extends StatelessWidget {
  const _SelectedColumn({
    required this.keyId,
    required this.tilePrefix,
    required this.icon,
    required this.entries,
    required this.onDelete,
    this.lockedIds = const {},
  });

  final String keyId;
  final String tilePrefix;
  final IconData icon;
  final List<({String id, String label})> entries;
  final void Function(String id) onDelete;

  /// Entry ids that cannot be removed (a lock badge replaces their delete
  /// button) — e.g. a next_scenes link to an immutable scene in save-content
  /// editing.
  final Set<String> lockedIds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: ValueKey(keyId),
      children: [
        for (final e in entries)
          Card(
            key: ValueKey('$tilePrefix.${e.id}'),
            child: ListTile(
              leading: Icon(icon),
              title: Text(e.label),
              trailing: lockedIds.contains(e.id)
                  ? Icon(
                      Icons.lock,
                      key: ValueKey('$tilePrefix.${e.id}.locked'),
                      color: scheme.onSurfaceVariant,
                    )
                  : _TileDeleteButton(
                      keyValue: ValueKey('$tilePrefix.${e.id}.delete'),
                      onPressed: () => onDelete(e.id),
                    ),
            ),
          ),
      ],
    );
  }
}
