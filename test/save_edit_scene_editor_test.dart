import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/images/bg_images_controller.dart';
import 'package:living_scroll/images/images_controller.dart';
import 'package:living_scroll/keyevents/key_events_controller.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/notes/notes_controller.dart';
import 'package:living_scroll/npcs/npcs_controller.dart';
import 'package:living_scroll/scenes/scenes_controller.dart';
import 'package:living_scroll/screens/scene_edit_screen.dart';
import 'package:living_scroll/soundtracks/soundtracks_controller.dart';

/// The `next_scenes` exception: a FROZEN (immutable) scene opens
/// the editor but only its `next_scenes` list is editable — links may be added,
/// and removed ONLY when the target scene is non-immutable. All other fields are
/// frozen (behind an `ignoring` IgnorePointer).
void main() {
  Finder byId(String k) => find.byKey(ValueKey(k));

  // Three scenes: a frozen base pointing at one immutable and one mutable scene.
  Map<String, dynamic> doc() => {
    'scenes': [
      {
        'scene_uuid': 'base',
        'name': 'Base',
        'scene_type': 'standard',
        'next_scenes': ['imm', 'mut'],
        'notes': ['note1'], // a linked (base) note -> should render locked
        'immutable': true,
      },
      {
        'scene_uuid': 'imm',
        'name': 'Old target',
        'scene_type': 'standard',
        'immutable': true,
      },
      {
        'scene_uuid': 'mut',
        'name': 'New target',
        'scene_type': 'standard',
      }, // no immutable flag -> mutable
      {
        'scene_uuid': 'imm2',
        'name': 'Other frozen',
        'scene_type': 'standard',
        'immutable': true,
      }, // immutable, NOT linked -> must not be an add candidate
    ],
  };

  // A NotesController holding the linked base note (note1).
  NotesController notesCtrl() => NotesController()
    ..loadFrom({
      'notes': [
        {
          'note_uuid': 'note1',
          'note_name': 'Clue',
          'note_content': 'x',
          'immutable': true,
        },
      ],
    });

  Widget host(ScenesController scenes) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: SceneEditScreen(
      controller: scenes,
      onSave: () async {},
      onCancel: () {},
      npcs: NpcsController(),
      notes: notesCtrl(),
      keyEvents: KeyEventsController(),
      images: ImagesController(),
      soundtracks: SoundtracksController(),
      bgImages: BgImagesController(),
      npcsImagesPath: '/tmp/x/npcs',
      imagesOtherPath: '/tmp/x/other',
      bgImagesPath: '/tmp/x/bg',
      readOnly: true,
    ),
  );

  testWidgets(
    'frozen scene: next_scenes editable, immutable link not removable',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scenes = ScenesController()..loadFrom(doc());
      scenes.beginEdit('base');
      await tester.pumpWidget(host(scenes));
      await tester.pump();

      // The next_scenes ADD button is present and enabled (adding is allowed).
      final add = byId('game.scenes.edit.nextscenes.add');
      expect(add, findsOneWidget);

      // Link to the IMMUTABLE target: locked, not removable.
      expect(
        byId('game.scenes.edit.nextscenes.tile.imm.locked'),
        findsOneWidget,
      );
      expect(byId('game.scenes.edit.nextscenes.tile.imm.delete'), findsNothing);

      // Link to the MUTABLE (new) target: removable.
      expect(
        byId('game.scenes.edit.nextscenes.tile.mut.delete'),
        findsOneWidget,
      );
      expect(byId('game.scenes.edit.nextscenes.tile.mut.locked'), findsNothing);

      // The rest of the form is frozen: the name field sits under an `ignoring`
      // IgnorePointer.
      final frozen = find.ancestor(
        of: byId('game.scenes.edit.field.name'),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring == true,
        ),
      );
      expect(frozen, findsOneWidget);

      // The linked base note shows a lock instead of a delete button.
      expect(byId('game.scenes.edit.notes.tile.note1.locked'), findsOneWidget);
      expect(byId('game.scenes.edit.notes.tile.note1.delete'), findsNothing);

      // The scene-type buttons are greyed out (disabled).
      for (final t in ['start', 'standard', 'recurring', 'end']) {
        final btn = tester.widget<ButtonStyleButton>(
          byId('game.scenes.edit.scenetype.$t'),
        );
        expect(
          btn.onPressed,
          isNull,
          reason: '$t type button must be disabled',
        );
      }
    },
  );

  testWidgets(
    'frozen scene: next_scenes picker offers ONLY non-immutable scenes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scenes = ScenesController()..loadFrom(doc());
      scenes.beginEdit('base');
      await tester.pumpWidget(host(scenes));
      await tester.pump();

      // Open the next_scenes picker.
      await tester.tap(byId('game.scenes.edit.nextscenes.add'));
      await tester.pumpAndSettle();

      // Only the mutable scene is a candidate; immutable scenes (linked 'imm' and
      // unlinked 'imm2') are NOT offered.
      expect(byId('scene.nextscenes.select.tile.mut'), findsOneWidget);
      expect(byId('scene.nextscenes.select.tile.imm'), findsNothing);
      expect(byId('scene.nextscenes.select.tile.imm2'), findsNothing);
    },
  );

  testWidgets('mutable (new) scene: fully editable, no next_scenes locks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scenes = ScenesController()..loadFrom(doc());
    scenes.beginEdit('mut'); // the mutable scene
    await tester.pumpWidget(host(scenes));
    await tester.pump();

    // No fields are frozen for a mutable scene.
    final frozen = find.ancestor(
      of: byId('game.scenes.edit.field.name'),
      matching: find.byWidgetPredicate(
        (w) => w is IgnorePointer && w.ignoring == true,
      ),
    );
    expect(frozen, findsNothing);

    // The scene-type buttons are enabled (not greyed).
    final start = tester.widget<ButtonStyleButton>(
      byId('game.scenes.edit.scenetype.start'),
    );
    expect(start.onPressed, isNotNull);
  });
}
