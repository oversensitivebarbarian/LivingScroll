import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../scenes/scene.dart';
import '../widgets/detail_dialog.dart';
import '../widgets/rail_menu_button.dart';
import '../widgets/rail_state.dart';
import 'adventure_tile.dart';
import 'play_screen.dart';
import 'playthrough_screen.dart';

/// The adventure launch screen — the game-start "dialog" reached from the
/// Library Adventures info dialog's **Play** button (start a NEW game) AND from
/// a Library **Saves** tile (RESUME an in-progress save). The poster sits on the
/// left; on the right the title (with the version on the next line) sits above a
/// two-column FORM — the LEFT column holds the Group name field over the players
/// (PC) roster (a name field + a **+** to add more), the RIGHT column holds a
/// grid of the adventure's START scenes as single-select (radio) tiles (a resume
/// shows the last-scene panel there instead). The bottom row holds **Cancel**
/// (back), **Prep mode** (secondary, no progress) and **Play** (gameplay,
/// progress recorded).
///
/// New game ([resumeSaveName] null): either play button copies the adventure into
/// `{Saves}` under `<title>-<version>-<group>` (prompting Replace / Cancel when
/// that save already exists) and starts at the SELECTED start scene. Resume
/// ([resumeSaveName] set): no copy — both buttons continue the existing save at
/// the LAST VISITED scene (the last entry of its `history.json`).
class AdventureLaunchScreen extends StatefulWidget {
  const AdventureLaunchScreen({
    super.key,
    required this.adventure,
    this.store = const ProjectsStore(),
    this.onHome,
    this.resumeSaveName,
    this.onNavigate,
    this.onEditSave,
  });

  /// The adventure being launched; carries the cover + metadata shown here. For
  /// a new game it is the library adventure (its [AdventureSummary.slug] is the
  /// dir under `{Adventures}`); for a resume it is the save summary (slug = the
  /// `{Saves}` dir, equal to [resumeSaveName]).
  final AdventureSummary adventure;
  final ProjectsStore store;

  /// Returns to the app's Home view (used when a gameplay session finishes the
  /// adventure). Forwarded to the [PlaythroughScreen].
  final VoidCallback? onHome;

  /// When set, this screen RESUMES the `{Saves}/<resumeSaveName>` playthrough
  /// (no copy) at its last visited scene, instead of starting a new game.
  final String? resumeSaveName;

  /// Exits to a shell destination by index (0 Home / 1 Create / 2 Library /
  /// 3 Settings), driving this screen's side navigation rail.
  final ValueChanged<int>? onNavigate;

  /// Opens the resumed save in the game editor. Drives the **Edit** button
  /// shown ONLY in resume mode — the Home entry point into save-content
  /// editing.
  final ValueChanged<String>? onEditSave;

  @override
  State<AdventureLaunchScreen> createState() => _AdventureLaunchScreenState();
}

class _AdventureLaunchScreenState extends State<AdventureLaunchScreen> {
  final TextEditingController _group = TextEditingController();

  /// One controller per player-character (PC) name field. The GM adds/removes
  /// fields with the +/remove buttons (new game); on a resume these are filled
  /// from the save's `group.json` and disabled.
  final List<TextEditingController> _players = [];

  List<Scene> _startScenes = const [];
  String? _selected;

  /// New game only: the `{Finished}` directory whose key-event progress will be
  /// imported into the fresh save (set via the "Import progress" dialog), or null
  /// when no import is chosen. Applied AFTER the save dir is created, on launch.
  String? _importFrom;

  /// Resume only: the scene to continue at (the save's last visited scene).
  Scene? _resumeScene;

  /// False until the form's data (scenes / resume info) has loaded — shows the
  /// loading roller. True while a launch is in progress also shows it.
  bool _loaded = false;
  bool _launching = false;

  /// Side-navigation rail expanded (icons + labels) vs collapsed (icons only).
  /// Backed by the app-wide [RailState] so the choice is preserved across views.
  bool get _extended => RailState.extended.value;

  bool get _isResume => widget.resumeSaveName != null;

  @override
  void initState() {
    super.initState();
    RailState.extended.addListener(_onRailChanged);
    // A new game shows one empty player field to start with (the GM adds more
    // with the + button); a resume fills the roster from group.json in _load().
    if (!_isResume) _players.add(TextEditingController());
    _load();
  }

  /// Rebuilds when the shared rail state changes (e.g. toggled on another view).
  void _onRailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RailState.extended.removeListener(_onRailChanged);
    _group.dispose();
    for (final c in _players) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() => setState(() => _players.add(TextEditingController()));

  void _removePlayer(int index) => setState(() {
    _players.removeAt(index).dispose();
  });

  Future<void> _load() async {
    final doc = _isResume
        ? await widget.store.readSave(widget.resumeSaveName!)
        : await widget.store.readAdventure(widget.adventure.slug);
    if (!mounted) return;

    final allScenes = <Scene>[
      if (doc?['scenes'] is List)
        for (final s in doc!['scenes'] as List)
          if (s is Map) Scene.fromJson(s),
    ];
    final startScenes = [
      for (final s in allScenes)
        if (s.sceneType == 'start') s,
    ];

    Scene? resumeScene;
    var group = '';
    var players = const <String>[];
    if (_isResume) {
      // The group this save is for, its player roster (both pre-filled and
      // disabled below), plus the scene to continue at (history's last entry,
      // falling back to a start scene).
      group = await widget.store.readSaveGroup(widget.resumeSaveName!);
      players = await widget.store.readSavePlayers(widget.resumeSaveName!);
      final history = await widget.store.readSaveHistory(
        widget.resumeSaveName!,
      );
      // history.json entries are scene UUIDs; resolve the last one against
      // author scenes AND runtime ad-hoc scenes (party.json), so the
      // last-scene panel can show a recorded ad-hoc scene.
      final party = await widget.store.readPartyState(widget.resumeSaveName!);
      if (!mounted) return;
      final resumable = <Scene>[
        ...allScenes,
        if (party?['adhoc_scenes'] is List)
          for (final e in party!['adhoc_scenes'] as List)
            if (e is Map && e['scene_uuid'] is String)
              Scene(
                uuid: e['scene_uuid'] as String,
                name: e['name'] is String ? e['name'] as String : '',
                sceneType: Scene.defaultSceneType,
              ),
      ];
      for (final uuid in history.reversed) {
        final match = resumable.where((s) => s.uuid == uuid);
        if (match.isNotEmpty) {
          resumeScene = match.first;
          break;
        }
      }
      resumeScene ??= startScenes.isNotEmpty
          ? startScenes.first
          : (allScenes.isNotEmpty ? allScenes.first : null);
    }

    setState(() {
      _startScenes = startScenes;
      _selected = startScenes.isNotEmpty ? startScenes.first.uuid : null;
      _resumeScene = resumeScene;
      if (_isResume) {
        _group.text = group;
        for (final p in players) {
          _players.add(TextEditingController(text: p));
        }
      }
      _loaded = true;
    });
  }

  /// New game needs a group name + a selected start scene; a resume only needs a
  /// scene to continue at (always resolved on load).
  bool get _canLaunch => _isResume
      ? _resumeScene != null
      : _group.text.trim().isNotEmpty && _selected != null;

  /// Resume: continue the existing save. New game: copy the adventure into
  /// `{Saves}` (prompting Replace / Cancel on an existing save) then play.
  Future<void> _launch(PlayMode mode) async {
    if (_isResume) {
      final scene = _resumeScene;
      if (scene == null) return;
      // The roster is editable on a resume (add/remove/rename) — persist the
      // (possibly edited) player list back to the save's group.json before
      // continuing. The group name is fixed (it names the save dir).
      await widget.store.writeSavePlayers(widget.resumeSaveName!, [
        for (final c in _players) c.text,
      ]);
      await _openPlaythrough(widget.resumeSaveName!, scene.uuid, mode);
      return;
    }

    final group = _group.text.trim();
    final scene = _selected;
    if (group.isEmpty || scene == null) return;
    final saveName = ProjectsStore.saveDirName(
      widget.adventure.name,
      widget.adventure.version,
      group,
    );

    var overwrite = false;
    if (await widget.store.saveExists(saveName)) {
      if (!mounted) return;
      final replace = await _confirmReplace(group);
      if (replace != true) return; // Cancel -> stay on the form.
      overwrite = true;
    }

    setState(() => _launching = true); // show the roller during the copy
    final created = await widget.store.startSaveFromLibrary(
      adventureDir: widget.adventure.slug,
      groupName: group,
      players: [for (final c in _players) c.text],
      overwrite: overwrite,
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _launching = false);
      return;
    }
    // Once the new save dir exists, import the chosen finished game's progress
    // (key events, NPC states, GM notes) into it, if one was picked (new game only).
    if (_importFrom != null) {
      await widget.store.importSaveProgress(
        saveName: created,
        fromFinishedDir: _importFrom!,
      );
      if (!mounted) return;
    }
    // Drop the roller before pushing — the playthrough shows its own while it
    // loads (an ever-spinning roller left under the pushed route never settles).
    setState(() => _launching = false);
    await _openPlaythrough(created, scene, mode);
  }

  Future<void> _openPlaythrough(
    String saveName,
    String sceneUuid,
    PlayMode mode,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaythroughScreen(
          saveName: saveName,
          startSceneUuid: sceneUuid,
          mode: mode,
          store: widget.store,
          onHome: widget.onHome,
        ),
      ),
    );
  }

  Future<bool?> _confirmReplace(String group) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('launch.save.exists.dialog'),
        content: Text(
          l10n.launchSaveExistsMessage(widget.adventure.name, group),
        ),
        actions: [
          TextButton(
            key: const ValueKey('launch.save.exists.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('launch.save.exists.replace'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.launchReplace),
          ),
        ],
      ),
    );
  }

  /// New game only: opens the "Import progress" picker — the SAME view as the
  /// Library Saves/Finished tab (a grid of [AdventureTile]s at adventure-tile
  /// proportions) over the FINISHED games (`{Finished}`), MINUS the delete button
  /// (browse-only tiles), and with the finished sessions of the SAME game (same
  /// adventure name + version) FILTERED OUT — you import from ANOTHER game's
  /// finished session. Tapping a tile picks it (single-select) and closes the
  /// picker; the chosen finished dir is remembered in [_importFrom] and applied on
  /// the next launch (after the save dir is created). Cancel leaves it unchanged.
  Future<void> _pickImportProgress() async {
    final l10n = AppLocalizations.of(context);
    final finished = await widget.store.listFinished();
    if (!mounted) return;

    // Drop the finished sessions of the SAME game (same adventure identity).
    final others = [
      for (final f in finished)
        if (!(f.name == widget.adventure.name &&
            f.version == widget.adventure.version))
          f,
    ];

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('launch.import.dialog'),
        title: Text(l10n.launchImportProgress),
        content: SizedBox(
          width: 560,
          height: 420,
          child: others.isEmpty
              ? Center(
                  child: Text(
                    l10n.launchImportProgressEmpty,
                    key: const ValueKey('launch.import.empty'),
                  ),
                )
              // The SAME grid as the Library Saves/Finished tab (tile size 220,
              // 1:1.43), but every tile is browse-only (no delete button) and a
              // tap picks that finished session.
              : GridView.builder(
                  key: const ValueKey('launch.import.grid'),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1 / 1.43,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final f = others[index];
                    return AdventureTile(
                      adventure: f,
                      // No onDelete/onClone/onEdit -> a browse-only tile (no
                      // delete button); tapping picks this finished session.
                      onOpen: () => Navigator.of(ctx).pop(f.slug),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('launch.import.cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.unsavedCancel),
          ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _importFrom = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('launch.root'),
      body: SafeArea(
        // The side-navigation rail stays visible so Home / Settings etc. are
        // always reachable; only the content area swaps roller <-> form.
        child: Row(
          children: [
            _rail(l10n),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _content(l10n, scheme)),
          ],
        ),
      ),
    );
  }

  /// The side navigation rail (Home / Create / Library / Settings) so the launch
  /// screen never dead-ends — tapping a destination exits to the shell there.
  Widget _rail(AppLocalizations l10n) {
    return NavigationRail(
      // Key by the extended state so toggling REPLACES the rail with a fresh
      // instance already at the target layout instead of animating — the rail is
      // STATIC: expand/collapse is instant, no slide/reveal animation.
      key: ValueKey('launch.rail.$_extended'),
      leading: RailMenuButton(
        tooltip: l10n.menuTooltip,
        onTap: RailState.toggle,
      ),
      // The launch screen sits "in" the Library context; tapping any destination
      // exits there via onNavigate.
      selectedIndex: 2,
      onDestinationSelected: (index) => widget.onNavigate?.call(index),
      extended: _extended,
      labelType: NavigationRailLabelType.none,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(
            Icons.home_outlined,
            key: ValueKey('launch.nav.home'),
          ),
          selectedIcon: const Icon(
            Icons.home,
            key: ValueKey('launch.nav.home'),
          ),
          label: Text(l10n.navHome),
        ),
        NavigationRailDestination(
          icon: const Icon(
            Icons.auto_stories_outlined,
            key: ValueKey('launch.nav.create'),
          ),
          selectedIcon: const Icon(
            Icons.auto_stories,
            key: ValueKey('launch.nav.create'),
          ),
          label: Text(l10n.navCreate),
        ),
        NavigationRailDestination(
          icon: const Icon(
            Icons.library_books_outlined,
            key: ValueKey('launch.nav.library'),
          ),
          selectedIcon: const Icon(
            Icons.library_books,
            key: ValueKey('launch.nav.library'),
          ),
          label: Text(l10n.navLibrary),
        ),
        NavigationRailDestination(
          icon: const Icon(
            Icons.settings_outlined,
            key: ValueKey('launch.nav.settings'),
          ),
          selectedIcon: const Icon(
            Icons.settings,
            key: ValueKey('launch.nav.settings'),
          ),
          label: Text(l10n.navSettings),
        ),
      ],
    );
  }

  /// The content area: a roller while loading / launching, else the form.
  Widget _content(AppLocalizations l10n, ColorScheme scheme) {
    return (!_loaded || _launching)
        ? const Center(
            child: CircularProgressIndicator(key: ValueKey('launch.loading')),
          )
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT — the poster, KEEPING its 1:1.43 portrait proportions.
                // The Align gives the AspectRatio loose constraints (not the
                // Row's tight full height), so the width cap (max 300 — guards
                // against overflow on a tall/narrow window) shrinks the WHOLE
                // poster proportionally instead of squeezing it into a narrow
                // strip.
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: AspectRatio(
                      aspectRatio: 1 / 1.43,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.adventure.cover != null
                            ? Image.file(
                                widget.adventure.cover!,
                                key: const ValueKey('launch.cover'),
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                key: const ValueKey('launch.cover'),
                                color: scheme.surfaceContainerHighest,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // RIGHT — title/version, then the two-column FORM
                // (group + players | scenes), then the actions.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.adventure.name,
                        key: const ValueKey('launch.title'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (widget.adventure.version.isNotEmpty)
                        Text(
                          '${l10n.createNewVersionLabel}: '
                          '${widget.adventure.version}',
                          key: const ValueKey('launch.version'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const Divider(height: 24),
                      // The FORM is two columns: the LEFT holds the group
                      // name over the players (PC) roster; the RIGHT holds
                      // the start-scene radio grid (new game) or the
                      // last-scene panel (resume).
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LEFT form column — group name + players. It
                            // scrolls as a whole so a long roster never
                            // overflows on the 640x480 minimum window.
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      key: const ValueKey('launch.field.group'),
                                      controller: _group,
                                      // A resume already has its group (from
                                      // group.json, pre-filled on load); the
                                      // field is not editable there.
                                      enabled: !_isResume,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: l10n.launchGroupNameLabel,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _playersSection(l10n),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // RIGHT form column — start scenes (new game) or
                            // the last-scene panel (resume).
                            Expanded(
                              child: _isResume
                                  ? _lastSceneInfo(l10n, scheme)
                                  : _sceneGrid(scheme),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Wrap so the actions reflow to a second line on a
                      // narrow window instead of overflowing.
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Resume only: open the save in the game editor to
                          // ADD content.
                          if (_isResume && widget.onEditSave != null)
                            OutlinedButton(
                              key: const ValueKey('launch.edit'),
                              onPressed: () => widget.onEditSave!.call(
                                widget.resumeSaveName!,
                              ),
                              child: Text(l10n.librarySaveEdit),
                            ),
                          OutlinedButton(
                            key: const ValueKey('launch.cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.unsavedCancel),
                          ),
                          // New game only: import a finished game's key-event
                          // progress into the fresh save (picked here, applied
                          // on launch). Sits between Cancel and Prep mode.
                          if (!_isResume)
                            OutlinedButton(
                              key: const ValueKey('launch.import.progress'),
                              onPressed: _pickImportProgress,
                              child: Text(l10n.launchImportProgress),
                            ),
                          FilledButton.tonal(
                            key: const ValueKey('launch.dryrun'),
                            onPressed: _canLaunch
                                ? () => _launch(PlayMode.preview)
                                : null,
                            child: Text(l10n.launchDryRun),
                          ),
                          FilledButton(
                            key: const ValueKey('launch.play'),
                            onPressed: _canLaunch
                                ? () => _launch(PlayMode.gameplay)
                                : null,
                            child: Text(l10n.libraryAdventurePlay),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  /// The players (PC names) section under the group field (LEFT form column): a
  /// label, then the list of name fields (each with a remove button), then a +
  /// button that appends another empty field. A new game starts with one empty
  /// field (seeded in initState). On a resume the fields are pre-filled from the
  /// save's group.json but stay EDITABLE (add/remove/rename) — the roster can be
  /// managed when continuing, and the edits are persisted back to group.json on
  /// launch (unlike the group name, which is fixed). The enclosing left column
  /// scrolls, so a long roster never overflows the form (the 640x480
  /// minimum-window contract).
  Widget _playersSection(AppLocalizations l10n) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.launchPlayersLabel,
          key: const ValueKey('launch.players.label'),
          style: text.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _players.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('launch.player.$i'),
                    controller: _players[i],
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.launchPlayerNameHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('launch.player.$i.remove'),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: l10n.launchRemovePlayer,
                  onPressed: () => _removePlayer(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const ValueKey('launch.players.add'),
            icon: const Icon(Icons.add),
            tooltip: l10n.launchAddPlayer,
            onPressed: _addPlayer,
          ),
        ),
      ],
    );
  }

  /// Resume only: a panel describing where the save will continue — its last
  /// scene's name over its description (replaces the start-scene grid).
  Widget _lastSceneInfo(AppLocalizations l10n, ColorScheme scheme) {
    final scene = _resumeScene;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        key: const ValueKey('launch.last.scene'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.launchLastSceneLabel,
              style: text.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scene?.name ?? '',
              key: const ValueKey('launch.last.scene.name'),
              style: text.titleMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((scene?.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scene!.description,
                key: const ValueKey('launch.last.scene.description'),
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// New game only: the start scenes as single-select (radio) tiles —
  /// adventure-tile proportions (1:1.43). Each tile is a TEASER: the scene name
  /// over a TRUNCATED description in a large font, with a bottom-right Loupe that
  /// opens the full-description dialog.
  Widget _sceneGrid(ColorScheme scheme) {
    return GridView.builder(
      key: const ValueKey('launch.scenes'),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 1 / 1.43,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _startScenes.length,
      itemBuilder: (context, index) {
        final scene = _startScenes[index];
        final selected = scene.uuid == _selected;
        final onColor = selected
            ? scheme.onSecondaryContainer
            : scheme.onSurface;
        return Material(
          color: selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('launch.scene.${scene.uuid}'),
            onTap: () => setState(() => _selected = scene.uuid),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: onColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      // Teaser: a few lines of the description, clamped + ellipsised
                      // (the full text lives in the Loupe dialog).
                      Expanded(
                        child: Text(
                          scene.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                // BOTTOM-RIGHT — Loupe opens the full-description dialog; it does
                // NOT select the tile (it is its own button).
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton(
                    key: ValueKey('launch.scene.${scene.uuid}.loupe'),
                    icon: Icon(Icons.loupe, color: onColor),
                    onPressed: () => _showSceneDetail(scene),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The start-scene DETAIL dialog (opened by a tile's Loupe): the shared
  /// format-A detail dialog showing the scene name + FULL description.
  Future<void> _showSceneDetail(Scene scene) => showDetailDialog(
    context,
    rootKey: 'launch.scene.detail',
    title: scene.name,
    titleKey: 'launch.scene.detail.name',
    body: scene.description,
    bodyKey: 'launch.scene.detail.description',
    okKey: 'launch.scene.detail.ok',
  );
}
