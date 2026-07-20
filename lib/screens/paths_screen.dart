import 'package:flutter/material.dart';

import '../paths/path_colors.dart';
import '../paths/paths_controller.dart';
import '../widgets/path_tile.dart';
import 'paths_edit_screen.dart';

// Re-export so existing imports of `pathColors` via this screen keep working.
export '../paths/path_colors.dart';

/// The in-game Paths section. Shows a vertical list with
/// one [PathTile] row per path colour; tapping a row opens the path edit form
/// in place. Save returns to the list.
///
/// State lives on the shared [PathsController] (owned by the game shell) so the
/// shell's navigation guard can read [PathsController.isDirty].
class PathsScreen extends StatelessWidget {
  const PathsScreen({
    super.key,
    required this.controller,
    required this.onSave,
    this.readOnly = false,
  });

  final PathsController controller;

  /// Persists the edited path (commit + write to LivingScroll.json) and returns
  /// to the grid. Provided by the game shell.
  final Future<void> Function() onSave;

  /// Save-content editing: the Paths section is read-only —
  /// the six colours are a fixed set (no add) and existing paths are immutable,
  /// so a frozen path does not open the edit form (a lock badge is shown).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final editingId = controller.editingId;
        if (editingId != null) {
          final color = pathColors.firstWhere((c) => c.id == editingId);
          return PathsEditScreen(
            controller: controller,
            color: color,
            onSave: onSave,
          );
        }
        return ListView.separated(
          key: const ValueKey('game.paths.list'),
          padding: const EdgeInsets.all(24),
          itemCount: pathColors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final c = pathColors[index];
            return PathTile(
              colorId: c.id,
              color: c.color,
              name: controller.name(c.id),
              onTap: () => controller.beginEdit(c.id),
              // The whole Paths section is read-only in save-edit (fixed colour
              // set, existing paths immutable) — lock every slot.
              locked: readOnly,
            );
          },
        );
      },
    );
  }
}
