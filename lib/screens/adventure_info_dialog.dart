import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';

/// The Library Adventures info window — opened by tapping an Adventures tile.
/// Mirrors the create-mode Adventure settings layout: the cover on the left,
/// read-only metadata on the right (Title, then the version on its own line
/// below, System, Author, Description), and a Close / Play actions row at the
/// bottom.
///
/// Returns `true` when Play was pressed, `null`/`false` when dismissed. (What
/// Play does is wired by the caller.)
Future<bool?> showAdventureInfoDialog(
  BuildContext context,
  AdventureSummary adventure,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AdventureInfoDialog(adventure: adventure),
  );
}

class _AdventureInfoDialog extends StatelessWidget {
  const _AdventureInfoDialog({required this.adventure});

  final AdventureSummary adventure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Padding(
          key: const ValueKey('library.adventure.info'),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT — the cover, same 1:1.43 proportions as the settings form.
                    AspectRatio(
                      aspectRatio: 1 / 1.43,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: adventure.cover != null
                            ? Image.file(
                                adventure.cover!,
                                key: const ValueKey(
                                  'library.adventure.info.cover',
                                ),
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                key: const ValueKey(
                                  'library.adventure.info.cover',
                                ),
                                color: scheme.surfaceContainerHighest,
                              ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // RIGHT — read-only metadata.
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adventure.name,
                              key: const ValueKey(
                                'library.adventure.info.title',
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            // Version on its OWN line under the title, in a
                            // smaller font, prefixed with the localized label.
                            if (adventure.version.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.createNewVersionLabel}: '
                                '${adventure.version}',
                                key: const ValueKey(
                                  'library.adventure.info.version',
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _field(
                              context,
                              l10n.createNewSystemLabel,
                              adventure.system,
                              'library.adventure.info.system',
                            ),
                            const SizedBox(height: 12),
                            _field(
                              context,
                              l10n.createNewAuthorLabel,
                              adventure.author,
                              'library.adventure.info.author',
                            ),
                            const SizedBox(height: 12),
                            _field(
                              context,
                              l10n.createNewDescriptionLabel,
                              adventure.description,
                              'library.adventure.info.description',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Actions — Close then Play (convention: secondary then primary).
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: const ValueKey('library.adventure.info.close'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.dialogClose),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const ValueKey('library.adventure.info.play'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.libraryAdventurePlay),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A read-only labelled value row (a small caption over the value).
  Widget _field(
    BuildContext context,
    String label,
    String value,
    String keyId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value, key: ValueKey(keyId)),
      ],
    );
  }
}
