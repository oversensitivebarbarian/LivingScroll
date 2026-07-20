import 'dart:io';

import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../services/file_picker_service.dart';
import 'adventure_tile.dart';
import 'library_tile_actions.dart';
import 'replay_screen.dart';

/// Per-tab tile actions in the Library grids.
enum _TileActions {
  /// No action.
  none,

  /// Copy as project + Delete menu; tap opens the info dialog (Adventures tab).
  adventures,

  /// Delete button; tap opens the project in create mode (Projects tab).
  projects,

  /// Tap RESUMES the save in the launch screen (Saves tab).
  saves,

  /// Delete button; tap opens the REPLAY view (Finished tab).
  finished,
}

/// The Library destination: a 4-tab browser over the user-files roots that
/// hold adventures. Each tab is a grid of [AdventureTile]s
/// listing one directory:
///   * Adventures — unpacked `.ls` archives ({Adventures})
///   * Saves      — in-progress playthroughs ({Saves})
///   * Projects   — work-in-progress adventures ({Projects})
///   * Finished   — completed, read-only adventures ({Finished})
///
/// Per-tab tile affordances: the Adventures tab has a Copy as project / Delete
/// menu; the Projects tab has a direct delete button AND opens a tapped tile in
/// create mode (the game editor, via [onOpen]); the Saves and Finished tabs are
/// browse-only.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.store = const ProjectsStore(),
    this.onOpen,
    this.onHome,
    this.onNavigate,
    this.onCreateNew,
    this.onEditSave,
    this.initialTab = 0,
  });

  /// Opens a started game (`{Saves}/<slug>`) in the game editor for save-content
  /// editing — the Saves tile's Edit action and the resume screen's Edit
  /// button. Provided by the shell (`home_shell._openSaveInEditor`).
  final ValueChanged<String>? onEditSave;

  /// The tab to open on first build (0 Adventures / 1 Saves / 2 Projects /
  /// 3 Finished) — used when the Home view's "More" link opens a specific tab.
  final int initialTab;

  final ProjectsStore store;

  /// Opens a project by slug in create mode (the game editor) when a Projects
  /// tile is tapped. Only the Projects tab uses it; the other tabs are
  /// browse-only.
  final ValueChanged<String>? onOpen;

  /// Returns to the app's Home view (used by a finished playthrough launched
  /// from an Adventures tile). Threaded to the launch + playthrough screens.
  final VoidCallback? onHome;

  /// Exits to a shell destination by index (0 Home / 1 Create / 2 Library /
  /// 3 Settings) — drives the launch screen's navigation rail so its side menu
  /// can reach Home / Settings etc.
  final ValueChanged<int>? onNavigate;

  /// Opens the new-adventure form on the Create destination — the Projects tab's
  /// leading "new project" cell (the same entry point as the Create grid's new
  /// cell).
  final VoidCallback? onCreateNew;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<AdventureSummary> _adventures = const [];
  List<AdventureSummary> _saves = const [];
  List<AdventureSummary> _projects = const [];
  List<AdventureSummary> _finished = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<AdventureSummary> adventures = const [];
    List<AdventureSummary> saves = const [];
    List<AdventureSummary> projects = const [];
    List<AdventureSummary> finished = const [];
    try {
      adventures = await widget.store.listAdventures();
      saves = await widget.store.listSaves();
      projects = await widget.store.list();
      finished = await widget.store.listFinished();
    } catch (_) {
      // No path provider (a bare widget test) -> empty grids rather than a crash.
    }
    if (!mounted) return;
    setState(() {
      _adventures = adventures;
      _saves = saves;
      _projects = projects;
      _finished = finished;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Column(
        key: const ValueKey('library.root'),
        children: [
          TabBar(
            key: const ValueKey('library.tabs'),
            tabs: [
              Tab(
                key: const ValueKey('library.tab.adventures'),
                text: l10n.libraryAdventures,
              ),
              Tab(
                key: const ValueKey('library.tab.saves'),
                text: l10n.librarySaves,
              ),
              Tab(
                key: const ValueKey('library.tab.projects'),
                text: l10n.libraryProjects,
              ),
              Tab(
                key: const ValueKey('library.tab.finished'),
                text: l10n.libraryFinished,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Adventures: an import cell first, and tiles carry a Copy as
                // project / Delete menu.
                _grid(
                  'library.grid.adventures',
                  _adventures,
                  withImport: true,
                  actions: _TileActions.adventures,
                ),
                _grid(
                  'library.grid.saves',
                  _saves,
                  actions: _TileActions.saves,
                ),
                // Projects: a new-project cell first, and tiles carry a Delete
                // action.
                _grid(
                  'library.grid.projects',
                  _projects,
                  withNewProject: true,
                  actions: _TileActions.projects,
                ),
                _grid(
                  'library.grid.finished',
                  _finished,
                  actions: _TileActions.finished,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    String key,
    List<AdventureSummary> items, {
    bool withImport = false,
    bool withNewProject = false,
    _TileActions actions = _TileActions.none,
  }) {
    final lead = (withImport || withNewProject) ? 1 : 0;
    final l10n = AppLocalizations.of(context);
    final adventures = actions == _TileActions.adventures;
    final projects = actions == _TileActions.projects;
    final saves = actions == _TileActions.saves;
    final finished = actions == _TileActions.finished;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        key: ValueKey(key),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 1 / 1.43,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length + lead,
        itemBuilder: (context, index) {
          if (withImport && index == 0) return _importTile(context);
          if (withNewProject && index == 0) return _newProjectTile(context);
          final adventure = items[index - lead];
          return AdventureTile(
            adventure: adventure,
            // Projects: opens the project in create mode (the game editor).
            // Adventures: opens the read-only info window. Saves: resumes the
            // save in the launch screen. Finished: opens the REPLAY view.
            onOpen: projects
                ? () => widget.onOpen?.call(adventure.slug)
                : adventures
                ? () => _showAdventureInfo(adventure)
                : saves
                ? () => _resumeSave(adventure)
                : finished
                ? () => _openReplay(adventure)
                : () {},
            // Adventures: Copy as project + Delete (context menu). Projects:
            // Clone + Delete (the SAME context menu as the Create grid).
            // Finished: Copy as project + Delete (context menu too). Saves: a
            // direct delete BUTTON (via the Edit/Delete dialog).
            onClone: adventures
                ? () => _copyAsProject(adventure)
                : projects
                ? () => _cloneProject(adventure)
                : finished
                ? () => _copyFinishedAsProject(adventure)
                : null,
            cloneLabel: (adventures || finished)
                ? l10n.libraryCopyAsProject
                : null,
            // Adventures: an extra "Export to LaTeX" menu item.
            onExportLatex: adventures ? () => _exportLatex(adventure) : null,
            exportLatexLabel: adventures ? l10n.libraryExportLatex : null,
            // Saves: the corner button opens an Edit / Delete dialog (Edit opens
            // the save in the game editor).
            onEdit: saves
                ? () => widget.onEditSave?.call(adventure.slug)
                : null,
            deleteAsButton: saves,
            onDelete: adventures
                ? () => _confirmDelete(
                    adventure,
                    'library.delete',
                    l10n.adventureDeleteMessage,
                    () => widget.store.deleteLibraryAdventure(adventure.slug),
                  )
                : projects
                ? () => _confirmDelete(
                    adventure,
                    'library.project.delete',
                    l10n.adventureDeleteMessage,
                    () => widget.store.delete(adventure.slug),
                  )
                : saves
                ? () => _confirmDelete(
                    adventure,
                    'library.save.delete',
                    l10n.librarySaveDeleteMessage,
                    () => widget.store.deleteSave(adventure.slug),
                  )
                : finished
                ? () => _confirmDelete(
                    adventure,
                    'library.finished.delete',
                    l10n.libraryFinishedDeleteMessage,
                    () => widget.store.deleteFinished(adventure.slug),
                  )
                : null,
          );
        },
      ),
    );
  }

  /// Opens the read-only info window for a library adventure (Adventures tab);
  /// its Play button opens the adventure launch screen.
  Future<void> _showAdventureInfo(AdventureSummary adventure) =>
      showAdventureInfoTile(
        context,
        store: widget.store,
        adventure: adventure,
        onHome: widget.onHome,
        onNavigate: widget.onNavigate,
      );

  /// Resumes an in-progress save (Saves tab): the SAME launch screen in resume
  /// mode — Prep mode / Play continue at the save's last visited scene.
  Future<void> _resumeSave(AdventureSummary save) async {
    await resumeSaveTile(
      context,
      store: widget.store,
      save: save,
      onHome: widget.onHome,
      onNavigate: widget.onNavigate,
      onEditSave: widget.onEditSave,
    );
    if (mounted) await _load(); // a finished save no longer lists here
  }

  /// Opens the read-only REPLAY view for a finished session (Finished tab).
  Future<void> _openReplay(AdventureSummary finished) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReplayScreen(finishedDir: finished.slug, store: widget.store),
      ),
    );
  }

  /// Clones a project (the Projects tile's Clone menu item): copies its directory
  /// to a new unique slug + renamed copy, then reloads so the grid shows it — the
  /// SAME action as the Create grid's Clone.
  Future<void> _cloneProject(AdventureSummary adventure) async {
    await widget.store.cloneAdventure(adventure.slug);
    await _load();
  }

  Future<void> _copyAsProject(AdventureSummary adventure) async {
    await widget.store.copyLibraryAdventureToProject(adventure.slug);
    await _load(); // the Projects tab now has the copy
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.libraryCopyDone,
            key: const ValueKey('library.copy.done'),
          ),
        ),
      );
  }

  /// Copies a Finished session into `{Projects}` as a new editable project —
  /// the Finished tile's "Copy as project" menu item. Every key event's state
  /// is reset to unchecked in the copy (ProjectsStore.copyFinishedToProject).
  Future<void> _copyFinishedAsProject(AdventureSummary adventure) async {
    await widget.store.copyFinishedToProject(adventure.slug);
    await _load(); // the Projects tab now has the copy
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.libraryCopyDone,
            key: const ValueKey('library.copy.done'),
          ),
        ),
      );
  }

  /// Exports the library adventure to a LaTeX document (ZIP): builds the bytes,
  /// then offers a native save dialog. A cancelled dialog writes nothing (no
  /// error); a build failure shows an error SnackBar.
  Future<void> _exportLatex(AdventureSummary adventure) async {
    final result = await widget.store.exportLatex(adventure.slug);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (result == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.libraryExportLatexError,
              key: const ValueKey('library.export.latex.error'),
            ),
          ),
        );
      return;
    }
    final path = await FilePickerService.instance.saveFile(
      fileName: result.suggestedFileName,
    );
    if (path == null) return; // cancelled -> nothing written
    await File(path).writeAsBytes(result.archiveBytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.libraryExportLatexDone,
            key: const ValueKey('library.export.latex.done'),
          ),
        ),
      );
  }

  /// Confirms (Delete / Cancel) then runs [doDelete] and refreshes the grid. The
  /// dialog's keys are namespaced by [keyPrefix] (`<prefix>.dialog/.cancel/.confirm`)
  /// and its body shows [message].
  Future<void> _confirmDelete(
    AdventureSummary adventure,
    String keyPrefix,
    String message,
    Future<void> Function() doDelete,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: ValueKey('$keyPrefix.dialog'),
        title: Text(adventure.name),
        content: Text(message),
        actions: [
          TextButton(
            key: ValueKey('$keyPrefix.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: ValueKey('$keyPrefix.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adventureDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await doDelete();
    await _load(); // the tile is gone
  }

  /// The first Projects cell: tap -> open the new-adventure form on the Create
  /// destination, exactly like the Create grid's "new" cell.
  Widget _newProjectTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('library.projects.new'),
        onTap: () => widget.onCreateNew?.call(),
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

  /// The first Adventures cell: tap -> pick a `.ls` -> import into the library.
  Widget _importTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('library.adventures.import'),
        onTap: _importAdventure,
        child: Center(
          child: Tooltip(
            message: l10n.libraryImport,
            child: Icon(
              Icons.upload_file_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importAdventure() async {
    final added = await importLsToLibraryTile(context, store: widget.store);
    if (added && mounted) await _load(); // refresh the grid
  }
}
