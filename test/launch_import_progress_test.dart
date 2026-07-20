import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_launch_screen.dart';
import 'package:living_scroll/widgets/rail_state.dart';

/// Widget coverage for the adventure launch screen's two launch-time additions:
///   * a NEW game shows an "Import progress" button (between Cancel and Prep mode)
///     that picks a finished game to import progress (key events, NPC states,
///     GM notes) from, applied on launch;
///   * a RESUME edits the players roster (fields enabled, +/remove shown) and
///     persists it on launch, while the group name stays fixed.
Widget _wrap(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

Map<String, dynamic> _docWithStart() => {
      'metadata': {'name': 'Pack', 'system': 'basic'},
      'key_events': [],
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'Opening',
          'scene_type': 'start',
          'description': 'It begins.',
        },
      ],
    };

void main() {
  setUp(() => RailState.extended.value = false);

  Future<void> pumpLaunch(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(screen));
    await tester.pumpAndSettle();
  }

  group('Import progress button (new game)', () {
    testWidgets('is shown between Cancel and Prep mode for a new game',
        (tester) async {
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          adventure: const AdventureSummary(slug: 'demo', name: 'Pack'),
          store: _FakeStore(doc: _docWithStart()),
        ),
      );

      expect(find.byKey(const ValueKey('launch.import.progress')), findsOneWidget);

      // Ordering: Cancel -> Import progress -> Prep mode, left to right.
      final cancelX =
          tester.getCenter(find.byKey(const ValueKey('launch.cancel'))).dx;
      final importX = tester
          .getCenter(find.byKey(const ValueKey('launch.import.progress')))
          .dx;
      final prepX =
          tester.getCenter(find.byKey(const ValueKey('launch.dryrun'))).dx;
      expect(cancelX, lessThan(importX));
      expect(importX, lessThan(prepX));
    });

    testWidgets('is ABSENT on a resume', (tester) async {
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          adventure: const AdventureSummary(slug: 'save', name: 'Pack'),
          resumeSaveName: 'save',
          store: _FakeStore(doc: _docWithStart(), players: const ['Alice']),
        ),
      );

      expect(find.byKey(const ValueKey('launch.import.progress')), findsNothing);
    });

    testWidgets(
        'picker shows finished games as browse-only tiles and filters same-game',
        (tester) async {
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          // Launching "Pack" 1.0.0 — its own finished session is filtered out.
          adventure: const AdventureSummary(
              slug: 'demo', name: 'Pack', version: '1.0.0'),
          store: _FakeStore(doc: _docWithStart(), finished: const [
            AdventureSummary(slug: 'Old-1', name: 'Old', version: '1.0.0'),
            AdventureSummary(
                slug: 'Pack-self', name: 'Pack', version: '1.0.0'),
          ]),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('launch.import.progress')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('launch.import.dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('launch.import.grid')), findsOneWidget);
      // The picker uses the SAME AdventureTile as the Library Saves grid.
      expect(find.byKey(const ValueKey('adventure.tile.Old-1')), findsOneWidget);
      // Tiles are browse-only — no delete button.
      expect(find.byKey(const ValueKey('adventure.tile.Old-1.delete')),
          findsNothing);
      expect(find.byKey(const ValueKey('adventure.tile.Old-1.actions')),
          findsNothing);
      // The SAME game's finished session (Pack 1.0.0) is filtered out.
      expect(
          find.byKey(const ValueKey('adventure.tile.Pack-self')), findsNothing);
    });

    testWidgets('empty state when there are no importable finished games',
        (tester) async {
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          // The only finished session is the same game -> filtered out -> empty.
          adventure: const AdventureSummary(
              slug: 'demo', name: 'Pack', version: '1.0.0'),
          store: _FakeStore(doc: _docWithStart(), finished: const [
            AdventureSummary(
                slug: 'Pack-self', name: 'Pack', version: '1.0.0'),
          ]),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('launch.import.progress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.import.empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('launch.import.grid')), findsNothing);
    });

    testWidgets('tapping a tile picks it; applied on Play', (tester) async {
      final store = _FakeStore(doc: _docWithStart(), finished: const [
        AdventureSummary(slug: 'Old-1', name: 'Old', version: '1.0.0'),
      ]);
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          adventure: const AdventureSummary(
              slug: 'demo', name: 'Pack', version: '1.0.0'),
          store: store,
        ),
      );

      // Pick the finished game by tapping its tile (closes the picker).
      await tester.tap(find.byKey(const ValueKey('launch.import.progress')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('adventure.tile.Old-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.import.dialog')), findsNothing);

      // Enter a group name and launch.
      await tester.enterText(
          find.byKey(const ValueKey('launch.field.group')), 'Team A');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('launch.play')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(store.startedSave, isNotNull);
      expect(store.importedFrom, 'Old-1');
      expect(store.importedInto, store.startedSave);
    });
  });

  group('Resume roster is editable', () {
    testWidgets('player fields are enabled with + / remove controls',
        (tester) async {
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          adventure: const AdventureSummary(slug: 'save', name: 'Pack'),
          resumeSaveName: 'save',
          store:
              _FakeStore(doc: _docWithStart(), players: const ['Alice', 'Bob']),
        ),
      );

      final f0 = tester
          .widget<TextField>(find.byKey(const ValueKey('launch.player.0')));
      expect(f0.enabled, isNot(false)); // editable on resume (default-enabled)
      expect(f0.controller!.text, 'Alice'); // pre-filled from group.json
      // The group name, by contrast, stays disabled.
      final group = tester
          .widget<TextField>(find.byKey(const ValueKey('launch.field.group')));
      expect(group.enabled, isFalse);

      expect(
          find.byKey(const ValueKey('launch.players.add')), findsOneWidget);
      expect(find.byKey(const ValueKey('launch.player.0.remove')),
          findsOneWidget);

      // Add a third player field.
      await tester.tap(find.byKey(const ValueKey('launch.players.add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch.player.2')), findsOneWidget);
    });

    testWidgets('launching a resume persists the edited roster', (tester) async {
      final store =
          _FakeStore(doc: _docWithStart(), players: const ['Alice']);
      await pumpLaunch(
        tester,
        AdventureLaunchScreen(
          adventure: const AdventureSummary(slug: 'save', name: 'Pack'),
          resumeSaveName: 'save',
          store: store,
        ),
      );

      // Add a second player and fill it in.
      await tester.tap(find.byKey(const ValueKey('launch.players.add')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('launch.player.1')), 'Bob');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('launch.play')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(store.savedPlayersFor, 'save');
      expect(store.savedPlayers, ['Alice', 'Bob']);
    });
  });
}

/// A [ProjectsStore] stub that returns fixed data and records the launch-time
/// calls the screen makes (import + roster persistence), without touching disk.
class _FakeStore extends ProjectsStore {
  _FakeStore({
    this.doc,
    this.players = const [],
    this.finished = const [],
  });

  final Map<String, dynamic>? doc;
  final List<String> players;
  final List<AdventureSummary> finished;

  String? startedSave;
  String? importedFrom;
  String? importedInto;
  String? savedPlayersFor;
  List<String>? savedPlayers;

  @override
  Future<Map<String, dynamic>?> readAdventure(String dir) async => doc;

  @override
  Future<Map<String, dynamic>?> readSave(String saveName) async => doc;

  @override
  Future<String> readSaveGroup(String saveName) async => 'Team A';

  @override
  Future<List<String>> readSavePlayers(String saveName) async => players;

  @override
  Future<List<String>> readSaveHistory(String saveName) async => const [];

  @override
  Future<Map<String, dynamic>?> readPartyState(String saveName) async => null;

  @override
  Future<List<AdventureSummary>> listFinished() async => finished;

  @override
  Future<bool> saveExists(String saveName) async => false;

  @override
  Future<String?> startSaveFromLibrary({
    required String adventureDir,
    required String groupName,
    List<String> players = const [],
    bool overwrite = false,
  }) async =>
      startedSave = 'Pack-1.0.0-$groupName';

  @override
  Future<void> importSaveProgress({
    required String saveName,
    required String fromFinishedDir,
  }) async {
    importedInto = saveName;
    importedFrom = fromFinishedDir;
  }

  @override
  Future<void> writeSavePlayers(String saveName, List<String> players) async {
    savedPlayersFor = saveName;
    savedPlayers = players;
  }
}
