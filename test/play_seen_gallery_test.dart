// Widget coverage for the play view's "seen" gallery: the Notes section shows
// the current scene's notes, then — when seenNotes is non-empty — a horizontal
// divider and the already-seen notes below it. The
// on-disk commit + images path are covered by commit_seen_test.dart and the
// integration test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/scenes/scene.dart';
import 'package:living_scroll/screens/play_screen.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: home),
);

Scene _scene() => Scene.fromJson({
  'name': 'Scene',
  'scene_uuid': 's1',
  'scene_type': 'standard',
  'description': 'A room.',
});

({String uuid, String name, String content}) _note(String uuid, String name) =>
    (uuid: uuid, name: name, content: 'body of $name');

PlayScreen _play({
  List<({String uuid, String name, String content})> notes = const [],
  List<({String uuid, String name, String content})> seenNotes = const [],
}) => PlayScreen(
  scene: _scene(),
  mode: PlayMode.gameplay,
  keyEvents: const [],
  nextScenes: const [],
  npcs: const [],
  notes: notes,
  images: const [],
  seenNotes: seenNotes,
  onExit: () {},
);

Future<void> _pump(WidgetTester tester, PlayScreen play) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(play));
  await tester.pumpAndSettle();
}

final _divider = find.byKey(const ValueKey('play.notes.seen.divider'));

void main() {
  testWidgets('seen notes render below a divider, under the scene notes', (
    tester,
  ) async {
    await _pump(
      tester,
      _play(
        notes: [_note('n1', 'Current clue')],
        seenNotes: [_note('n2', 'Old clue'), _note('n3', 'Older clue')],
      ),
    );

    expect(find.byKey(const ValueKey('play.notes.center')), findsOneWidget);
    // The current scene's note is above; the divider separates the seen ones.
    expect(find.byKey(const ValueKey('play.note.tile.n1')), findsOneWidget);
    expect(_divider, findsOneWidget);
    expect(find.byKey(const ValueKey('play.note.seen.n2')), findsOneWidget);
    expect(find.byKey(const ValueKey('play.note.seen.n3')), findsOneWidget);

    // The divider sits BELOW the scene note and ABOVE the seen notes.
    final sceneBottom = tester
        .getRect(find.byKey(const ValueKey('play.note.tile.n1')))
        .bottom;
    final dividerY = tester.getRect(_divider).center.dy;
    final seenTop = tester
        .getRect(find.byKey(const ValueKey('play.note.seen.n2')))
        .top;
    expect(dividerY, greaterThanOrEqualTo(sceneBottom));
    expect(seenTop, greaterThanOrEqualTo(dividerY));
  });

  testWidgets('no divider when there are no seen notes', (tester) async {
    await _pump(tester, _play(notes: [_note('n1', 'Current clue')]));
    expect(find.byKey(const ValueKey('play.note.tile.n1')), findsOneWidget);
    expect(_divider, findsNothing);
  });

  testWidgets('the seen gallery shows even when the scene has no notes', (
    tester,
  ) async {
    // _hasNotes is true when seenNotes is non-empty, so the section still renders.
    await _pump(tester, _play(seenNotes: [_note('n2', 'Old clue')]));
    expect(find.byKey(const ValueKey('play.notes.center')), findsOneWidget);
    expect(find.byKey(const ValueKey('play.note.seen.n2')), findsOneWidget);
    expect(_divider, findsOneWidget);
  });
}
