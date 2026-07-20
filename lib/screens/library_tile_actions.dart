import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../services/file_picker_service.dart';
import 'adventure_info_dialog.dart';
import 'adventure_launch_screen.dart';
import 'library_duplicate_dialog.dart';

/// Shared tile-tap actions used by BOTH the Library tabs and the Home view, so a
/// tile behaves identically wherever it is shown.

/// Import tile (Library Adventures grid + Home empty state): pick a `.ls`, import
/// it into the library, and surface the outcome as a SnackBar. A duplicate raises
/// the same Overwrite/Cancel dialog as Export. Returns `true` when an adventure
/// was actually added (so the caller can refresh its grid/sections); `false` on
/// cancel, an invalid file, or a declined overwrite.
Future<bool> importLsToLibraryTile(
  BuildContext context, {
  required ProjectsStore store,
}) async {
  final path = await FilePickerService.instance.pickLs();
  if (path == null) return false;
  var status = await store.importLsToLibrary(path);
  if (!context.mounted) return false;

  // Already in the library -> the SAME Overwrite/Cancel dialog as Export.
  if (status == LibraryImportStatus.duplicate) {
    final choice = await showLibraryDuplicateDialog(context);
    if (choice != true) return false; // Cancel -> nothing changes.
    status = await store.importLsToLibrary(path, overwrite: true);
    if (!context.mounted) return false;
  }

  final l10n = AppLocalizations.of(context);
  final (String message, String key) = switch (status) {
    LibraryImportStatus.added => (l10n.libraryImportDone, 'library.import.done'),
    LibraryImportStatus.duplicate => (
        l10n.libraryImportDuplicate,
        'library.import.duplicate'
      ),
    LibraryImportStatus.invalid => (
        l10n.libraryImportInvalid,
        'library.import.invalid'
      ),
  };
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message, key: ValueKey(key))));
  return status == LibraryImportStatus.added;
}

/// Adventures tile: open the read-only info window; its Play button opens the
/// adventure launch screen (new game).
Future<void> showAdventureInfoTile(
  BuildContext context, {
  required ProjectsStore store,
  required AdventureSummary adventure,
  VoidCallback? onHome,
  ValueChanged<int>? onNavigate,
}) async {
  final play = await showAdventureInfoDialog(context, adventure);
  if (play != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdventureLaunchScreen(
          adventure: adventure,
          store: store,
          onHome: onHome,
          onNavigate: onNavigate),
    ),
  );
}

/// Saves tile: RESUME the in-progress playthrough (the launch screen in resume
/// mode, continuing at the save's last visited scene).
Future<void> resumeSaveTile(
  BuildContext context, {
  required ProjectsStore store,
  required AdventureSummary save,
  VoidCallback? onHome,
  ValueChanged<int>? onNavigate,
  ValueChanged<String>? onEditSave,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdventureLaunchScreen(
        adventure: save,
        store: store,
        onHome: onHome,
        onNavigate: onNavigate,
        onEditSave: onEditSave,
        resumeSaveName: save.slug,
      ),
    ),
  );
}
