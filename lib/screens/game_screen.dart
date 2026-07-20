import 'dart:io';

import 'package:flutter/material.dart';

import '../create/adventure_settings_controller.dart';
import '../create/game_systems.dart';
import '../create/projects_store.dart';
import '../keyevents/key_events_controller.dart';
import '../l10n/app_localizations.dart';
import '../images/adventure_image.dart';
import '../images/bg_images_controller.dart';
import '../images/images_controller.dart';
import '../notes/note_media.dart';
import '../notes/notes_controller.dart';
import '../npcs/npc.dart';
import '../npcs/npcs_controller.dart';
import '../paths/paths_controller.dart';
import '../scenes/scene.dart';
import '../scenes/scenes_controller.dart';
import '../services/audio_metadata.dart';
import '../services/audio_player_service.dart';
import '../services/file_picker_service.dart';
import '../services/publish_validator.dart';
import '../settings/settings_scope.dart';
import '../soundtracks/soundtrack.dart';
import '../soundtracks/soundtracks_controller.dart';
import '../util/uuid.dart';
import '../widgets/npc_tile.dart' show sevenSeaVillain;
import '../widgets/rail_menu_button.dart';
import '../widgets/rail_state.dart';
import 'adventure_settings_screen.dart';
import 'image_form_screen.dart';
import 'library_duplicate_dialog.dart';
import 'publish_result_dialog.dart';
import 'key_event_edit_screen.dart';
import 'images_screen.dart';
import 'key_events_screen.dart';
import 'notes_edit_screen.dart';
import 'notes_screen.dart';
import 'npc_7thsea_screen.dart';
import 'npc_basicrpg_screen.dart';
import 'npcs_screen.dart';
import 'paths_edit_screen.dart';
import 'paths_screen.dart';
import 'play_screen.dart';
import 'scene_edit_screen.dart';
import 'scenes_screen.dart';
// Scene map ("Mapa") disabled for now — kept for future work (see
// docs/scene_map_widget.md). Re-enable with `_sceneMapPage()` and its destination.
// import '../widgets/scene_map/scene_graph.dart';
// import '../widgets/scene_map/scene_map_view.dart';
import '../widgets/scene_tile.dart';
import 'soundtracks_screen.dart';
import 'unsaved_changes_dialog.dart';

/// In-game shell, reached after creating or opening an adventure. A
/// [NavigationRail] holds the in-game sections (Adventure settings, Scenes,
/// Locations, NPC, Key events, Images, Soundtracks, Paths); the leading Menu
/// toggles the rail, and the leading Home destination leaves the game for the
/// app's Home view (via [onHome]).
///
/// The Adventure settings section edits the adventure's metadata + cover in
/// place; every other section is a placeholder for now (icon + title +
/// "Coming soon").
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.slug,
    required this.onHome,
    this.store = const ProjectsStore(),
  }) : isSaveEdit = false;

  /// Opens a started game (`{Saves}/<saveName>`) in the editor for save-content
  /// editing: the store resolves every per-adventure op under
  /// `{Saves}/<saveName>`, and [isSaveEdit] is true so the sections freeze the
  /// immutable base content.
  const GameScreen.save({
    super.key,
    required String saveName,
    required this.onHome,
  }) : slug = saveName,
       store = const ProjectsStore(editBase: AdventureBase.saves),
       isSaveEdit = true;

  /// The adventure being played/edited.
  final String slug;

  /// Invoked when the Home destination is selected: leave the game and show the
  /// app's Home view.
  final VoidCallback onHome;

  final ProjectsStore store;

  /// Whether this editor is operating on a save (`{Saves}/<name>`) rather than a
  /// project — drives the immutable-base freezing in the sections. Set by the
  /// constructor (not read from [store]) so test doubles need not stub it.
  final bool isSaveEdit;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Home leaves the game for the app Home view.
  static const int _homeIndex = 0;

  /// Adventure settings — the in-place metadata + cover editor.
  static const int _settingsIndex = 1;

  /// Scenes — the first content section, shown by default.
  static const int _scenesIndex = 2;

  /// NPC — the NPC grid / edit section.
  static const int _npcsIndex = 3;

  /// Notes — the note grid / edit section.
  static const int _notesIndex = 4;

  /// Key events — the event list / edit section.
  static const int _keyEventsIndex = 5;

  /// Images — the "all photos" grid / add-form section.
  static const int _imagesIndex = 6;

  /// Paths — the path grid / edit section.
  static const int _pathsIndex = 8;

  int _selectedIndex = _scenesIndex;

  /// Rail expanded (icons + labels) vs collapsed (icons only), backed by the
  /// app-wide [RailState] so the choice is preserved across views.
  bool get _extended => RailState.extended.value;

  /// Adventure settings form state + dirty flag, consulted by the rail guard.
  final AdventureSettingsController _settings = AdventureSettingsController();

  /// Paths section state (per-path name/description + edit dirty flag),
  /// consulted by the rail guard.
  final PathsController _paths = PathsController([
    for (final c in pathColors) c.id,
  ]);

  /// Notes section state (notes list + edit dirty flag), consulted by the rail
  /// guard.
  final NotesController _notes = NotesController();

  /// Key events section state (events list + edit dirty flag), consulted by the
  /// rail guard.
  final KeyEventsController _keyEvents = KeyEventsController();

  /// The key events CHECKED during the current preview play-through, keyed by
  /// name. A play session carries the checked state ACROSS scene transitions: a
  /// key event checked in a scene stays checked when the player follows a next
  /// scene (or starts an ad-hoc scene), and a checked event is hidden from the
  /// next scene's Key events row. It is reset to the authored/persisted checked
  /// state each time a FRESH preview is opened from a scene tile (a `replace:
  /// false` open); following a next scene (`replace: true`) keeps it. Preview
  /// never writes this to disk — it is in-session state only.
  Set<String> _sessionCheckedKeyEvents = {};

  /// Soundtracks section state (track list + which track is playing).
  final SoundtracksController _soundtracks = SoundtracksController();

  /// Images section state (the general image pool).
  final ImagesController _images = ImagesController();

  /// The scene BACKGROUND-image pool (files under `images/bg_images/`).
  final BgImagesController _bgImages = BgImagesController();

  /// NPC section state (NPC list + edit dirty flag), consulted by the rail guard.
  final NpcsController _npcs = NpcsController();

  /// Scenes section state (scene list + edit dirty flag), consulted by the rail
  /// guard.
  final ScenesController _scenes = ScenesController();

  /// Absolute path to this adventure's `images/npcs/` dir.
  String _npcsImagesPath = '';

  /// Absolute path to this adventure's `images/other/` dir (the Images grid).
  String _imagesOtherPath = '';

  /// Absolute path to this adventure's `images/bg_images/` dir (scene backgrounds).
  String _bgImagesPath = '';

  /// Absolute path to this adventure's `audio/` dir (scene soundtracks).
  String _audioPath = '';

  /// The adventure's current cover on disk (shown until a new one is staged).
  File? _existingCover;

  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    RailState.extended.addListener(_onRailChanged);
    _loadAdventure();
  }

  /// Rebuilds when the shared rail state changes (e.g. toggled on another view).
  void _onRailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RailState.extended.removeListener(_onRailChanged);
    _settings.dispose();
    _paths.dispose();
    _notes.dispose();
    _keyEvents.dispose();
    AudioPlayerService.instance.stop();
    _soundtracks.dispose();
    _images.dispose();
    _bgImages.dispose();
    _npcs.dispose();
    _scenes.dispose();
    super.dispose();
  }

  Future<void> _loadAdventure() async {
    Map<String, dynamic>? doc;
    File? cover;
    String? imagesOtherPath;
    String? bgImagesPath;
    List<String> bgImages = const [];
    String? npcsImagesPath;
    String? audioPath;
    try {
      doc = await widget.store.read(widget.slug);
      cover = await widget.store.coverFile(widget.slug);
      imagesOtherPath = await widget.store.imagesOtherPath(widget.slug);
      bgImagesPath = await widget.store.bgImagesPath(widget.slug);
      bgImages = await widget.store.listBgImages(widget.slug);
      npcsImagesPath = await widget.store.npcImagesPath(widget.slug);
      audioPath = await widget.store.audioPath(widget.slug);
    } catch (_) {
      // An unreadable adventure (or no path provider in a bare widget test)
      // leaves the Adventure settings section on its loading indicator rather
      // than crashing the game shell.
      return;
    }
    if (!mounted) return;
    setState(() {
      _existingCover = cover;
      _settings.loadFrom(doc ?? const {});
      _paths.loadFrom(doc ?? const {});
      _notes.loadFrom(doc ?? const {});
      _keyEvents.loadFrom(doc ?? const {});
      _soundtracks.loadFrom(doc ?? const {});
      _images.loadFrom(doc ?? const {});
      _npcs.loadFrom(doc ?? const {});
      final npcSystem = _systemOf(doc);
      _npcs.setTemplate(
        GameSystems.templateFor(npcSystem),
        systemId: npcSystem,
        pruneHiddenStats: GameSystems.pruneHiddenStatsFor(npcSystem),
      );
      _scenes.loadFrom(doc ?? const {});
      _imagesOtherPath = imagesOtherPath ?? '';
      _bgImagesPath = bgImagesPath ?? '';
      _bgImages.setAll(bgImages);
      _npcsImagesPath = npcsImagesPath ?? '';
      _audioPath = audioPath ?? '';
      _settingsLoaded = true;
    });
    _refreshNoteMedia();
    _refreshUsedPaths();
  }

  /// Recomputes which path colours are referenced by at least one scene's
  /// `path_names` (matched against each path's STORED name) and pushes the
  /// set to [_paths], so its edit form can refuse to blank the name of a path
  /// a scene still depends on. Called on load and after scenes or paths are
  /// persisted, since either can change the answer.
  void _refreshUsedPaths() {
    final used = <String>{};
    for (final id in _paths.ids) {
      final name = _paths.name(id).trim();
      if (name.isEmpty) continue;
      for (final s in _scenes.scenes) {
        if (s.pathNames.contains(name)) {
          used.add(id);
          break;
        }
      }
    }
    _paths.setUsedIds(used);
  }

  /// Reads `metadata.system` from a decoded document (null when absent).
  static String? _systemOf(Map<String, dynamic>? doc) {
    final meta = doc?['metadata'];
    final system = meta is Map ? meta['system'] : null;
    return system is String ? system : null;
  }

  /// Rebuilds the images a note may embed — the adventure's images
  /// (`images/other/`) plus its NPC portraits (`images/npcs/`) — and hands them
  /// to the Notes controller. Called on load and after the Images / NPC
  /// sections change so a note authored later sees the up-to-date set.
  void _refreshNoteMedia() {
    final media = <NoteMediaRef>[
      for (final img in _images.images)
        NoteMediaRef(
          scope: 'other',
          uuid: img.uuid,
          label: img.name,
          file: File('$_imagesOtherPath/${img.uuid}.png'),
        ),
      for (final npc in _npcs.npcs)
        if (npc.fullImage != null)
          NoteMediaRef(
            scope: 'npc',
            uuid: npc.fullImage!,
            label: npc.name,
            file: File('$_npcsImagesPath/${npc.fullImage}.png'),
          ),
    ];
    _notes.setMedia(media);
  }

  /// Resolves a note image embed's `<scope>:<uuid>` reference to its file on
  /// disk (`other:` -> images/other/, `npc:` -> images/npcs/), so the Play
  /// view's note window can render embedded images. Returns null when missing.
  File? _noteImageFile(String reference) {
    final parsed = NoteMediaRef.parse(reference);
    if (parsed == null) return null;
    final (scope, uuid) = parsed;
    final base = scope == 'npc' ? _npcsImagesPath : _imagesOtherPath;
    final f = File('$base/$uuid.png');
    return f.existsSync() ? f : null;
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      // Re-tapping the CURRENT destination returns a nested form to the
      // section's BASE (list) view, guarded by isDirty exactly like any other
      // navigation away from a form. With no nested form open it is a no-op.
      _returnToSectionBase(index);
      return;
    }

    // Any navigation elsewhere stops soundtrack playback (the Play/Stop glyph
    // resets to Play). Playback only exists while in the Soundtracks section,
    // which has no unsaved-changes guard, so leaving it always proceeds.
    _stopSoundtrackPlayback();

    final leaveTo = index == _homeIndex
        ? widget.onHome
        : () => setState(() => _selectedIndex = index);

    // Leaving a section with unsaved edits is guarded by the Save/Abandon/Cancel
    // prompt.
    final guard = _editorGuardFor(_selectedIndex);
    if (guard != null && guard.isDirty) {
      _confirmLeave(leaveTo, onSave: guard.onSave, onDiscard: guard.onDiscard);
      return;
    }
    // No unsaved edits, so no prompt — but a section left with a pristine
    // (untouched) editor open must still close it, otherwise the controller
    // keeps its edit state and the section re-renders the open form instead of
    // its listing when the user returns.
    _closePristineEdit();
    leaveTo();
  }

  /// Re-tapping the CURRENT rail destination returns a nested form to the
  /// section's BASE (list) view, guarded by isDirty. With no nested form open
  /// (the base view is already showing, or the destination has no nested form)
  /// it is a no-op. The rail stays on the same destination throughout: only the
  /// section's sub-view changes from the form back to its listing.
  void _returnToSectionBase(int index) {
    final guard = _editorGuardFor(index);
    if (guard == null || !guard.isEditing) return; // already at the base view
    if (guard.isDirty) {
      _confirmLeave(
        () => setState(() {}),
        onSave: guard.onSave,
        onDiscard: guard.onDiscard,
      );
    } else {
      guard.onDiscard(); // close the pristine form -> back to the listing
      setState(() {});
    }
  }

  /// The unsaved-changes guard descriptor for the section at [index]: its dirty
  /// + editing state and the Save/Abandon callbacks the rail guard uses. Null
  /// for sections without an editable form (Home, Soundtracks). [isEditing] is
  /// whether a NESTED form is open over the section's base (list) view; the
  /// Adventure settings section's base view IS its form, so it never reports
  /// editing (nothing to pop) though it stays dirty-guarded on a switch.
  ({
    bool isDirty,
    bool isEditing,
    Future<bool> Function() onSave,
    VoidCallback onDiscard,
  })?
  _editorGuardFor(int index) {
    switch (index) {
      case _settingsIndex:
        return (
          isDirty: _settings.isDirty,
          isEditing: false,
          onSave: () async {
            await _persistSettings();
            return true;
          },
          onDiscard: _settings.discard,
        );
      case _pathsIndex:
        return (
          isDirty: _paths.isDirty,
          isEditing: _paths.isEditing,
          onSave: _savePathsEdit,
          onDiscard: _paths.discardEdit,
        );
      case _notesIndex:
        return (
          isDirty: _notes.isDirty,
          isEditing: _notes.isEditing,
          onSave: _saveNotesEdit,
          onDiscard: _notes.cancelEdit,
        );
      case _keyEventsIndex:
        return (
          isDirty: _keyEvents.isDirty,
          isEditing: _keyEvents.isEditing,
          onSave: _saveKeyEventEdit,
          onDiscard: _keyEvents.cancelEdit,
        );
      case _imagesIndex:
        return (
          isDirty: _images.isDirty,
          isEditing: _images.isEditing,
          onSave: _saveImageEdit,
          onDiscard: _images.cancelEdit,
        );
      case _npcsIndex:
        return (
          isDirty: _npcs.isDirty,
          isEditing: _npcs.isEditing,
          onSave: _saveNpcEdit,
          onDiscard: _npcs.cancelEdit,
        );
      case _scenesIndex:
        return (
          isDirty: _scenes.isDirty,
          isEditing: _scenes.isEditing,
          onSave: _saveSceneEdit,
          onDiscard: _scenes.cancelEdit,
        );
      default:
        return null;
    }
  }

  /// Closes a non-dirty editor left open on the current section. Only reached
  /// from the unguarded leave path above, where the section is known not to be
  /// dirty, so this never drops pending work — it just discards an abandoned
  /// pristine draft so the section reopens on its listing.
  void _closePristineEdit() {
    if (_selectedIndex == _notesIndex && _notes.isEditing) {
      _notes.cancelEdit();
    } else if (_selectedIndex == _keyEventsIndex && _keyEvents.isEditing) {
      _keyEvents.cancelEdit();
    } else if (_selectedIndex == _pathsIndex && _paths.isEditing) {
      _paths.discardEdit();
    } else if (_selectedIndex == _imagesIndex && _images.isEditing) {
      _images.cancelEdit();
    } else if (_selectedIndex == _npcsIndex && _npcs.isEditing) {
      _npcs.cancelEdit();
    } else if (_selectedIndex == _scenesIndex && _scenes.isEditing) {
      _scenes.cancelEdit();
    }
  }

  /// Shows the unsaved-changes prompt: Save persists ([onSave]) and proceeds,
  /// Abandon drops the edits ([onDiscard]) and proceeds, Cancel (or a dismissed
  /// dialog) keeps the user on the current section. [onSave] returns `false`
  /// when the save was rejected (e.g. a duplicate note title) — navigation is
  /// then aborted so the user stays on the section to fix the input.
  Future<void> _confirmLeave(
    VoidCallback proceed, {
    required Future<bool> Function() onSave,
    required VoidCallback onDiscard,
  }) async {
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted || choice == null || choice == UnsavedChoice.cancel) return;
    if (choice == UnsavedChoice.save) {
      if (!await onSave()) return;
    } else {
      onDiscard();
    }
    if (!mounted) return;
    proceed();
  }

  /// Writes the Adventure settings form to disk (LivingScroll.json + cover.jpg),
  /// refreshes the on-disk cover preview, and clears the dirty state.
  Future<void> _persistSettings() async {
    final coverChanged = _settings.coverSourcePath != null;
    await widget.store.update(
      slug: widget.slug,
      metadata: _settings.metadata,
      coverSourcePath: _settings.coverSourcePath,
      coverCrop: _settings.coverCrop,
    );
    if (coverChanged) {
      final cover = await widget.store.coverFile(widget.slug);
      if (cover != null) {
        // Drop any cached bytes so the freshly written cover is shown.
        PaintingBinding.instance.imageCache.evict(FileImage(cover));
      }
      _existingCover = cover;
    }
    _settings.markSaved();
  }

  /// Commits the edited path and writes the `paths` collection back to
  /// LivingScroll.json (the Paths editor's Save / the guard's Save).
  Future<void> _persistPaths() async {
    _paths.save();
    await widget.store.writePaths(widget.slug, _paths.toJson());
    // The scene editor's Paths multi-select and the scene tiles' colour discs
    // read the available paths; refresh them after a Paths change.
    _scenes.setPaths(_scenePathRefs());
    _refreshUsedPaths();
  }

  /// The Paths editor's Save button (via [PathsScreen.onSave]) and the rail
  /// guard's Save. Rejects (dialog + abort) an attempt to blank the name of a
  /// path already referenced by a scene's `path_names`; otherwise commits and
  /// persists as before.
  Future<bool> _savePathsEdit() async {
    if (_paths.nameRequiredButEmpty) {
      await showPathNameRequiredDialog(context);
      return false;
    }
    await _persistPaths();
    return true;
  }

  /// Writes the `notes` collection back to LivingScroll.json (after a note Save
  /// or delete).
  Future<void> _persistNotes() async {
    await widget.store.writeNotes(widget.slug, _notes.toJson());
  }

  /// The rail guard's Save for the Notes section. A nameless draft is dropped
  /// (nothing to persist). A duplicate title is rejected: it warns and returns
  /// `false` so navigation is aborted and the user stays on the edit — matching
  /// the editor's own Save. Otherwise it commits the edit and persists.
  Future<bool> _saveNotesEdit() async {
    if (!_notes.canSave) {
      _notes.cancelEdit();
      return true;
    }
    if (!_notes.isNameUnique(_notes.editName)) {
      await showNotesNameNotUniqueDialog(context);
      return false;
    }
    _notes.save();
    await _persistNotes();
    return true;
  }

  /// Writes the `key_events` collection back to LivingScroll.json (after an event
  /// Save) and refreshes the Notes visibility editor's available events, so a
  /// note authored later in the same session sees the new/renamed event.
  Future<void> _persistKeyEvents() async {
    await widget.store.writeKeyEvents(widget.slug, _keyEvents.toJson());
    final refs = [
      for (final e in _keyEvents.events) (uuid: e.uuid, name: e.name),
    ];
    _notes.setKeyEvents(refs);
    _images.setKeyEvents(refs);
    _npcs.setKeyEvents(refs);
    _scenes.setKeyEvents(refs);
  }

  /// The adventure's named paths (colourId + name) for the scene editor's Paths
  /// multi-select and the scene tile's colour discs.
  List<ScenePathRef> _scenePathRefs() => [
    for (final id in _paths.ids)
      if (_paths.name(id).trim().isNotEmpty)
        (colorId: id, name: _paths.name(id).trim()),
  ];

  /// Writes the `scenes` collection back to LivingScroll.json (after a Save /
  /// delete).
  Future<void> _persistScenes() async {
    await widget.store.writeScenes(widget.slug, _scenes.toJson());
    // A scene's path_names can change which paths are in use; refresh so the
    // Paths editor's name-required check stays accurate.
    _refreshUsedPaths();
  }

  /// The Publish action (rail trailing): validates the SAVED adventure for
  /// publish-readiness and shows the result — a list of problems to fix, or a
  /// success message. (Producing the published file is a separate step.)
  Future<void> _handlePublish() async {
    final doc = await widget.store.read(widget.slug);
    if (!mounted) return;
    final issues = const PublishValidator().validate(doc);
    if (issues.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => PublishResultDialog(issues: issues),
      );
      return;
    }
    // Already in the library? Consult the fast index (Settings/adventures.json):
    // an adventure with the SAME identity (title/version/system/author/language)
    // -> offer Overwrite / Cancel before writing.
    final dup = await widget.store.findLibraryDuplicate(doc?['metadata']);
    if (!mounted) return;
    var overwrite = false;
    if (dup != null) {
      final choice = await showLibraryDuplicateDialog(context);
      if (choice != true) return; // Cancel -> nothing is written.
      overwrite = true;
    }

    // Save the UNPACKED adventure into the Adventures library (overwriting the
    // existing copy when chosen), then confirm and offer the `.ls` download.
    final result = await widget.store.export(widget.slug, overwrite: overwrite);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => PublishResultDialog(
        issues: const [],
        downloadLabel: l10n.publishDownloadLs,
        onDownload: () =>
            _downloadBytes(result.archiveBytes, result.suggestedFileName),
      ),
    );
  }

  /// "Export elements": a lenient partial export (name + system only). On pass it
  /// builds a TEMPORARY `.lse` (nowhere permanent), offers it as a download, and
  /// deletes the temp file once the dialog closes.
  Future<void> _handleExportPart() async {
    final doc = await widget.store.read(widget.slug);
    if (!mounted) return;
    final issues = const PartExportValidator().validate(doc);
    if (issues.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => PublishResultDialog(issues: issues),
      );
      return;
    }
    final result = await widget.store.exportPart(widget.slug);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => PublishResultDialog(
        issues: const [],
        validMessage: l10n.publishElementsReady,
        downloadLabel: l10n.publishDownloadLse,
        dismissOnDownload: true,
        onDownload: () =>
            _downloadCopy(result.tempFile, result.suggestedFileName),
      ),
    );
    // The temp `.lse` is kept nowhere permanent — drop it once the dialog closes.
    await widget.store.deleteTemp(result.tempFile);
  }

  /// Saves [bytes] to a user-chosen location (native save dialog). Returns
  /// `true` when saved, `false` when cancelled.
  Future<bool> _downloadBytes(List<int> bytes, String fileName) async {
    final path = await FilePickerService.instance.saveFile(fileName: fileName);
    if (path == null) return false;
    await File(path).writeAsBytes(bytes);
    return true;
  }

  /// Copies [source] to a user-chosen location (native save dialog). Returns
  /// `true` when saved, `false` when cancelled.
  Future<bool> _downloadCopy(File source, String fileName) async {
    final path = await FilePickerService.instance.saveFile(fileName: fileName);
    if (path == null) return false;
    await source.copy(path);
    return true;
  }

  /// Opens the Play view in PREVIEW mode for [scene] (the scene tile's Preview
  /// glyph). Read-only: toggling key events / following next scenes navigates the
  /// preview only; nothing is persisted.
  ///
  /// Following a next scene [replace]s the current preview rather than stacking a
  /// new route, so the preview is always a SINGLE route: Pause then exits straight
  /// back to the editor (the Scenes list), not to the previously viewed scene.
  ///
  /// The replacement uses a NO-TRANSITION route (zero duration, identity builder)
  /// so changing scenes just swaps the rail + content in place, with no page
  /// animation. The initial open (from a scene tile) keeps the normal transition.
  void _openScenePreview(Scene scene, {bool replace = false}) {
    if (!replace) {
      // A fresh preview session (opened from a scene tile) starts from the
      // authored/persisted checked state; following next scenes accumulates more.
      _sessionCheckedKeyEvents = {
        for (final e in _keyEvents.events)
          if (e.checked) e.name,
      };
    }
    if (replace) {
      Navigator.of(context).pushReplacement<void, void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => _scenePreview(scene),
        ),
      );
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => _scenePreview(scene)),
      );
    }
  }

  Widget _scenePreview(Scene scene) {
    // The scene's background: its bg_image (images/bg_images/<uuid>.png), or none.
    File? bgImage;
    if (scene.bgImage.isNotEmpty) {
      final f = File('$_bgImagesPath/${scene.bgImage}.png');
      if (f.existsSync()) bgImage = f;
    }

    final keyEvents = [
      for (final n in scene.keyEventNames)
        (name: n, checked: _keyEventChecked(n)),
    ];
    // next_scenes store target scene_uuids; resolve each to its scene for the
    // label / discs / visibility gate. A dangling uuid (target deleted) is
    // skipped so it never renders an empty button.
    final nextScenes = <PlayNextScene>[
      for (final uuid in scene.nextSceneUuids)
        if (_sceneByUuid(uuid) case final t?)
          (
            uuid: uuid,
            name: t.name,
            discs: _discsForScene(t),
            op: t.visibility.op,
            requiredEvents: _visibilityEventNames(t),
            visited: t.extra['visited'] == true,
            // The editor preview has no party tracks — never a merge target.
            occupiedByOtherTrack: false,
          ),
    ];
    final notes = <({String uuid, String name, String content})>[];
    for (final uuid in scene.noteUuids) {
      for (final note in _notes.notes) {
        if (note.uuid == uuid) {
          notes.add((uuid: note.uuid, name: note.name, content: note.content));
          break;
        }
      }
    }
    final images = [
      for (final uuid in scene.imageUuids) File('$_imagesOtherPath/$uuid.png'),
    ];
    // The scene's soundtrack: the first attached audio track whose file exists.
    // Autoplay follows the app-wide Music setting (default on).
    final soundtrack = _sceneSoundtrackFile(scene);
    final autoplay = SettingsScope.of(context).overrides.autoplayOn;
    final npcs = <PlayNpc>[];
    for (final name in scene.npcNames) {
      for (final npc in _npcs.npcs) {
        if (npc.name == name) {
          File? resolve(String? uuid) {
            if (uuid == null || uuid.isEmpty) return null;
            final f = File('$_npcsImagesPath/$uuid.png');
            return f.existsSync() ? f : null;
          }

          npcs.add((
            uuid: npc.uuid,
            name: npc.name,
            iconImage: resolve(npc.iconImage),
            fullImage: resolve(npc.fullImage),
            description: npc.description,
            backstory: npc.backstory,
            state: npc.state,
            // Basic RPG has no stat template; future systems resolve values here.
            stats: const <({String label, String value})>[],
            villain: sevenSeaVillain(_npcs.systemId, npc.extra['stats']),
            sevenSeaStats: npc.extra['stats'] is Map
                ? Map<String, dynamic>.from(npc.extra['stats'] as Map)
                : <String, dynamic>{},
          ));
          break;
        }
      }
    }

    return PlayScreen(
      scene: scene,
      mode: PlayMode.preview,
      backgroundImage: bgImage,
      keyEvents: keyEvents,
      nextScenes: nextScenes,
      npcs: npcs,
      villains: _villainsForPreview(),
      notes: notes,
      images: images,
      soundtrack: soundtrack,
      autoplayMusic: autoplay,
      noteImageResolver: _noteImageFile,
      onExit: () => Navigator.of(context).pop(),
      onFollowScene: (uuid, checked, deactivated) {
        // Commit the scene's checked key events before advancing: the next scene
        // inherits them (and hides any it shares from its Key events row). The
        // editor preview never persists, so NPC deactivations are session-only.
        _sessionCheckedKeyEvents = checked;
        final t = _sceneByUuid(uuid);
        if (t != null) _openScenePreview(t, replace: true);
      },
      onAdHoc: (name, checked, deactivated) {
        _sessionCheckedKeyEvents = checked;
        _openScenePreview(_adHocSceneFrom(scene, name), replace: true);
      },
    );
  }

  /// The synthetic scene started by the Ad-hoc button on [from]: an improvised
  /// scene not authored in `next_scenes[]`. It carries no narration, location or
  /// other content of its own, but INHERITS [from]'s next scenes verbatim — an
  /// ad-hoc scene continues to exactly the same set of follow-up scenes as the
  /// scene it was started from (so play can detour through it and rejoin the
  /// authored graph). It is a standard scene, so it offers its own Ad-hoc button.
  Scene _adHocSceneFrom(Scene from, String name) => Scene(
    // The editor preview stays ephemeral (no track, no persistence); it just
    // previews the named ad-hoc scene with the inherited next_scenes.
    uuid: '',
    name: name.isEmpty ? AppLocalizations.of(context).playAdHocScene : name,
    sceneType: Scene.defaultSceneType,
    nextSceneUuids: List<String>.from(from.nextSceneUuids),
  );

  /// The on-disk file for the scene's first attached soundtrack (`audio/<uuid>.<ext>`),
  /// or `null` when the scene has no music or the file is missing. Resolved
  /// synchronously (the preview builds without awaiting) by scanning [_audioPath].
  File? _sceneSoundtrackFile(Scene scene) {
    if (scene.audioUuids.isEmpty || _audioPath.isEmpty) return null;
    final dir = Directory(_audioPath);
    if (!dir.existsSync()) return null;
    final files = dir.listSync().whereType<File>().toList();
    for (final uuid in scene.audioUuids) {
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final base = dot > 0 ? name.substring(0, dot) : name;
        if (base == uuid) return f;
      }
    }
    return null;
  }

  /// Whether [name] is checked in the CURRENT preview play-through (the session
  /// state carried across scene transitions — see [_sessionCheckedKeyEvents]),
  /// NOT the authored value. A checked event arrives `checked: true` to the Play
  /// view, which hides it from the Key events row.
  bool _keyEventChecked(String name) => _sessionCheckedKeyEvents.contains(name);

  /// ALL 7th Sea Villain-kind NPCs in the WHOLE adventure (`_npcs.npcs`),
  /// regardless of scene attachment — feeds the preview's Play view Villains
  /// tab. An `inactive` villain is INCLUDED (not filtered out) so its tile
  /// shows greyed instead of disappearing (unlike the scene-scoped NPC grid).
  List<PlayNpc> _villainsForPreview() {
    final out = <PlayNpc>[];
    for (final npc in _npcs.npcs) {
      final villain = sevenSeaVillain(_npcs.systemId, npc.extra['stats']);
      if (villain?.kind != 'villain') continue;
      File? resolve(String? uuid) {
        if (uuid == null || uuid.isEmpty) return null;
        final f = File('$_npcsImagesPath/$uuid.png');
        return f.existsSync() ? f : null;
      }

      out.add((
        uuid: npc.uuid,
        name: npc.name,
        iconImage: resolve(npc.iconImage),
        fullImage: resolve(npc.fullImage),
        description: npc.description,
        backstory: npc.backstory,
        state: npc.state,
        stats: const <({String label, String value})>[],
        villain: villain,
        sevenSeaStats: npc.extra['stats'] is Map
            ? Map<String, dynamic>.from(npc.extra['stats'] as Map)
            : <String, dynamic>{},
      ));
    }
    return out;
  }

  Scene? _sceneByUuid(String uuid) {
    for (final s in _scenes.scenes) {
      if (s.uuid == uuid) return s;
    }
    return null;
  }

  /// The path-colour discs of scene [t], shown on a next-scene button in the
  /// preview.
  List<SceneTileDisc> _discsForScene(Scene t) {
    return [
      for (final p in _scenes.paths)
        if (t.pathNames.contains(p.name))
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
  }

  /// Scene [t]'s visibility gate, resolved from stored key_event_uuids to
  /// key-event NAMES (the play view evaluates the gate against checked
  /// key-event names). Unknown uuids are dropped.
  List<String> _visibilityEventNames(Scene t) {
    final names = <String>[];
    for (final uuid in t.visibility.keyEvents) {
      for (final e in _keyEvents.events) {
        if (e.uuid == uuid) {
          names.add(e.name);
          break;
        }
      }
    }
    return names;
  }

  /// The rail guard's Save for the Scenes section. A nameless draft is dropped; a
  /// duplicate name is rejected (warn + abort); otherwise the scene is committed
  /// and persisted.
  Future<bool> _saveSceneEdit() async {
    if (!_scenes.canSave) {
      _scenes.cancelEdit();
      return true;
    }
    if (!_scenes.isNameUnique(_scenes.editName)) {
      await showSceneNameNotUniqueDialog(context);
      return false;
    }
    _scenes.save();
    await _persistScenes();
    return true;
  }

  // --- Scene picker create-and-select hooks -------------------------------
  // Each opens the entity's existing create form (bound to the section
  // controller) in a pushed route; on Save it persists and returns the new
  // item's select-id so the picker auto-selects it.

  Future<String?> _createKeyEventForScene(BuildContext context) async {
    final before = _keyEvents.events.length;
    _keyEvents.beginNew();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          body: SafeArea(
            child: KeyEventEditScreen(
              controller: _keyEvents,
              onSave: () async {
                _keyEvents.save();
                await _persistKeyEvents();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              onCancel: () {
                _keyEvents.cancelEdit();
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );
    if (_keyEvents.events.length > before) return _keyEvents.events.last.name;
    return null;
  }

  /// The scene NPC picker's "create new NPC" cell: open the SAME system-specific
  /// editor as the NPC section (Basic RPG / 7th Sea 2e) in a pushed route;
  /// on Save it persists and returns the new NPC's NAME so the picker auto-selects
  /// it (a scene references NPCs by name — `_pickNpcs`).
  Future<String?> _createNpcForScene(BuildContext context) async {
    final before = _npcs.npcs.length;
    _npcs.beginNew();
    Widget editor(BuildContext ctx) {
      Future<void> onSave() async {
        await _saveNpcEditFromForm();
        if (ctx.mounted) Navigator.of(ctx).pop();
      }

      void onCancel() {
        _npcs.cancelEdit();
        Navigator.of(ctx).pop();
      }

      // Same dispatch as NpcsScreen: empty template -> Basic RPG; any other
      // (7th Sea) -> its kind-driven form.
      if (_npcs.template.isEmpty) {
        return NpcBasicRpgScreen(
          controller: _npcs,
          imagesBasePath: _npcsImagesPath,
          onSave: onSave,
          onCancel: onCancel,
        );
      }
      return Npc7thSeaScreen(
        controller: _npcs,
        imagesBasePath: _npcsImagesPath,
        onSave: onSave,
        onCancel: onCancel,
      );
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(body: SafeArea(child: editor(ctx))),
      ),
    );
    if (_npcs.npcs.length > before) return _npcs.npcs.last.name;
    return null;
  }

  Future<String?> _createNoteForScene(BuildContext context) async {
    final before = _notes.notes.length;
    _notes.beginNew();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          body: SafeArea(
            child: NotesEditScreen(
              controller: _notes,
              onSave: () async {
                if (_notes.save()) await _persistNotes();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              onCancel: () {
                _notes.cancelEdit();
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );
    if (_notes.notes.length > before) return _notes.notes.last.uuid;
    return null;
  }

  Future<String?> _createSoundtrackForScene(BuildContext context) async {
    final path = await FilePickerService.instance.pickAudio();
    if (path == null || !mounted) return null;
    final name = deriveSoundtrackName(path);
    if (!_soundtracks.isNameUnique(name)) {
      if (context.mounted) await showSoundtrackNameNotUniqueDialog(context);
      return null;
    }
    final uuid = _soundtracks.add(name);
    await widget.store.importAudio(widget.slug, path, uuid);
    await widget.store.writeAudio(widget.slug, _soundtracks.toJson());
    return uuid;
  }

  /// The rail guard's Save for the Key events section. Same contract as
  /// [_saveNotesEdit]: drop a nameless draft, reject a duplicate name (warn +
  /// abort), otherwise commit and persist.
  Future<bool> _saveKeyEventEdit() async {
    if (!_keyEvents.canSave) {
      _keyEvents.cancelEdit();
      return true;
    }
    if (!_keyEvents.isNameUnique(_keyEvents.editName)) {
      await showKeyEventNameNotUniqueDialog(context);
      return false;
    }
    _keyEvents.save();
    await _persistKeyEvents();
    return true;
  }

  /// Cascade-deletes a key_event: strips every reference to its name on disk
  /// (notes' visibility_rules, scenes' key_events) and removes the event, then
  /// reloads so the in-memory state matches.
  Future<void> _deleteKeyEvent(String name) async {
    await widget.store.deleteKeyEvent(widget.slug, name);
    final doc = await widget.store.read(widget.slug);
    if (!mounted) return;
    setState(() {
      _keyEvents.loadFrom(doc ?? const {});
      _notes.loadFrom(doc ?? const {});
    });
  }

  // --- Soundtracks --------------------------------------------------------

  /// The "Add soundtrack" action: pick an audio file, derive its display name
  /// (track title (+ artist), else file name without extension), and — when the
  /// name is unique — copy the file into `audio/<uuid>.<ext>` and append it to
  /// `audio[]`. A duplicate derived name is rejected with the not-unique dialog
  /// and nothing is copied or written.
  Future<void> _addSoundtrack() async {
    final path = await FilePickerService.instance.pickAudio();
    if (path == null || !mounted) return;
    final name = deriveSoundtrackName(path);
    if (!_soundtracks.isNameUnique(name)) {
      await showSoundtrackNameNotUniqueDialog(context);
      return;
    }
    final uuid = _soundtracks.add(name);
    await widget.store.importAudio(widget.slug, path, uuid);
    await widget.store.writeAudio(widget.slug, _soundtracks.toJson());
  }

  /// Deletes a soundtrack (after the tile's confirm dialog): stops it if playing,
  /// removes the `audio[]` entry and its file, then persists.
  Future<void> _deleteSoundtrack(Soundtrack track) async {
    if (_soundtracks.isPlaying(track.uuid)) {
      await AudioPlayerService.instance.stop();
    }
    _soundtracks.delete(track.uuid);
    await widget.store.deleteAudioFile(widget.slug, track.uuid);
    await widget.store.writeAudio(widget.slug, _soundtracks.toJson());
  }

  /// The tile's Play/Stop toggle: stop if this track is playing, otherwise start
  /// it FROM THE BEGINNING (stopping any other track). Drives the glyph via the
  /// controller's playing state.
  Future<void> _togglePlaySoundtrack(Soundtrack track) async {
    if (_soundtracks.isPlaying(track.uuid)) {
      await AudioPlayerService.instance.stop();
      _soundtracks.setPlaying(null);
      return;
    }
    final file = await widget.store.audioFile(widget.slug, track.uuid);
    if (file == null) return;
    await AudioPlayerService.instance.playFromStart(file.path);
    if (!mounted) return;
    _soundtracks.setPlaying(track.uuid);
  }

  /// Stops soundtrack playback (if any) and resets the glyph to Play. Called on
  /// navigation away and on dispose.
  void _stopSoundtrackPlayback() {
    if (_soundtracks.playingUuid != null) {
      AudioPlayerService.instance.stop();
      _soundtracks.setPlaying(null);
    }
  }

  // --- NPCs ---------------------------------------------------------------

  /// Writes the `npcs` collection back to LivingScroll.json (after a Save).
  Future<void> _persistNpcs() async {
    await widget.store.writeNpcs(widget.slug, _npcs.toJson());
    _refreshNoteMedia(); // a new/changed NPC portrait is now embeddable in notes
  }

  /// Writes the staged NPC images to disk (full at 1000x1430, icon at 400x572)
  /// and records their ids on the controller. No-op when no new image was staged.
  /// Replacing images deletes the previous files first.
  Future<void> _commitNpcImages() async {
    final staged = _npcs.editFullStagedPath;
    final iconCrop = _npcs.editIconCrop;
    if (staged == null || iconCrop == null) return;
    await widget.store.deleteNpcImage(widget.slug, _npcs.editFullImageUuid);
    await widget.store.deleteNpcImage(widget.slug, _npcs.editIconImageUuid);
    final fullUuid = uuidV4();
    final iconUuid = uuidV4();
    await widget.store.writeNpcFullImage(widget.slug, staged, fullUuid);
    await widget.store.writeNpcIconImage(
      widget.slug,
      staged,
      iconCrop,
      iconUuid,
    );
    _npcs.setEditImageUuids(fullUuid, iconUuid);
  }

  /// The NPC editor's Save: commit the staged images, then the entry, then
  /// persist. The editor has already enforced name uniqueness.
  Future<void> _saveNpcEditFromForm() async {
    await _commitNpcImages();
    if (_npcs.save()) await _persistNpcs();
  }

  /// The rail guard's Save for the NPC section. A draft missing required fields is
  /// dropped; a duplicate name is rejected (warn + abort); otherwise the staged
  /// images are written, the entry committed and persisted.
  Future<bool> _saveNpcEdit() async {
    if (!_npcs.canSave) {
      _npcs.cancelEdit();
      return true;
    }
    if (!_npcs.isNameUnique(_npcs.editName)) {
      await showNpcNameNotUniqueDialog(context);
      return false;
    }
    await _commitNpcImages();
    _npcs.save();
    await _persistNpcs();
    return true;
  }

  /// Clones an NPC (the tile's Clone menu): the store appends a copy with a fresh
  /// npc_uuid, a unique name and copied images; then reload so the grid shows it.
  Future<void> _cloneNpc(Npc npc) async {
    await widget.store.cloneNpc(widget.slug, npc.uuid);
    final doc = await widget.store.read(widget.slug);
    if (!mounted) return;
    setState(() => _npcs.loadFrom(doc ?? const {}));
  }

  /// Cascade-deletes an NPC (after the tile's confirm dialog): the store removes
  /// its entry, strips scene references by name and deletes its images; then
  /// reload so the grid matches disk.
  Future<void> _deleteNpc(Npc npc) async {
    await widget.store.deleteNpc(widget.slug, npc.uuid);
    final doc = await widget.store.read(widget.slug);
    if (!mounted) return;
    setState(() => _npcs.loadFrom(doc ?? const {}));
  }

  // --- Images -------------------------------------------------------------

  /// Writes the `images` collection back to LivingScroll.json (after an add or
  /// delete).
  Future<void> _persistImages() async {
    await widget.store.writeImages(widget.slug, _images.toJson());
    _refreshNoteMedia(); // a new/removed image changes what notes can embed
  }

  /// The Images add form's Add (and the rail guard's Save): commit the staged
  /// image. With no image staged the draft is dropped (the image is required).
  /// Otherwise the image is converted to PNG and written to
  /// `images/other/<image_uuid>.png`, appended to images[] (name = file name
  /// without extension, plus the visibility gate) and persisted. The file is
  /// written BEFORE the entry is added so the new tile renders an existing file.
  Future<bool> _saveImageEdit() async {
    if (!_images.isNew) {
      // EDIT — only the visibility gate changed; the image file is unchanged.
      _images.commitEdit();
      await _persistImages();
      return true;
    }
    final source = _images.editImageSource;
    if (source == null) {
      _images.cancelEdit();
      return true;
    }
    final imageUuid = uuidV4();
    await widget.store.importImage(widget.slug, source, imageUuid);
    _images.commitNew(imageUuid, _fileNameWithoutExtension(source));
    await _persistImages();
    return true;
  }

  /// The scene editor's image picker "add" action: open the new-image form,
  /// and on commit return the new image's uuid so the picker auto-selects it.
  /// Cancel/Back returns null (nothing added, nothing selected).
  Future<String?> _createImageForScene(BuildContext context) async {
    final before = _images.images.length;
    _images.beginNew();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          body: SafeArea(
            child: ImageFormScreen(
              controller: _images,
              imagesBasePath: _imagesOtherPath,
              onCommit: () async {
                await _saveImageEdit();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              onCancel: () {
                _images.cancelEdit();
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );
    if (_images.images.length > before) return _images.images.last.uuid;
    return null;
  }

  /// The Background image picker's "add" action: pick an image file and write it
  /// (converted to PNG) to `images/bg_images/`, returning the new uuid so the
  /// picker auto-selects it as the scene's bg_image. A background image has NO
  /// visibility rules and no metadata form — just the file. Cancel returns null.
  Future<String?> _createBgImageForScene(BuildContext context) async {
    final path = await FilePickerService.instance.pickImage();
    if (path == null) return null;
    final uuid = uuidV4();
    await widget.store.importBgImage(widget.slug, path, uuid);
    _bgImages.add(uuid);
    return uuid;
  }

  /// Deletes an image (after the tile's confirm dialog): removes its file, drops
  /// the entry and persists.
  Future<void> _deleteImage(AdventureImage image) async {
    await widget.store.deleteImageFile(widget.slug, image.uuid);
    _images.delete(image.uuid);
    await _persistImages();
  }

  /// The file name of [path] without its directory or extension.
  String _fileNameWithoutExtension(String path) {
    var name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// The Adventure settings Save button: persist, then return to the game's
  /// content (the Scenes section) — "NAVIGATE TO LAYOUT: game".
  Future<void> _saveFromForm() async {
    await _persistSettings();
    if (!mounted) return;
    setState(() => _selectedIndex = _scenesIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.home_outlined, key: ValueKey('nav.game.home')),
        selectedIcon: const Icon(Icons.home, key: ValueKey('nav.game.home')),
        label: Text(l10n.navHome),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.settings_outlined,
          key: ValueKey('nav.game.settings'),
        ),
        selectedIcon: const Icon(
          Icons.settings,
          key: ValueKey('nav.game.settings'),
        ),
        label: Text(l10n.gameAdventureSettings),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.videocam_outlined,
          key: ValueKey('nav.game.scenes'),
        ),
        selectedIcon: const Icon(
          Icons.videocam,
          key: ValueKey('nav.game.scenes'),
        ),
        label: Text(l10n.gameScenes),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.person_outlined, key: ValueKey('nav.game.npcs')),
        selectedIcon: const Icon(Icons.person, key: ValueKey('nav.game.npcs')),
        label: Text(l10n.gameNpcs),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.library_books_outlined,
          key: ValueKey('nav.game.notes'),
        ),
        selectedIcon: const Icon(
          Icons.library_books,
          key: ValueKey('nav.game.notes'),
        ),
        label: Text(l10n.gameNotes),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.library_add_check_outlined,
          key: ValueKey('nav.game.keyevents'),
        ),
        selectedIcon: const Icon(
          Icons.library_add_check,
          key: ValueKey('nav.game.keyevents'),
        ),
        label: Text(l10n.gameKeyEvents),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.photo_library_outlined,
          key: ValueKey('nav.game.images'),
        ),
        selectedIcon: const Icon(
          Icons.photo_library,
          key: ValueKey('nav.game.images'),
        ),
        label: Text(l10n.gameImages),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.library_music_outlined,
          key: ValueKey('nav.game.soundtracks'),
        ),
        selectedIcon: const Icon(
          Icons.library_music,
          key: ValueKey('nav.game.soundtracks'),
        ),
        label: Text(l10n.gameSoundtracks),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.alt_route_outlined,
          key: ValueKey('nav.game.paths'),
        ),
        selectedIcon: const Icon(
          Icons.alt_route,
          key: ValueKey('nav.game.paths'),
        ),
        label: Text(l10n.gamePaths),
      ),
      // MAP — the scene map for the whole adventure. DISABLED for now (kept for
      // future work; see docs/scene_map_widget.md). Re-enable this destination
      // together with the `_sceneMapPage()` entry in `pages` below.
      // NavigationRailDestination(
      //   icon: const Icon(Icons.map_outlined, key: ValueKey('nav.game.map')),
      //   selectedIcon: const Icon(Icons.map, key: ValueKey('nav.game.map')),
      //   label: Text(l10n.navMap),
      // ),
    ];

    // Index 0 (Home) is an action, never shown as content.
    final pages = <Widget>[
      const SizedBox.shrink(),
      _settingsPage(),
      // Scenes — the scene list + editor.
      ScenesScreen(
        controller: _scenes,
        onPersist: _persistScenes,
        onPreview: _openScenePreview,
        npcs: _npcs,
        notes: _notes,
        keyEvents: _keyEvents,
        images: _images,
        soundtracks: _soundtracks,
        bgImages: _bgImages,
        npcsImagesPath: _npcsImagesPath,
        imagesOtherPath: _imagesOtherPath,
        bgImagesPath: _bgImagesPath,
        onCreateNpc: _createNpcForScene,
        onCreateNote: _createNoteForScene,
        onCreateKeyEvent: _createKeyEventForScene,
        onCreateImage: _createImageForScene,
        onCreateBgImage: _createBgImageForScene,
        onCreateSoundtrack: _createSoundtrackForScene,
        readOnly: widget.isSaveEdit,
      ),
      NpcsScreen(
        controller: _npcs,
        imagesBasePath: _npcsImagesPath,
        onSave: _saveNpcEditFromForm,
        onClone: _cloneNpc,
        onDelete: _deleteNpc,
        readOnly: widget.isSaveEdit,
      ),
      NotesScreen(
        controller: _notes,
        onPersist: _persistNotes,
        readOnly: widget.isSaveEdit,
      ),
      KeyEventsScreen(
        controller: _keyEvents,
        onPersist: _persistKeyEvents,
        onDeleteEvent: _deleteKeyEvent,
        readOnly: widget.isSaveEdit,
      ),
      ImagesScreen(
        controller: _images,
        imagesBasePath: _imagesOtherPath,
        onCommit: _saveImageEdit,
        onDelete: _deleteImage,
        readOnly: widget.isSaveEdit,
      ),
      SoundtracksScreen(
        controller: _soundtracks,
        onAdd: _addSoundtrack,
        onDelete: _deleteSoundtrack,
        onTogglePlay: _togglePlaySoundtrack,
        readOnly: widget.isSaveEdit,
      ),
      PathsScreen(
        controller: _paths,
        onSave: _persistPaths,
        readOnly: widget.isSaveEdit,
      ),
      // Scene map page — DISABLED (kept for future work; see
      // docs/scene_map_widget.md). Re-enable with the `nav.game.map` destination.
      // _sceneMapPage(),
    ];

    return Scaffold(
      key: const ValueKey('game.root'),
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              // Key by the extended state so toggling the rail REPLACES it with a
              // fresh instance whose extend controller initialises AT the target
              // value (initState), instead of animating to it (didUpdateWidget ->
              // forward/reverse). The whole rail — destinations AND the bottom
              // Export actions — is therefore STATIC: expand/collapse is instant,
              // with no slide/reveal animation. (Section switches keep the same
              // key, so the selection indicator still animates normally.)
              key: ValueKey('game.rail.$_extended'),
              leading: RailMenuButton(
                tooltip: l10n.menuTooltip,
                onTap: RailState.toggle,
              ),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              extended: _extended,
              labelType: NavigationRailLabelType.none,
              // Scroll the destinations when the viewport is short, so the many
              // sections + the bottom Export actions never overflow the rail.
              scrollable: true,
              destinations: destinations,
              // PUBLISH — pinned to the rail's bottom; an action (validate the
              // adventure for publishing), not a navigable destination. Hidden in
              // save-content editing: a save is not exported.
              trailingAtBottom: true,
              trailing: widget.isSaveEdit ? null : _publishRailButton(l10n),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }

  /// The rail's default extended width (matches `NavigationRail`'s
  /// `minExtendedWidth` default, which this rail does not override). When
  /// expanded, the bottom actions fill this width so they sit at the LEFT edge
  /// like the destinations, instead of the (narrower) action block being
  /// centered by the rail's trailing slot.
  static const double _railExtendedWidth = 256;

  /// The rail's default collapsed width (matches `NavigationRail`'s `minWidth`
  /// default). Each destination centers its icon in a leading box THIS wide;
  /// the bottom actions reuse it as their leading icon box so their icons — and
  /// therefore their labels — line up exactly with the destinations.
  static const double _railMinWidth = 80;

  /// The rail's icon size (matches `NavigationRail`'s default icon theme size),
  /// so the footer action icons are the SAME size collapsed and expanded — and
  /// the same size as the destination icons (a `TextButton`'s default icon size
  /// is 18, which would render the expanded footer icons smaller).
  static const double _railIconSize = 24;

  /// The rail's bottom actions: Export (full) and, below it, Export elements
  /// (partial `.lse`). Both are actions, not destinations.
  ///
  /// Collapsed: centered icon buttons (with tooltips), like the collapsed
  /// destinations. Expanded: each action mirrors a [NavigationRailDestination] —
  /// a fixed [_railMinWidth]-wide leading box with the icon CENTERED, then the
  /// label, in a fixed [_railExtendedWidth] block that the trailing slot centres,
  /// so the action icons/labels line up with the destinations. The expanded
  /// footer is rendered STATICALLY (no per-element reveal/grow animation): it
  /// simply appears at its final layout when the rail is expanded.
  Widget _publishRailButton(AppLocalizations l10n) {
    if (!_extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('nav.game.publish'),
              tooltip: l10n.gamePublish,
              icon: const Icon(Icons.publish, size: _railIconSize),
              onPressed: _handlePublish,
            ),
            const SizedBox(height: 4),
            IconButton(
              key: const ValueKey('nav.game.export_part'),
              tooltip: l10n.gameExportPart,
              icon: const Icon(Icons.upload_file, size: _railIconSize),
              onPressed: _handleExportPart,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        // A fixed block the width the destinations reach, centred by the trailing
        // slot so the actions line up with the destinations. Static — no
        // animation on the footer itself.
        width: _railExtendedWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _railActionButton(
              keyId: 'nav.game.publish',
              icon: Icons.publish,
              label: l10n.gamePublish,
              onTap: _handlePublish,
            ),
            const SizedBox(height: 4),
            // 'Export Notes' is not in the bundled Material Icons font;
            // upload_file (file + up arrow) is the closest "export" glyph.
            _railActionButton(
              keyId: 'nav.game.export_part',
              icon: Icons.upload_file,
              label: l10n.gameExportPart,
              onTap: _handleExportPart,
            ),
          ],
        ),
      ),
    );
  }

  /// One EXPANDED rail action, laid out like a [NavigationRailDestination]: a
  /// [_railMinWidth]-wide leading box with the icon centered, then the label.
  /// Keeping the icon in a fixed leading box (rather than a `TextButton.icon`,
  /// which packs it hard-left) is what makes the action icons and labels line up
  /// with the destinations above.
  Widget _railActionButton({
    required String keyId,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      key: ValueKey(keyId),
      onPressed: onTap,
      style: TextButton.styleFrom(
        // Match the COLLAPSED icon buttons (and the destinations): the rail's
        // on-surface-variant, not the TextButton default primary, so the footer
        // does not change colour between the collapsed and expanded rail.
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        // Match the collapsed icon-button row height (48) so the footer rows
        // keep the same height in both states.
        minimumSize: const Size(0, 48),
        // Match the collapsed / destination icon size (a TextButton defaults to
        // 18, shrinking the expanded footer icons).
        iconSize: _railIconSize,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _railMinWidth,
            child: Center(child: Icon(icon)),
          ),
          // The label occupies a FIXED remainder (extended width - icon box) so a
          // long label ("Export elements") can't stretch the action past the
          // block width — otherwise the block would fill the rail and stop
          // centering, shifting the icons off the destination column.
          SizedBox(
            width: _railExtendedWidth - _railMinWidth,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  // The Map section page — DISABLED for now, kept for future work (see
  // docs/scene_map_widget.md). Re-enable with the `nav.game.map` destination and
  // the `_sceneMapPage()` entry in `pages`, and the scene_map imports at the top.
  //
  // /// The Map section page (`nav.game.map`): a read-only metro-style map of
  // /// the whole scene graph. Tapping a station opens that scene's preview.
  // Widget _sceneMapPage() {
  //   final scenes = _scenes.scenes;
  //   final paths = _scenes.paths;
  //   return SceneMapView(
  //     key: const ValueKey('game.map'),
  //     model: buildSceneGraph(
  //         scenes: scenes, paths: paths, mode: SceneMapMode.game),
  //     mode: SceneMapMode.game,
  //     paths: paths,
  //     onSceneTap: (uuid) {
  //       for (final s in scenes) {
  //         if (s.uuid == uuid) {
  //           _openScenePreview(s);
  //           return;
  //         }
  //       }
  //     },
  //   );
  // }

  Widget _settingsPage() {
    if (!_settingsLoaded || !_settings.isLoaded) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('game.settings.loading'),
        ),
      );
    }
    return AdventureSettingsScreen(
      key: const ValueKey('game.settings.root'),
      controller: _settings,
      existingCover: _existingCover,
      onSave: _saveFromForm,
      onImport: _handleImport,
      loadTargetDoc: () => widget.store.read(widget.slug),
      readOnly: widget.isSaveEdit,
    );
  }

  /// Performs an Import-data operation chosen on the Adventure settings form:
  /// merges the [selection] of [importDoc] (media under [sourceDir]) into this
  /// adventure (see [ProjectsStore.importInto]), reloads every section from the
  /// rewritten LivingScroll.json, and confirms with a SnackBar.
  Future<void> _handleImport(
    String sourceDir,
    Map<String, dynamic> importDoc,
    Map<String, Set<String>> selection,
    bool sameSystem,
  ) async {
    await widget.store.importInto(
      slug: widget.slug,
      sourceDir: sourceDir,
      importDoc: importDoc,
      selection: selection,
      sameSystem: sameSystem,
    );
    await _loadAdventure();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.importDone,
          key: const ValueKey('game.settings.import.done'),
        ),
      ),
    );
  }
}
