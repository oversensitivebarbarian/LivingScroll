import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';

/// One cell of the Create grid.
///
/// Two states, by [AdventureSummary.valid]:
///   * VALID — the adventure cover fills the tile, with a circular context menu
///     (Clone / Delete) pinned top-right; tapping opens the adventure.
///   * INVALID (`LivingScroll.json` not schema-valid, or an unsupported system) —
///     a greyed, non-interactive tile (no open, no context menu) with a centered
///     Block glyph on the same circular `secondaryContainer` backdrop the
///     context menu uses. Opening such an adventure would throw, so the tile
///     surfaces the problem instead of being openable.
///
/// Keys are parameterised by the adventure slug so every tile is unique.
class AdventureTile extends StatelessWidget {
  const AdventureTile({
    super.key,
    required this.adventure,
    required this.onOpen,
    this.onClone,
    this.onDelete,
    this.onEdit,
    this.onExportLatex,
    this.cloneLabel,
    this.editLabel,
    this.exportLatexLabel,
    this.deleteAsButton = false,
  });

  final AdventureSummary adventure;
  final VoidCallback onOpen;

  /// When non-null (the Saves tile), the tile's corner button opens an
  /// **Edit / Delete** dialog instead of deleting directly: Edit runs
  /// [onEdit] (open the save in the game editor), Delete runs [onDelete]. Takes
  /// precedence over [deleteAsButton] / the context menu.
  final VoidCallback? onEdit;

  /// Label of the dialog's Edit button (defaults to the localized "Edit").
  final String? editLabel;

  /// Clone / Delete actions. When BOTH are null (and [onExportLatex] too) the tile
  /// is browse-only: no context menu (and the invalid tile shows no delete
  /// button). The Library's read-only grids pass null; the Create grid passes both.
  final VoidCallback? onClone;
  final VoidCallback? onDelete;

  /// An extra context-menu action (Library Adventures grid: "Export to LaTeX").
  /// When non-null it adds a menu item BETWEEN Clone and Delete.
  final VoidCallback? onExportLatex;

  /// Label of the [onClone] menu item. Defaults to "Clone" (the Create grid); the
  /// Library Adventures grid passes "Copy as project".
  final String? cloneLabel;

  /// Label of the [onExportLatex] menu item (Library Adventures grid).
  final String? exportLatexLabel;

  /// When true, [onDelete] is surfaced as a DIRECT inset delete button (the same
  /// round close button as the Notes tile) instead of a context-menu item — used
  /// by the Library Projects grid. Ignored when [onClone] is also set.
  final bool deleteAsButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final slug = adventure.slug;
    if (!adventure.valid) return _invalid(scheme, slug);
    return AspectRatio(
      aspectRatio: 1 / 1.43,
      child: InkWell(
        key: ValueKey('adventure.tile.$slug'),
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (adventure.cover != null)
              Image.file(adventure.cover!, fit: BoxFit.cover)
            else
              ColoredBox(color: scheme.surfaceContainerHighest),
            // Saves tile: a corner button opening an Edit / Delete dialog —
            // takes precedence over the direct delete button and the menu.
            if (onEdit != null)
              _actionsButton(context, scheme, slug, l10n)
            // A DIRECT inset delete button (Projects grid) — same round close
            // button as the Notes tile; takes precedence over the menu.
            else if (deleteAsButton && onClone == null && onDelete != null)
              _deleteButton(scheme, slug)
            // Otherwise a context menu (Clone / Copy as project, Export to LaTeX,
            // Delete).
            else if (onClone != null ||
                onDelete != null ||
                onExportLatex != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondaryContainer,
                  ),
                  child: PopupMenuButton<String>(
                    key: ValueKey('adventure.tile.menu.$slug'),
                    icon: Icon(
                      Icons.more_vert,
                      color: scheme.onSecondaryContainer,
                    ),
                    onSelected: (value) {
                      if (value == 'clone') onClone?.call();
                      if (value == 'latex') onExportLatex?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (onClone != null)
                        PopupMenuItem<String>(
                          key: ValueKey('adventure.tile.menu.$slug.item.clone'),
                          value: 'clone',
                          child: Text(cloneLabel ?? l10n.adventureClone),
                        ),
                      if (onExportLatex != null)
                        PopupMenuItem<String>(
                          key: ValueKey('adventure.tile.menu.$slug.item.latex'),
                          value: 'latex',
                          child: Text(
                            exportLatexLabel ?? l10n.libraryExportLatex,
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem<String>(
                          key: ValueKey(
                            'adventure.tile.menu.$slug.item.delete',
                          ),
                          value: 'delete',
                          child: Text(l10n.adventureDelete),
                        ),
                    ],
                  ),
                ),
              ),
            // Save tiles carry the playthrough's group as a bottom overlay;
            // Finished tiles add the completion date under it.
            if (adventure.group.isNotEmpty || adventure.finishedAt != null)
              _metaOverlay(context, scheme, slug),
          ],
        ),
      ),
    );
  }

  /// The bottom overlay band (Save/Finished tiles). A translucent
  /// `secondaryContainer` band across the tile's lower edge with the playthrough's
  /// group and — for a finished session — the completion date below it, in
  /// `onSecondaryContainer` so they stay legible over a cover image or a flat tile
  /// alike. The date is formatted with the system locale's short date pattern
  /// ([MaterialLocalizations.formatShortDate], numeric and year-bearing).
  Widget _metaOverlay(BuildContext context, ColorScheme scheme, String slug) {
    final hasGroup = adventure.group.isNotEmpty;
    final hasDate = adventure.finishedAt != null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: scheme.secondaryContainer.withValues(alpha: 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasGroup)
              _overlayLine(
                scheme,
                Icons.group_outlined,
                adventure.group,
                ValueKey('adventure.tile.$slug.group'),
              ),
            if (hasGroup && hasDate) const SizedBox(height: 4),
            if (hasDate)
              _overlayLine(
                scheme,
                Icons.event_available_outlined,
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(adventure.finishedAt!),
                ValueKey('adventure.tile.$slug.finished'),
              ),
          ],
        ),
      ),
    );
  }

  /// One overlay line: a small leading icon + a single, ellipsised label keyed
  /// for tests.
  Widget _overlayLine(
    ColorScheme scheme,
    IconData icon,
    String text,
    Key key,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: scheme.onSecondaryContainer),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          key: key,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  /// The inset round delete button (top-right) — the SAME round close button as
  /// the Notes tile: a `onSecondaryContainer` disc behind a `secondaryContainer`
  /// close glyph. Keyed `adventure.tile.<slug>.delete`.
  Widget _deleteButton(ColorScheme scheme, String slug) => Positioned(
    top: 8,
    right: 8,
    child: SizedBox(
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.onSecondaryContainer,
        ),
        child: IconButton(
          key: ValueKey('adventure.tile.$slug.delete'),
          icon: Icon(Icons.close, color: scheme.secondaryContainer),
          onPressed: onDelete,
        ),
      ),
    ),
  );

  /// The Saves tile's corner button — the SAME round disc as the delete button
  /// but with a `more_vert` glyph; opens the Edit / Delete dialog. Keyed
  /// `adventure.tile.<slug>.actions`.
  Widget _actionsButton(
    BuildContext context,
    ColorScheme scheme,
    String slug,
    AppLocalizations l10n,
  ) => Positioned(
    top: 8,
    right: 8,
    child: SizedBox(
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.onSecondaryContainer,
        ),
        child: IconButton(
          key: ValueKey('adventure.tile.$slug.actions'),
          icon: Icon(Icons.more_vert, color: scheme.secondaryContainer),
          onPressed: () => _showSaveActions(context, slug, l10n),
        ),
      ),
    ),
  );

  /// The Edit / Delete dialog raised by the Saves tile's corner button.
  Future<void> _showSaveActions(
    BuildContext context,
    String slug,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: ValueKey('library.save.actions.dialog'),
        title: Text(adventure.name),
        actions: [
          TextButton(
            key: const ValueKey('library.save.actions.cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.unsavedCancel),
          ),
          TextButton(
            key: const ValueKey('library.save.actions.delete'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onDelete?.call();
            },
            child: Text(l10n.adventureDelete),
          ),
          FilledButton(
            key: const ValueKey('library.save.actions.edit'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onEdit?.call();
            },
            child: Text(editLabel ?? l10n.librarySaveEdit),
          ),
        ],
      ),
    );
  }

  /// The invalid state: the adventure cover is kept as the background (so the
  /// tile stays recognisable) under a greyed
  /// scrim that reads as disabled; on top sits a centered Block glyph on the
  /// same circular `secondaryContainer` backdrop as the context menu. It keeps
  /// the `adventure.tile.$slug` key (still findable; no open tap, no context
  /// menu) and carries the standard tile delete button top-right — the SAME
  /// treatment as every other tile (a round `onSecondaryContainer` backdrop
  /// behind a `secondaryContainer` Close glyph) — so a broken adventure can
  /// still be deleted.
  Widget _invalid(ColorScheme scheme, String slug) {
    return AspectRatio(
      key: ValueKey('adventure.tile.$slug'),
      aspectRatio: 1 / 1.43,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The cover stays as the background; a greyed scrim dims it so the
          // tile reads as disabled. No cover -> a plain greyed box.
          if (adventure.cover != null) ...[
            Image.file(adventure.cover!, fit: BoxFit.cover),
            ColoredBox(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
            ),
          ] else
            ColoredBox(color: scheme.surfaceContainerHighest),
          Center(
            child: Container(
              key: ValueKey('adventure.tile.$slug.block'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondaryContainer,
              ),
              child: Icon(Icons.block, color: scheme.onSecondaryContainer),
            ),
          ),
          // Delete — identical to the other tiles' delete button. Omitted in
          // browse-only grids (no delete action).
          if (onDelete != null) _deleteButton(scheme, slug),
        ],
      ),
    );
  }
}
