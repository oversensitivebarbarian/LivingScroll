import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The "already in the Adventures library" prompt, shared by the game-view Export
/// and the Library Adventures import. Returns `true` to Overwrite the existing
/// library copy, `false`/`null` to Cancel.
Future<bool?> showLibraryDuplicateDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      key: const ValueKey('library.duplicate.dialog'),
      title: Text(l10n.libraryDuplicateTitle),
      content: Text(l10n.libraryDuplicateMessage),
      actions: [
        TextButton(
          key: const ValueKey('library.duplicate.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('library.duplicate.overwrite'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.libraryOverwrite),
        ),
      ],
    ),
  );
}
