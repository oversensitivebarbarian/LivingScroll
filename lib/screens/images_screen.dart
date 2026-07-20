import 'dart:io';

import 'package:flutter/material.dart';

import '../images/adventure_image.dart';
import '../images/images_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/image_tile.dart';
import 'image_form_screen.dart';

/// The in-game Images section: the adventure's "all photos" grid. Cell 0 is
/// an empty "+" tile that opens the add form (a required
/// image picker + a visibility gate); the remaining cells are one [ImageTile] per
/// `images[]` entry, square and sized to the Adventure tile's shorter side. A
/// tile's top-right delete button confirms before removing the image (and its
/// file).
///
/// State lives on the shared [ImagesController] (owned by the game shell);
/// [onCommit] writes the staged image + appends the entry (the form's Add and the
/// rail guard's Save), [onDelete] removes one.
class ImagesScreen extends StatelessWidget {
  const ImagesScreen({
    super.key,
    required this.controller,
    required this.imagesBasePath,
    required this.onCommit,
    required this.onDelete,
    this.readOnly = false,
  });

  /// Save-content editing: immutable base images are frozen (no open, no
  /// delete); new images stay editable.
  final bool readOnly;

  final ImagesController controller;

  /// Absolute path to the adventure's `images/other/` dir (`<basePath>/<uuid>.png`).
  final String imagesBasePath;

  final Future<void> Function() onCommit;
  final Future<void> Function(AdventureImage image) onDelete;

  Future<void> _confirmDelete(
    BuildContext context,
    AdventureImage image,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('image.delete.dialog'),
        content: Text(l10n.imagesDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('image.delete.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('image.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.imagesDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete(image);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEditing) {
          return ImageFormScreen(
            controller: controller,
            imagesBasePath: imagesBasePath,
            onCommit: onCommit,
            onCancel: controller.cancelEdit,
          );
        }
        return _grid(context);
      },
    );
  }

  Widget _grid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final images = controller.images;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        key: const ValueKey('image.grid'),
        // Square cells whose width matches the Adventure tile's shorter side
        // (the Create grid uses maxCrossAxisExtent 220).
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: images.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // The empty "+" tile — opens the add form.
            return Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('image.new'),
                onTap: controller.beginNew,
                child: Tooltip(
                  message: l10n.imagesAddTooltip,
                  child: Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }
          final image = images[index - 1];
          return ImageTile(
            uuid: image.uuid,
            file: File('$imagesBasePath/${image.uuid}.png'),
            onTap: () => controller.beginEdit(image.uuid),
            onDelete: () => _confirmDelete(context, image),
            locked: readOnly && image.immutable,
          );
        },
      ),
    );
  }
}
