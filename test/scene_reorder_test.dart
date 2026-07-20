import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/images/bg_images_controller.dart';
import 'package:living_scroll/images/images_controller.dart';
import 'package:living_scroll/keyevents/key_events_controller.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/notes/notes_controller.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/scenes/scenes_controller.dart';
import 'package:living_scroll/screens/scenes_screen.dart';
import 'package:living_scroll/soundtracks/soundtracks_controller.dart';

/// Drag-to-reorder of scenes: a swap_vert handle (first from the left) on each
/// scene tile reorders the scenes[] list; the change is persisted. The handle is
/// shown only on the full (unfiltered) list, and ALSO in save-edit (reorder is a
/// list-order change, not a graph change).
void main() {
  Finder byId(String k) => find.byKey(ValueKey(k));

  Map<String, dynamic> doc(List<String> uuids) => {
        'scenes': [
          for (final u in uuids)
            {'scene_uuid': u, 'name': u.toUpperCase(), 'scene_type': 'standard'},
        ],
      };

  group('ScenesController.reorder', () {
    List<String> order(ScenesController c) =>
        [for (final s in c.scenes) s.uuid];

    test('moves an item to a later position (post-removal index)', () {
      final c = ScenesController()..loadFrom(doc(['s1', 's2', 's3']));
      c.reorder(0, 2); // remove s1 -> [s2,s3], insert at 2 -> [s2,s3,s1]
      expect(order(c), ['s2', 's3', 's1']);
    });

    test('moves an item to an earlier position', () {
      final c = ScenesController()..loadFrom(doc(['s1', 's2', 's3']));
      c.reorder(2, 0); // remove s3 -> [s1,s2], insert at 0 -> [s3,s1,s2]
      expect(order(c), ['s3', 's1', 's2']);
    });

    test('swap of adjacent items keeps the rest', () {
      final c = ScenesController()..loadFrom(doc(['s1', 's2', 's3', 's4']));
      c.reorder(0, 1); // remove s1 -> [s2,s3,s4], insert at 1 -> [s2,s1,s3,s4]
      expect(order(c), ['s2', 's1', 's3', 's4']);
    });

    test('out-of-range oldIndex is a no-op', () {
      final c = ScenesController()..loadFrom(doc(['s1', 's2']));
      c.reorder(5, 0);
      expect(order(c), ['s1', 's2']);
    });
  });

  group('ScenesScreen reorder handles', () {
    int persistCount = 0;
    late ScenesController controller;

    Widget host({bool readOnly = false}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ScenesScreen(
              controller: controller,
              onPersist: () async => persistCount++,
              onPreview: (_) {},
              npcs: NpcsController(),
              notes: NotesController(),
              keyEvents: KeyEventsController(),
              images: ImagesController(),
              soundtracks: SoundtracksController(),
              bgImages: BgImagesController(),
              npcsImagesPath: '/tmp/x/npcs',
              imagesOtherPath: '/tmp/x/other',
              bgImagesPath: '/tmp/x/bg',
              readOnly: readOnly,
            ),
          ),
        );

    setUp(() {
      persistCount = 0;
      controller = ScenesController()..loadFrom(doc(['s1', 's2', 's3']));
    });

    testWidgets('each scene tile has a swap_vert reorder handle; Add tile stays',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(byId('scene.new'), findsOneWidget);
      expect(byId('scene.tile.s1.reorder'), findsOneWidget);
      expect(byId('scene.tile.s2.reorder'), findsOneWidget);
      expect(byId('scene.tile.s3.reorder'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsNWidgets(3));
    });

    testWidgets('handles are HIDDEN while the search filter is active',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.enterText(byId('scene.search'), 's1');
      await tester.pumpAndSettle();

      expect(byId('scene.tile.s1.reorder'), findsNothing);
      expect(find.byIcon(Icons.swap_vert), findsNothing);
    });

    testWidgets('handles ARE shown in save-edit (reorder allowed)',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(readOnly: true));
      await tester.pumpAndSettle();
      expect(byId('scene.tile.s1.reorder'), findsOneWidget);
    });

    testWidgets('dragging a handle reorders and persists', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(controller.scenes.first.uuid, 's1');

      // Grab the first tile's handle and drag it downward past the next tile.
      // ReorderableDragStartListener is an IMMEDIATE drag: start a manual gesture
      // and move in small steps with pumps so the reorder is recognised.
      final start = tester.getCenter(byId('scene.tile.s1.reorder'));
      final gesture = await tester.startGesture(start);
      await tester.pump();
      for (var dy = 20.0; dy <= 180; dy += 20) {
        await gesture.moveTo(Offset(start.dx, start.dy + dy));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(persistCount, greaterThan(0), reason: 'reorder must persist');
      expect(controller.scenes.first.uuid, isNot('s1'),
          reason: 's1 was dragged down, so it is no longer first');
      // The set of scenes is unchanged (only the order moved).
      expect(controller.scenes.map((s) => s.uuid).toSet(),
          {'s1', 's2', 's3'});
    });
  });
}
