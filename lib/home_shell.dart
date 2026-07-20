import 'package:flutter/material.dart';

import 'create/create_new_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/create_grid_screen.dart';
import 'screens/create_new_screen.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/unsaved_changes_dialog.dart';
import 'settings/settings_edit_controller.dart';
import 'settings/settings_scope.dart';
import 'widgets/rail_menu_button.dart';
import 'widgets/rail_state.dart';

/// Main application shell:
///
/// ```
/// <Scaffold>
///   <Row>
///     <NavigationRail> (Menu) Home / Create / Library / Settings
///     <content area>
/// ```
///
/// Everything lives natively inside the [NavigationRail]: Home, Create, Library
/// and Settings are [NavigationRailDestination]s, and the Menu toggle sits in
/// the rail's `leading` slot.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// 0 = Home, 1 = Create, 2 = Library, 3 = Settings.
  static const int _createIndex = 1;
  static const int _settingsIndex = 3;

  int _selectedIndex = 0;

  /// The Library tab to open, and a counter bumped each time the Home view's
  /// "More" link requests one — the counter drives the LibraryScreen's key so it
  /// is rebuilt fresh on that tab (a persisted tab controller would ignore a new
  /// initialIndex).
  int _libraryTab = 0;
  int _libraryReopen = 0;

  /// Bumped whenever the shell returns to the Home destination from a pushed
  /// full-screen route (game / launch / playthrough). Keys the HomeScreen so it is
  /// rebuilt and reloads its Active sessions list — a just-created, just-progressed
  /// or just-finished save shows up / disappears at once.
  int _homeReopen = 0;

  /// Whether the navigation rail is expanded (icons + labels) or collapsed
  /// (icons only). Toggled by the Menu button. Backed by the app-wide
  /// [RailState] so the choice is preserved across every view.
  bool get _extended => RailState.extended.value;

  /// Whether the Create destination is showing the new-adventure form (true)
  /// or the grid (false).
  bool _creatingNew = false;

  /// Pending Settings edits + dirty state, consulted by the navigation guard.
  final SettingsEditController _editController = SettingsEditController();

  /// New-adventure form state + dirty flag, consulted by the navigation guard.
  final CreateNewController _createController = CreateNewController();

  @override
  void initState() {
    super.initState();
    RailState.extended.addListener(_onRailChanged);
  }

  /// Rebuilds when the shared rail state changes (e.g. toggled on another view).
  void _onRailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RailState.extended.removeListener(_onRailChanged);
    _editController.dispose();
    _createController.dispose();
    super.dispose();
  }

  /// Handle a navigation-rail selection. Leaving a dirty screen is guarded:
  /// Settings by the Save/Abandon/Cancel prompt, the new-adventure form by the
  /// two-option Abandon/Cancel prompt. Every other selection is immediate.
  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      // Re-tapping the CURRENT destination returns a nested form to its base
      // view. Only Create has a nested form (the new-adventure form over the
      // grid); re-tapping it closes the form back to the grid, through the same
      // isDirty guard (Abandon/Cancel) as any other navigation away from it.
      if (index == _createIndex && _creatingNew) {
        if (_createController.isDirty) {
          _confirmLeaveCreateNew(index); // index == current -> stays on Create
        } else {
          setState(() => _creatingNew = false); // pristine -> back to the grid
        }
      }
      return;
    }

    if (_selectedIndex == _settingsIndex && _editController.isDirty) {
      _confirmLeaveSettings(index);
      return;
    }
    if (_selectedIndex == _createIndex &&
        _creatingNew &&
        _createController.isDirty) {
      _confirmLeaveCreateNew(index);
      return;
    }
    // Leaving Create resets the sub-view so it reopens on the grid.
    if (_selectedIndex == _createIndex) _creatingNew = false;
    setState(() => _selectedIndex = index);
  }

  /// Settings: Save persists and navigates, Abandon drops the edits and
  /// navigates, Cancel (or a dismissed dialog) keeps the user on Settings.
  Future<void> _confirmLeaveSettings(int index) async {
    final scope = SettingsScope.of(context);
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted || choice == null || choice == UnsavedChoice.cancel) return;

    if (choice == UnsavedChoice.save) {
      await scope.onChanged(_editController.pending);
      _editController.markSaved();
    } else {
      _editController.discard();
    }
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  /// New-adventure form: Abandon discards the form and navigates; Cancel (or a
  /// dismissed dialog) keeps the user on the form.
  Future<void> _confirmLeaveCreateNew(int index) async {
    final abandon = await showDiscardChangesDialog(context);
    if (!mounted || !abandon) return;
    _createController.reset();
    setState(() {
      _creatingNew = false;
      _selectedIndex = index;
    });
  }

  /// Switch the Create destination to the new-adventure form (pristine).
  void _startNewAdventure() {
    _createController.reset();
    setState(() => _creatingNew = true);
  }

  /// From the Home empty-state "create new adventure" tile or the Library Projects
  /// "new project" cell: move to the Create destination AND open its new-adventure
  /// form (pristine) — the same entry point as the Create grid's new cell.
  void _startNewAdventureOnCreate() {
    _createController.reset();
    setState(() {
      _creatingNew = true;
      _selectedIndex = _createIndex;
    });
  }

  /// After Create (or opening an existing adventure): open the game screen and
  /// return the Create destination to its grid.
  Future<void> _openGame(String slug) async {
    _createController.reset();
    if (mounted) setState(() => _creatingNew = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(slug: slug, onHome: _exitGameToHome),
      ),
    );
  }

  /// Open a started game (`{Saves}/<saveName>`) in the editor for save-content
  /// editing — the Library Saves tile's Edit action and the resume screen's
  /// Edit button. Returning Home refreshes Active sessions like any pushed
  /// route.
  Future<void> _openSaveInEditor(String saveName) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen.save(saveName: saveName, onHome: _exitGameToHome),
      ),
    );
  }

  /// Leave any pushed full-screen route (game / launch / playthrough, at any
  /// depth) and show the shell's destination [index].
  void _exitToDestination(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      // Returning to Home reloads its Active sessions (a finished/paused save).
      if (index == 0) _homeReopen++;
      _selectedIndex = index;
    });
  }

  /// Leave the game (any depth of routes) and show the app's Home view.
  void _exitGameToHome() => _exitToDestination(0);

  /// Open the Library at [tab] (a Home "More" link). Bumps `_libraryReopen` so
  /// the LibraryScreen is recreated on that tab.
  void _openLibraryTab(int tab) {
    setState(() {
      _libraryTab = tab;
      _libraryReopen++;
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep the dirty baseline in step with the app's saved overrides.
    _editController.syncSaved(SettingsScope.of(context).overrides);

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        // ValueKey on the icon so key-based selectors can locate the
        // destination (NavigationRailDestination itself takes no key).
        icon: const Icon(Icons.home_outlined, key: ValueKey('nav.home')),
        selectedIcon: const Icon(Icons.home, key: ValueKey('nav.home')),
        label: Text(l10n.navHome),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.auto_stories_outlined,
          key: ValueKey('nav.create'),
        ),
        selectedIcon: const Icon(
          Icons.auto_stories,
          key: ValueKey('nav.create'),
        ),
        label: Text(l10n.navCreate),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.library_books_outlined,
          key: ValueKey('nav.library'),
        ),
        selectedIcon: const Icon(
          Icons.library_books,
          key: ValueKey('nav.library'),
        ),
        label: Text(l10n.navLibrary),
      ),
      NavigationRailDestination(
        icon: const Icon(
          Icons.settings_outlined,
          key: ValueKey('nav.settings'),
        ),
        selectedIcon: const Icon(Icons.settings, key: ValueKey('nav.settings')),
        label: Text(l10n.navSettings),
      ),
    ];

    final pages = <Widget>[
      HomeScreen(
        key: ValueKey('home.$_homeReopen'),
        onHome: _exitGameToHome,
        onNavigate: _exitToDestination,
        onMore: _openLibraryTab,
        onEditSave: _openSaveInEditor,
        onCreateNew: _startNewAdventureOnCreate,
      ),
      _creatingNew
          ? CreateNewScreen(controller: _createController, onCreated: _openGame)
          : CreateGridScreen(onNew: _startNewAdventure, onOpen: _openGame),
      LibraryScreen(
        key: ValueKey('library.$_libraryReopen'),
        initialTab: _libraryTab,
        onOpen: _openGame,
        onHome: _exitGameToHome,
        onNavigate: _exitToDestination,
        onEditSave: _openSaveInEditor,
        onCreateNew: _startNewAdventureOnCreate,
      ),
      SettingsScreen(controller: _editController),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              // Key by the extended state so toggling REPLACES the rail with a
              // fresh instance already at the target layout (its extend
              // controller initialises AT the target in initState) instead of
              // animating to it — the rail is STATIC: expand/collapse is instant,
              // no slide/reveal animation. (Selecting a destination keeps the
              // key, so the selection indicator still animates.)
              key: ValueKey('shell.rail.$_extended'),
              leading: RailMenuButton(
                tooltip: l10n.menuTooltip,
                onTap: RailState.toggle,
              ),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              extended: _extended,
              // Collapsed: icons only. Expanded: labels show beside the icons
              // via `extended`, so labelType stays `none`.
              labelType: NavigationRailLabelType.none,
              destinations: destinations,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }
}
