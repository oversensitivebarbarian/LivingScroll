import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:living_scroll/l10n/app_localizations.dart';
import 'package:living_scroll/screens/adventure_tile.dart';

/// A Saves tile's corner button opens an **Edit / Delete**
/// dialog (replacing the direct delete button) — Edit opens the save in the game
/// editor, Delete runs the existing delete flow. The tile body still resumes.
void main() {
  Finder byId(String k) => find.byKey(ValueKey(k));

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  const save = AdventureSummary(slug: 'demo-1-wed', name: 'Demo', group: 'Wed');

  testWidgets('Saves tile shows an actions button, not a direct delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () {},
          onDelete: () {},
          onEdit: () {},
          deleteAsButton: true,
        ),
      ),
    );
    expect(byId('adventure.tile.demo-1-wed.actions'), findsOneWidget);
    // The direct delete button is replaced by the actions button.
    expect(byId('adventure.tile.demo-1-wed.delete'), findsNothing);
  });

  testWidgets('actions dialog: Edit runs onEdit', (tester) async {
    var edited = false, deleted = false, opened = false;
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () => opened = true,
          onDelete: () => deleted = true,
          onEdit: () => edited = true,
          deleteAsButton: true,
        ),
      ),
    );

    await tester.tap(byId('adventure.tile.demo-1-wed.actions'));
    await tester.pumpAndSettle();
    expect(byId('library.save.actions.dialog'), findsOneWidget);
    expect(byId('library.save.actions.edit'), findsOneWidget);
    expect(byId('library.save.actions.delete'), findsOneWidget);

    await tester.tap(byId('library.save.actions.edit'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
    expect(deleted, isFalse);
    expect(opened, isFalse); // opening the editor is not "resume"
    expect(byId('library.save.actions.dialog'), findsNothing); // dialog closed
  });

  testWidgets('actions dialog: Delete runs onDelete', (tester) async {
    var edited = false, deleted = false;
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () {},
          onDelete: () => deleted = true,
          onEdit: () => edited = true,
          deleteAsButton: true,
        ),
      ),
    );

    await tester.tap(byId('adventure.tile.demo-1-wed.actions'));
    await tester.pumpAndSettle();
    await tester.tap(byId('library.save.actions.delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(edited, isFalse);
  });

  testWidgets('actions dialog: Cancel closes without acting', (tester) async {
    var edited = false, deleted = false;
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () {},
          onDelete: () => deleted = true,
          onEdit: () => edited = true,
          deleteAsButton: true,
        ),
      ),
    );

    await tester.tap(byId('adventure.tile.demo-1-wed.actions'));
    await tester.pumpAndSettle();
    await tester.tap(byId('library.save.actions.cancel'));
    await tester.pumpAndSettle();
    expect(byId('library.save.actions.dialog'), findsNothing);
    expect(edited, isFalse);
    expect(deleted, isFalse);
  });

  testWidgets('tile body still resumes (onOpen)', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () => opened = true,
          onDelete: () {},
          onEdit: () {},
          deleteAsButton: true,
        ),
      ),
    );
    await tester.tap(byId('adventure.tile.demo-1-wed'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('a Finished tile (no onEdit) keeps the direct delete button', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AdventureTile(
          adventure: save,
          onOpen: () {},
          onDelete: () {},
          deleteAsButton: true, // no onEdit -> direct delete
        ),
      ),
    );
    expect(byId('adventure.tile.demo-1-wed.delete'), findsOneWidget);
    expect(byId('adventure.tile.demo-1-wed.actions'), findsNothing);
  });
}
