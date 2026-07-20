import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/game_screen.dart';
import 'package:living_scroll/widgets/rail_state.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

void _noop() {}

void main() {
  // The rail's open/closed state is app-wide and shared; reset it to collapsed
  // before each case (these tests toggle from a collapsed start).
  setUp(() => RailState.extended.value = false);

  // The in-game rail's bottom actions — Export (`nav.game.publish`) and Export
  // elements (`nav.game.export_part`) — must be LEFT-aligned when the rail is
  // expanded, exactly like the navigable destinations above them (not centered).
  testWidgets('expanded rail: Export / Export elements actions are left-aligned',
      (tester) async {
    // A tall desktop viewport so the whole rail (sections + bottom actions) fits.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: _noop)));
    await tester.pumpAndSettle();

    // Expand the rail so the actions render as icon + label buttons.
    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();

    final publish = find.byKey(const ValueKey('nav.game.publish'));
    final exportPart = find.byKey(const ValueKey('nav.game.export_part'));
    expect(publish, findsOneWidget);
    expect(exportPart, findsOneWidget);

    final publishLeft = tester.getTopLeft(publish).dx;
    final exportPartLeft = tester.getTopLeft(exportPart).dx;

    // Both actions share the same left edge (equal, since their labels differ in
    // width — centered actions would land at different left edges).
    expect(
      (publishLeft - exportPartLeft).abs(),
      lessThan(1.0),
      reason: 'bottom rail actions must be left-aligned, not centered '
          '(publish.dx=$publishLeft exportPart.dx=$exportPartLeft)',
    );

    // The action ICONS must line up with the DESTINATION icons above — same x —
    // so the footer reads as one column with the destinations, not shifted left.
    Offset iconCenter(Finder button) {
      final icon = find.descendant(of: button, matching: find.byType(Icon));
      expect(icon, findsOneWidget);
      return tester.getCenter(icon);
    }

    final destIcon = tester.getCenter(find.byKey(const ValueKey('nav.game.notes')));
    final publishIcon = iconCenter(publish);
    final exportPartIcon = iconCenter(exportPart);

    expect((publishIcon.dx - destIcon.dx).abs(), lessThan(2.0),
        reason: 'Export icon must align with the destination icons '
            '(export=${publishIcon.dx} dest=${destIcon.dx})');
    expect((exportPartIcon.dx - destIcon.dx).abs(), lessThan(2.0),
        reason: 'Export elements icon must align with the destination icons '
            '(export=${exportPartIcon.dx} dest=${destIcon.dx})');
  });

  // The footer icons must be the SAME size collapsed and expanded (and the same
  // size as the destination icons) — a plain TextButton defaults to an 18px icon,
  // which used to shrink the expanded footer icons below the collapsed 24px.
  testWidgets('footer icons keep their size when the rail expands',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: _noop)));
    await tester.pumpAndSettle();

    double footerIconSize() => tester
        .getSize(find.descendant(
            of: find.byKey(const ValueKey('nav.game.publish')),
            matching: find.byType(Icon)))
        .width;
    double destIconSize() =>
        tester.getSize(find.byKey(const ValueKey('nav.game.notes'))).width;

    final collapsedIcon = footerIconSize();
    final collapsedDest = destIconSize();

    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();

    expect(footerIconSize(), collapsedIcon,
        reason: 'footer icon size changed on expand '
            '(collapsed=$collapsedIcon expanded=${footerIconSize()})');
    // ...and it matches the destination icons in both states.
    expect(footerIconSize(), destIconSize());
    expect(collapsedIcon, collapsedDest);
  });

  // The WHOLE rail — destinations AND the footer — must be STATIC: toggling it
  // is instant, with no expand/collapse animation. So the rail width and the
  // destination/footer positions are already at their final values on the first
  // frame after the toggle (nothing animates between that frame and settled).
  testWidgets('expanding the rail is instant (destinations and footer static)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: _noop)));
    await tester.pumpAndSettle();
    final collapsedWidth = tester.getSize(find.byType(NavigationRail)).width;

    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pump(); // exactly one frame after the toggle

    double railWidth() => tester.getSize(find.byType(NavigationRail)).width;
    double destIconX() =>
        tester.getCenter(find.byKey(const ValueKey('nav.game.notes'))).dx;
    double footerWidth() =>
        tester.getSize(find.byKey(const ValueKey('nav.game.publish'))).width;

    final railAtStart = railWidth();
    final destAtStart = destIconX();
    final footerAtStart = footerWidth();

    // It really expanded on that first frame (not still collapsed)...
    expect(railAtStart, greaterThan(collapsedWidth + 100),
        reason: 'rail did not expand instantly (start=$railAtStart '
            'collapsed=$collapsedWidth)');

    await tester.pumpAndSettle();

    // ...and nothing moved/resized between the first frame and settled — no
    // animation for either the destinations or the footer.
    expect(railWidth(), railAtStart, reason: 'rail width animated');
    expect(destIconX(), destAtStart, reason: 'a destination animated on expand');
    expect(footerWidth(), footerAtStart, reason: 'the footer animated on expand');
  });

  // The bottom actions must read the same collapsed and expanded: same row
  // HEIGHT and same icon/label COLOUR (they used to switch from a grey, 48-tall
  // icon button to a shorter, primary-coloured text button on expand).
  testWidgets('footer actions keep their height and colour when the rail expands',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GameScreen(slug: 'demo', onHome: _noop)));
    await tester.pumpAndSettle();

    final publish = find.byKey(const ValueKey('nav.game.publish'));
    Color iconColour(Finder button) {
      final icon = find.descendant(of: button, matching: find.byType(Icon));
      expect(icon, findsOneWidget);
      final w = tester.widget<Icon>(icon);
      return w.color ?? IconTheme.of(tester.element(icon)).color!;
    }

    final collapsedHeight = tester.getSize(publish).height;
    final collapsedColour = iconColour(publish);

    await tester.tap(find.byIcon(Symbols.side_navigation));
    await tester.pumpAndSettle();

    final expandedPublish = find.byKey(const ValueKey('nav.game.publish'));
    final expandedHeight = tester.getSize(expandedPublish).height;
    final expandedColour = iconColour(expandedPublish);

    expect(expandedHeight, collapsedHeight,
        reason: 'footer row height changed on expand '
            '(collapsed=$collapsedHeight expanded=$expandedHeight)');
    expect(expandedColour, collapsedColour,
        reason: 'footer colour changed on expand '
            '(collapsed=$collapsedColour expanded=$expandedColour)');
  });
}
