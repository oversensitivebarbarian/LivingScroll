import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:living_scroll/create/cover_crop.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_settings_screen.dart';
import 'package:living_scroll/screens/game_screen.dart';
import 'package:living_scroll/screens/paths_screen.dart';
import 'package:living_scroll/widgets/path_tile.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

/// A desktop-sized viewport so the in-game rail (10 sections + the bottom Export
/// actions) fits without scrolling — the default 800x600 surface is shorter than
/// any real window the game shell runs in.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// An in-memory [ProjectsStore] so the Adventure settings section can load
/// without a path_provider / filesystem. Records the last [update] call.
class _FakeStore implements ProjectsStore {
  _FakeStore(this._document);

  final Map<String, dynamic> _document;
  Map<String, String>? savedMetadata;
  List<Map<String, dynamic>>? savedPaths;

  @override
  Future<Map<String, dynamic>?> read(String slug) async => _document;

  @override
  Future<File?> coverFile(String slug) async => null;

  @override
  Future<String> imagesOtherPath(String slug) async => '';

  @override
  Future<String> bgImagesPath(String slug) async => '';

  @override
  Future<List<String>> listBgImages(String slug) async => const [];

  @override
  Future<String> npcImagesPath(String slug) async => '';

  @override
  Future<String> audioPath(String slug) async => '';

  @override
  Future<void> writePaths(String slug, List<Map<String, dynamic>> paths) async {
    savedPaths = paths;
  }

  @override
  Future<void> update({
    required String slug,
    required Map<String, String> metadata,
    String? coverSourcePath,
    CoverCrop? coverCrop,
  }) async {
    savedMetadata = metadata;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _seedDocument() => {
      'metadata': {
        'name': 'Demo',
        'system': 'basic',
        'version': '1.0.0',
        'author': 'A',
        'description': 'd',
        'language': 'en',
        'content_warnings': 'none',
        'license': 'x',
      },
      'images': [],
      'audio': [],
      'paths': [],
      'key_events': [],
      'notes': [],
      'gm_notes': [],
      'npcs': [],
      'scenes': [],
    };

void main() {
  testWidgets('Game rail starts on Scenes and switches sections',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: () {})));
    await tester.pumpAndSettle();

    NavigationRail rail() =>
        tester.widget<NavigationRail>(find.byType(NavigationRail));

    // Starts on the first content section (Scenes == index 2; Adventure
    // settings is index 1).
    expect(rail().selectedIndex, 2);

    // Switch to the NPC section (index 3).
    await tester.tap(find.byKey(const ValueKey('nav.game.npcs')));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 3);

    // Switch to the Notes section (index 4).
    await tester.tap(find.byKey(const ValueKey('nav.game.notes')));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 4);

    // Switch to the Images section (index 6).
    await tester.tap(find.byKey(const ValueKey('nav.game.images')));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 6);

    // Switch to the Soundtracks section (index 7).
    await tester.tap(find.byKey(const ValueKey('nav.game.soundtracks')));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 7);

    // Switch to Paths (index 8).
    await tester.tap(find.byKey(const ValueKey('nav.game.paths')));
    await tester.pumpAndSettle();
    expect(rail().selectedIndex, 8);
  });

  testWidgets('Notes section shows the notes list with the Add-note row',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.notes')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        4);
    expect(find.byKey(const ValueKey('note.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('note.new')), findsOneWidget);
  });

  testWidgets('Images section shows the all-photos grid with the add tile',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.images')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        6);
    expect(find.byKey(const ValueKey('image.grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('image.new')), findsOneWidget);
  });

  testWidgets('Soundtracks section shows the search bar and add row',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.soundtracks')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        7);
    expect(find.byKey(const ValueKey('sound.search')), findsOneWidget);
    expect(find.byKey(const ValueKey('sound.list')), findsOneWidget);
    expect(find.byKey(const ValueKey('sound.new')), findsOneWidget);

    // The add row shows the Material Symbols Music Note Add glyph (no "+"/text).
    expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.byKey(const ValueKey('sound.new')),
              matching: find.byType(Icon),
            ))
            .icon,
        Symbols.music_note_add);
    expect(find.text('Add soundtrack'), findsNothing);
  });

  testWidgets('Paths section shows the path tiles (not a placeholder)',
      (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.paths')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        8);
    expect(find.byType(PathsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('game.paths.list')), findsOneWidget);
    expect(find.byType(PathTile), findsNWidgets(6));
  });

  testWidgets('Leaving Paths mid-edit prompts; Save persists the path name',
      (tester) async {
    _useTallView(tester);
    final store = _FakeStore(_seedDocument());
    await tester.pumpWidget(
        _app(GameScreen(slug: 'demo', onHome: () {}, store: store)));
    await tester.pumpAndSettle();

    // Open Paths, then a path's edit form.
    await tester.tap(find.byKey(const ValueKey('nav.game.paths')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('path.tile.green')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('game.paths.edit.field.name')), 'Trail');
    await tester.pumpAndSettle();

    // Try to leave the section -> unsaved prompt -> Save.
    await tester.tap(find.byKey(const ValueKey('nav.game.scenes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings.unsaved.dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings.unsaved.save')));
    await tester.pumpAndSettle();

    // Proceeded to Scenes; back on Paths the tile shows the saved name.
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2);
    await tester.tap(find.byKey(const ValueKey('nav.game.paths')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('path.tile.green.name')), findsOneWidget);
    expect(find.text('Trail'), findsOneWidget);

    // Persisted to disk: one paths entry { color: green, name: Trail }.
    expect(store.savedPaths, isNotNull);
    expect(store.savedPaths!.single['color'], 'green');
    expect(store.savedPaths!.single['name'], 'Trail');
  });

  testWidgets('Game Home destination invokes onHome (go to the Home view)',
      (tester) async {
    var homeRequested = false;
    await tester.pumpWidget(
        _app(GameScreen(slug: 'demo', onHome: () => homeRequested = true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav.game.home')));
    await tester.pumpAndSettle();
    expect(homeRequested, isTrue);
  });

  testWidgets('Adventure settings section loads the form and Save persists',
      (tester) async {
    // The two-column form is laid out for a desktop window; give the test view
    // comparable room so the cover and the actions row both fit.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeStore(_seedDocument());
    await tester.pumpWidget(_app(
        GameScreen(slug: 'demo', onHome: () {}, store: store)));
    await tester.pumpAndSettle();

    // Open Adventure settings (index 1).
    await tester.tap(find.byKey(const ValueKey('nav.game.settings')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1);
    expect(find.byType(AdventureSettingsScreen), findsOneWidget);

    // Title pre-filled from the loaded document.
    expect(find.text('Demo'), findsOneWidget);

    // Edit the title, then Save -> store.update gets the new metadata and the
    // section returns to the game content (Scenes == index 2).
    await tester.enterText(
        find.byKey(const ValueKey('game.settings.field.title')), 'Renamed');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('game.settings.save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game.settings.save')));
    await tester.pumpAndSettle();

    expect(store.savedMetadata?['name'], 'Renamed');
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2);
  });
}
