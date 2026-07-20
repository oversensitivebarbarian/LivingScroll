import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/supported_languages.dart';
import '../settings/settings_edit_controller.dart';
import '../settings/settings_scope.dart';

/// Settings destination: language + display-mode overrides with an explicit
/// Save. Selecting a control marks the screen dirty (tracked on the shared
/// [SettingsEditController]); the override reaches overrides.json only on
/// Save (or via the unsaved-changes prompt when navigating away).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  /// Pending-edits/dirty state, shared with the shell's navigation guard.
  final SettingsEditController controller;

  /// Supported UI languages (ISO code -> endonym shown in the dropdown). Shared
  /// single source of truth with the adventure content-language dropdown.
  static const Map<String, String> _languageNames = SupportedLanguages.names;

  Future<void> _save(SettingsScope scope) async {
    await scope.onChanged(controller.pending);
    controller.markSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = SettingsScope.of(context);
    final packageInfo = PackageInfo.fromPlatform();

    return Padding(
      padding: const EdgeInsets.all(24),
      // Rebuild on every pending-edit change so the controls and the Save
      // button (enabled only when dirty) stay in sync with the controller.
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // Scrolls so the Build section never overflows the app's enforced
          // 640×480 minimum window floor. SingleChildScrollView sizes its
          // child to CONTENT height (not the viewport), so a short Column
          // would otherwise leave the whole scroll view shorter than the
          // shell Row's height and get vertically centered by it; the
          // LayoutBuilder + ConstrainedBox pins content to the top by forcing
          // at least the full available height, like every other rail
          // destination.
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsLanguageLabel),
                      const SizedBox(height: 8),
                      DropdownButton<String?>(
                        key: const ValueKey('settings.language'),
                        value: controller.lang,
                        items: [
                          DropdownMenuItem<String?>(
                            key: const ValueKey(
                              'settings.language.item.system',
                            ),
                            value: null,
                            child: Text(l10n.settingsLanguageSystemDefault),
                          ),
                          // Language names stay as endonyms (each shown in its own
                          // language), the convention for language pickers.
                          for (final entry in _languageNames.entries)
                            DropdownMenuItem<String?>(
                              key: ValueKey(
                                'settings.language.item.${entry.key}',
                              ),
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: controller.setLang,
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.settingsDisplayModeLabel),
                      RadioGroup<String?>(
                        groupValue: controller.mode,
                        onChanged: controller.setMode,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String?>(
                              key: const ValueKey('settings.mode.light'),
                              title: Text(l10n.settingsModeLight),
                              value: 'light',
                            ),
                            RadioListTile<String?>(
                              key: const ValueKey('settings.mode.dark'),
                              title: Text(l10n.settingsModeDark),
                              value: 'dark',
                            ),
                            RadioListTile<String?>(
                              key: const ValueKey('settings.mode.auto'),
                              title: Text(l10n.settingsModeAuto),
                              value: null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.settingsMusicLabel),
                      SwitchListTile(
                        key: const ValueKey('settings.music.autoplay'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsAutoplayLabel),
                        value: controller.autoplayOn,
                        onChanged: controller.setAutoplay,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const ValueKey('settings.save'),
                        onPressed: controller.isDirty
                            ? () => _save(scope)
                            : null,
                        child: Text(l10n.settingsSave),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.settingsBuildSectionLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<PackageInfo>(
                        future: packageInfo,
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.settingsVersionLabel}: ${info?.version ?? ''}',
                                key: const ValueKey('settings.build.version'),
                              ),
                              Text(
                                '${l10n.settingsBuildNumberLabel}: ${info?.buildNumber ?? ''}',
                                key: const ValueKey('settings.build.number'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
