import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/adventure_importer.dart';

/// Shows the import selection dialog: a scrollable list of every IMPORTABLE
/// element ([ImportAnalysis] already dropped elements already in the target and
/// system-incompatible NPCs), grouped by type (a header per category), each
/// element carrying its own checkbox. When nothing is importable it shows the
/// empty-state note instead. Returns the per-element selection (category → set
/// of element ids) when the user taps Import, or `null` when they cancel.
Future<Map<String, Set<String>>?> showImportSelectionDialog(
  BuildContext context,
  ImportAnalysis analysis,
) {
  return showDialog<Map<String, Set<String>>>(
    context: context,
    builder: (_) => _ImportSelectionDialog(analysis: analysis),
  );
}

class _ImportSelectionDialog extends StatefulWidget {
  const _ImportSelectionDialog({required this.analysis});

  final ImportAnalysis analysis;

  @override
  State<_ImportSelectionDialog> createState() => _ImportSelectionDialogState();
}

class _ImportSelectionDialogState extends State<_ImportSelectionDialog> {
  // category -> selected element ids. Seeded from the default (all selectable).
  late final Map<String, Set<String>> _selected = {
    for (final e in widget.analysis.defaultSelection.entries) e.key: {...e.value},
  };

  int get _count => _selected.values.fold(0, (n, s) => n + s.length);

  void _toggle(String category, String id, bool on) {
    setState(() {
      final set = _selected.putIfAbsent(category, () => <String>{});
      if (on) {
        set.add(id);
      } else {
        set.remove(id);
      }
    });
  }

  String _groupLabel(AppLocalizations l, String category) {
    switch (category) {
      case 'npcs':
        return l.gameNpcs;
      case 'key_events':
        return l.gameKeyEvents;
      case 'notes':
        return l.gameNotes;
      case 'gm_notes':
        return l.gameGmNotes;
      case 'images':
        return l.gameImages;
      case 'audio':
        return l.gameSoundtracks;
      case 'paths':
        return l.gamePaths;
      case 'scenes':
        return l.gameScenes;
    }
    return category;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final a = widget.analysis;

    return AlertDialog(
      key: const ValueKey('import.dialog'),
      title: Text(l10n.importSelectTitle),
      content: SizedBox(
        width: 380,
        // Nothing importable -> the empty-state note; otherwise the element list.
        child: a.isEmpty
            ? Text(
                l10n.importNothing,
                key: const ValueKey('import.dialog.empty'),
              )
            : SizedBox(
                height: 420,
                child: ListView(
                  key: const ValueKey('import.dialog.list'),
                  children: [
                    for (final c in a.present) ...[
                      // Type header (group title + count).
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 2),
                        child: Text(
                          '${_groupLabel(l10n, c)}  (${a.counts[c]})',
                          key: ValueKey('import.dialog.group.$c'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      // One checkbox per individual importable element.
                      for (final it in a.items[c]!)
                        CheckboxListTile(
                          key: ValueKey('import.dialog.item.$c.${it.id}'),
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 16),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(it.label),
                          value: _selected[c]?.contains(it.id) ?? false,
                          onChanged: (v) => _toggle(c, it.id, v == true),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('import.dialog.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.unsavedCancel),
        ),
        // No Import button when there is nothing to import.
        if (!a.isEmpty)
          FilledButton(
            key: const ValueKey('import.dialog.import'),
            // Nothing selected -> Import is a no-op; disable it.
            onPressed: _count == 0
                ? null
                : () => Navigator.of(context).pop(<String, Set<String>>{
                      for (final e in _selected.entries)
                        if (e.value.isNotEmpty) e.key: e.value,
                    }),
            child: Text(l10n.importConfirm),
          ),
      ],
    );
  }
}
