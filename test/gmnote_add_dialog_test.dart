// Widget coverage for the add-GM-note dialog (play.gmnote.add): a PLAIN content
// input only — a GM note is ALWAYS global, so there is NO scope checkbox. The
// content box takes its MAXIMUM adventure-tile size on a tall window but FLEXES
// SMALLER on a short window (non-scrollable, capped) so it never overflows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/play_screen.dart';

const _maxHeight = 480 * 1.43; // the content box's maximum height (686.4)

final _dialog = find.byKey(const ValueKey('play.gmnote.add'));
final _body = find.byKey(const ValueKey('play.gmnote.add.body'));
final _global = find.byKey(const ValueKey('play.gmnote.add.global'));

Future<void> _open(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showAddGmNoteDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the form has NO scope checkbox — a GM note is always global',
      (tester) async {
    await _open(tester, const Size(900, 1000));
    expect(_dialog, findsOneWidget);
    expect(find.byKey(const ValueKey('play.gmnote.add.content')), findsOneWidget);
    expect(_global, findsNothing);
  });

  testWidgets('tall window: the content box takes its MAX adventure-tile size',
      (tester) async {
    await _open(tester, const Size(900, 1000));
    final body = tester.getSize(_body);
    expect(body.width, moreOrLessEquals(480, epsilon: 0.5));
    expect(body.height, moreOrLessEquals(_maxHeight, epsilon: 0.5));
  });

  testWidgets('short window: the content box shrinks (capped) without overflow',
      (tester) async {
    // The verified minimum window (640x480 landscape) — the tightest case.
    await _open(tester, const Size(640, 480));
    expect(_dialog, findsOneWidget);
    final body = tester.getSize(_body);
    // Width unchanged; height CAPPED and SHRUNK below the maximum (no overflow —
    // the test framework would throw on a RenderFlex overflow during pump).
    expect(body.width, moreOrLessEquals(480, epsilon: 0.5));
    expect(body.height, lessThan(_maxHeight));
  });
}
