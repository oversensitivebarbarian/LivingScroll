import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/scenes/scenes_controller.dart' show ScenePathRef;
import 'package:living_scroll/widgets/scene_map/scene_graph.dart';
import 'package:living_scroll/widgets/scene_map/scene_map_view.dart';
// The scene map is DISABLED in the app shell for now (kept for future work; see
// docs/scene_map_widget.md). The standalone SceneMapView tests below still run;
// the two menu-integration tests + their helpers are commented out until the map
// is re-enabled in game_screen / play_screen.
// import 'package:living_scroll/create/cover_crop.dart';
// import 'package:living_scroll/create/projects_store.dart';
// import 'package:living_scroll/screens/game_screen.dart';
// import 'package:living_scroll/screens/play_screen.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _doc() =>
    jsonDecode(File('test/fixtures/scene_map/adventure.json').readAsStringSync())
        as Map<String, dynamic>;

(List<Scene>, List<ScenePathRef>) _load() {
  final doc = _doc();
  final scenes = [for (final s in (doc['scenes'] as List)) Scene.fromJson(s as Map)];
  final paths = <ScenePathRef>[
    for (final p in (doc['paths'] as List))
      (colorId: (p as Map)['color'] as String, name: p['name'] as String),
  ];
  return (scenes, paths);
}

SceneMapView _mapView({
  ValueChanged<String>? onSceneTap,
  bool empty = false,
}) {
  final loaded = _load();
  final scenes = empty ? <Scene>[] : loaded.$1;
  final paths = empty ? <ScenePathRef>[] : loaded.$2;
  final model =
      buildSceneGraph(scenes: scenes, paths: paths, mode: SceneMapMode.game);
  return SceneMapView(
    model: model,
    mode: SceneMapMode.game,
    paths: paths,
    onSceneTap: onSceneTap,
    animated: false,
  );
}

// In-memory store that fed the fixture document into GameScreen — only needed by
// the (disabled) game-view menu test below.
// class _FakeStore implements ProjectsStore {
//   _FakeStore(this._document);
//   final Map<String, dynamic> _document;
//
//   @override
//   Future<Map<String, dynamic>?> read(String slug) async => _document;
//   @override
//   Future<File?> coverFile(String slug) async => null;
//   @override
//   Future<String> locationImagesPath(String slug) async => '';
//   @override
//   Future<String> imagesOtherPath(String slug) async => '';
//   @override
//   Future<String> npcImagesPath(String slug) async => '';
//   @override
//   Future<String> audioPath(String slug) async => '';
//   @override
//   Future<void> update({
//     required String slug,
//     required Map<String, String> metadata,
//     String? coverSourcePath,
//     CoverCrop? coverCrop,
//   }) async {}
//   @override
//   noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
// }

const s1 = '00000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('renders the scene map without exception for the fixture',
      (tester) async {
    _bigView(tester);
    await tester.pumpWidget(_app(_mapView()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('scene.map.view')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty model shows the empty-state message', (tester) async {
    _bigView(tester);
    await tester.pumpWidget(_app(_mapView(empty: true)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('scene.map.empty')), findsOneWidget);
  });

  testWidgets('each station shows its scene-type icon (sceneTypeIcon)',
      (tester) async {
    _bigView(tester);
    await tester.pumpWidget(_app(_mapView()));
    await tester.pump(const Duration(seconds: 1));

    Finder iconIn(String uuid, IconData icon) => find.descendant(
          of: find.byKey(ValueKey('scene.map.node.$uuid')),
          matching: find.byIcon(icon),
        );

    // s1 start, s6 recurring, s10 end (per the fixture) -> the same glyphs the
    // scene tile / type radios use.
    expect(iconIn(s1, Icons.play_circle), findsOneWidget);
    expect(
        iconIn('00000000-0000-0000-0000-000000000006', Icons.change_circle),
        findsOneWidget);
    expect(iconIn('00000000-0000-0000-0000-000000000010', Icons.stop_circle),
        findsOneWidget);
  });

  testWidgets('tapping a station fires onSceneTap with its scene_uuid',
      (tester) async {
    _bigView(tester);
    String? tapped;
    await tester.pumpWidget(_app(_mapView(onSceneTap: (uuid) => tapped = uuid)));
    await tester.pump(const Duration(seconds: 1));

    final node = find.byKey(const ValueKey('scene.map.node.$s1'));
    expect(node, findsOneWidget);
    await tester.tap(node, warnIfMissed: false);
    await tester.pump();
    expect(tapped, s1);
  });

  testWidgets('the line legend filters: selecting a line toggles its chip',
      (tester) async {
    _bigView(tester);
    await tester.pumpWidget(_app(_mapView()));
    await tester.pump(const Duration(seconds: 1));

    final red = find.byKey(const ValueKey('scene.map.legend.line.red'));
    expect(red, findsOneWidget);

    FilterChip chip() => tester.widget<FilterChip>(red);
    expect(chip().selected, isFalse);

    await tester.tap(red);
    await tester.pump();
    expect(chip().selected, isTrue);

    // "All paths" clears the filter.
    await tester.tap(find.byKey(const ValueKey('scene.map.legend.all')));
    await tester.pump();
    expect(chip().selected, isFalse);
  });

  // --- Menu-integration tests — DISABLED while the map is off ---------------
  // Re-enable together with the `nav.game.map` destination (game_screen) and the
  // `nav.play.map` rail item (play_screen). See docs/scene_map_widget.md.
  //
  // testWidgets('game view: a Map destination with Icons.map opens the map',
  //     (tester) async {
  //   _bigView(tester);
  //   await tester.pumpWidget(_app(
  //       GameScreen(slug: 'demo', onHome: () {}, store: _FakeStore(_doc()))));
  //   await tester.pumpAndSettle();
  //
  //   // The Map destination exists in the rail.
  //   expect(find.byKey(const ValueKey('nav.game.map')), findsWidgets);
  //
  //   // Open it -> the map view appears and the selected icon is Icons.map.
  //   await tester.tap(find.byKey(const ValueKey('nav.game.map')).first);
  //   await tester.pump(const Duration(seconds: 1));
  //
  //   expect(find.byKey(const ValueKey('scene.map.view')), findsOneWidget);
  //   expect(find.byIcon(Icons.map), findsWidgets);
  // });
  //
  // testWidgets('play view: a Map rail item with Icons.map shows the injected map',
  //     (tester) async {
  //   _bigView(tester);
  //   final loaded = _load();
  //   final model = buildSceneGraph(
  //       scenes: loaded.$1, paths: loaded.$2, mode: SceneMapMode.play);
  //   final map = SceneMapView(
  //     model: model,
  //     mode: SceneMapMode.play,
  //     paths: loaded.$2,
  //     animated: false,
  //   );
  //
  //   await tester.pumpWidget(_app(PlayScreen(
  //     scene: Scene(uuid: 'cur', name: 'Current'),
  //     mode: PlayMode.gameplay,
  //     keyEvents: const [],
  //     nextScenes: const [],
  //     npcs: const [],
  //     notes: const [],
  //     images: const [],
  //     onExit: () {},
  //     mapView: map,
  //   )));
  //   await tester.pumpAndSettle();
  //
  //   final mapItem = find.byKey(const ValueKey('nav.play.map'));
  //   expect(mapItem, findsWidgets);
  //   expect(tester.widget<Icon>(mapItem.first).icon, Icons.map);
  //
  //   await tester.tap(mapItem.first);
  //   await tester.pump(const Duration(seconds: 1));
  //   expect(find.byKey(const ValueKey('scene.map.view')), findsOneWidget);
  // });
}
