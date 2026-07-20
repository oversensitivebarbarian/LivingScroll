import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The user's decision when leaving a dirty screen: Save, Abandon, Cancel.
enum UnsavedChoice { save, abandon, cancel }

/// Shows the unsaved-changes prompt that guards navigation away from a screen
/// with pending edits. Returns the chosen [UnsavedChoice], or `null` if the
/// dialog was dismissed (barrier tap) — callers treat `null` as [cancel].
Future<UnsavedChoice?> showUnsavedChangesDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<UnsavedChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('settings.unsaved.dialog'),
      title: Text(l10n.unsavedTitle),
      content: Text(l10n.unsavedMessage),
      actions: [
        // Cancel is the least-destructive default, placed first (leading).
        TextButton(
          key: const ValueKey('settings.unsaved.cancel'),
          onPressed: () => Navigator.of(context).pop(UnsavedChoice.cancel),
          child: Text(l10n.unsavedCancel),
        ),
        TextButton(
          key: const ValueKey('settings.unsaved.abandon'),
          onPressed: () => Navigator.of(context).pop(UnsavedChoice.abandon),
          child: Text(l10n.unsavedAbandon),
        ),
        FilledButton(
          key: const ValueKey('settings.unsaved.save'),
          onPressed: () => Navigator.of(context).pop(UnsavedChoice.save),
          child: Text(l10n.settingsSave),
        ),
      ],
    ),
  );
}

/// Two-option discard prompt for screens whose only way to persist is an
/// explicit action (the new-adventure form: Create). There is no "Save" here —
/// just Abandon (leave, nothing created) or Cancel (stay). Returns `true` when
/// the user chose Abandon.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final abandon = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('create_new.unsaved.dialog'),
      title: Text(l10n.unsavedTitle),
      content: Text(l10n.unsavedMessage),
      actions: [
        TextButton(
          key: const ValueKey('create_new.unsaved.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('create_new.unsaved.abandon'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.unsavedAbandon),
        ),
      ],
    ),
  );
  return abandon ?? false;
}
