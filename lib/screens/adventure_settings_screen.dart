import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../create/adventure_settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/supported_languages.dart';
import '../services/adventure_importer.dart';
import '../services/adventure_packager.dart';
import '../services/file_picker_service.dart';
import '../services/living_scroll_validator.dart';
import '../widgets/cover_picker.dart';
import 'cover_crop_dialog.dart';
import '../create/game_systems.dart';
import 'import_selection_dialog.dart';

/// The Adventure settings form: the same two-column layout as the
/// new-adventure form (cover on the left, metadata + actions on the right),
/// but editing an EXISTING adventure. Bound to a loaded
/// [AdventureSettingsController]; Save persists via [onSave].
///
/// State lives on the shared controller (owned by the game shell) so the shell's
/// navigation guard can read [AdventureSettingsController.isDirty].
class AdventureSettingsScreen extends StatefulWidget {
  const AdventureSettingsScreen({
    super.key,
    required this.controller,
    required this.onSave,
    this.onImport,
    this.loadTargetDoc,
    this.existingCover,
    this.readOnly = false,
  });

  final AdventureSettingsController controller;

  /// Save-content editing: the adventure identity is frozen — the form is
  /// read-only (fields/cover non-editable, Save + Import disabled).
  final bool readOnly;

  /// The adventure's current cover on disk, shown until a new one is staged.
  final File? existingCover;

  /// Persists the form (write LivingScroll.json + cover.jpg) and leaves the
  /// section. Enabled only while the required fields are valid.
  final Future<void> Function() onSave;

  /// Imports the chosen [selection] of individual elements (category → selected
  /// element ids) from the decoded import document [importDoc] (whose media is
  /// under [sourceDir]) into the adventure, then refreshes it. [sameSystem] is
  /// whether the import targets this adventure's system. Provided by the game
  /// shell (it owns the store + reload).
  final Future<void> Function(
    String sourceDir,
    Map<String, dynamic> importDoc,
    Map<String, Set<String>> selection,
    bool sameSystem,
  )?
  onImport;

  /// Loads the CURRENT adventure's full `LivingScroll.json` so the import can
  /// pre-filter out elements (by uuid) already present in it. Provided by the
  /// game shell (it owns the store + slug).
  final Future<Map<String, dynamic>?> Function()? loadTargetDoc;

  @override
  State<AdventureSettingsScreen> createState() =>
      _AdventureSettingsScreenState();
}

class _AdventureSettingsScreenState extends State<AdventureSettingsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _version;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _contentWarnings;
  late final TextEditingController _license;

  bool _importInvalid = false;

  AdventureSettingsController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _model.title);
    _version = TextEditingController(text: _model.version);
    _author = TextEditingController(text: _model.author);
    _description = TextEditingController(text: _model.description);
    _contentWarnings = TextEditingController(text: _model.contentWarnings);
    _license = TextEditingController(text: _model.license);
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _title.dispose();
    _version.dispose();
    _author.dispose();
    _description.dispose();
    _contentWarnings.dispose();
    _license.dispose();
    super.dispose();
  }

  // Keep the text fields in sync when the model changes outside of typing
  // (Abandon restores the baseline), and rebuild so Save enablement tracks the
  // required fields.
  void _onModelChanged() {
    void sync(TextEditingController c, String v) {
      if (c.text != v) c.value = TextEditingValue(text: v);
    }

    sync(_title, _model.title);
    sync(_version, _model.version);
    sync(_author, _model.author);
    sync(_description, _model.description);
    sync(_contentWarnings, _model.contentWarnings);
    sync(_license, _model.license);
    setState(() {});
  }

  Future<void> _pickCover() async {
    final path = await FilePickerService.instance.pickImage();
    if (path == null || !mounted) return;
    // Crop step: locked to 1:1.43. Cancelling stages nothing.
    final crop = await showCoverCropDialog(context, path);
    if (crop == null) return;
    _model.setField(() {
      _model.coverSourcePath = path;
      _model.coverCrop = crop;
    });
  }

  Future<void> _import() async {
    // The Import picker accepts a portable adventure archive — a `.ls` (full
    // export) or `.lse` (elements export). It is unpacked into a temp working
    // directory so its LivingScroll.json and media can be read for the merge.
    final path = await FilePickerService.instance.pickArchive();
    if (path == null) return;

    final workDir = await Directory.systemTemp.createTemp('ls_import_');
    try {
      Object? decoded;
      try {
        const AdventurePackager().unpack(
          bytes: await File(path).readAsBytes(),
          dest: workDir,
        );
        decoded = jsonDecode(
          await File('${workDir.path}/LivingScroll.json').readAsString(),
        );
      } catch (_) {
        decoded = null;
      }
      // Validate the LivingScroll.json BEFORE accepting. The
      // level depends on the archive kind: a
      // `.ls` is a finished, shippable adventure -> PUBLISHED (the full metadata
      // set must be present); a `.lse` is a partial elements pack -> PROJECT
      // (only name + system are required, mirroring the lenient export gate).
      final LivingScrollValidator validator =
          path.toLowerCase().endsWith('.lse')
          ? const ProjectValidator()
          : const PublishedAdventureValidator();
      final valid =
          decoded is Map<String, dynamic> && validator.isValid(decoded);
      if (!valid) {
        if (mounted) setState(() => _importInvalid = true);
        return;
      }
      if (mounted) setState(() => _importInvalid = false);

      final importDoc = decoded;
      // Analyze against the CURRENT adventure: its system gates NPCs and its
      // existing uuids pre-filter elements already present from the list.
      final targetDoc =
          (await widget.loadTargetDoc?.call()) ??
          {
            'metadata': {'system': _model.system ?? ''},
          };
      if (!mounted) return;
      final analysis = const AdventureImporter().analyze(importDoc, targetDoc);
      if (!mounted) return;
      final selection = await showImportSelectionDialog(context, analysis);
      if (selection == null || selection.values.every((s) => s.isEmpty)) return;

      // The unpacked archive holds the import file's media (images/, audio/).
      await widget.onImport?.call(
        workDir.path,
        importDoc,
        selection,
        analysis.sameSystem,
      );
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      // The cover + fields SCROLL; the action buttons stay pinned below, so the
      // form is safe at the minimum window in EITHER orientation and the
      // buttons stay reachable.
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Save-content editing freezes the adventure identity: block all
              // field/cover/dropdown interaction (scrolling still works — the
              // Scrollable sits above this IgnorePointer).
              child: IgnorePointer(
                ignoring: widget.readOnly,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COVER — fixed display size that scales DOWN on a narrow window
                    // (FittedBox), left-aligned.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 300,
                        child: AspectRatio(
                          aspectRatio: 1 / 1.43,
                          child: CoverPickerField(
                            key: const ValueKey('game.settings.cover'),
                            source: _model.coverSourcePath,
                            crop: _model.coverCrop,
                            existingCover: widget.existingCover,
                            label: l10n.createNewCoverLabel,
                            onTap: _pickCover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _field(
                      _title,
                      l10n.createNewTitleLabel,
                      keyId: 'game.settings.field.title',
                      onChanged: (v) => _model.setField(() => _model.title = v),
                    ),
                    _field(
                      _version,
                      l10n.createNewVersionLabel,
                      keyId: 'game.settings.field.version',
                      onChanged: (v) =>
                          _model.setField(() => _model.version = v),
                    ),
                    _systemDropdown(l10n),
                    _field(
                      _author,
                      l10n.createNewAuthorLabel,
                      keyId: 'game.settings.field.author',
                      onChanged: (v) =>
                          _model.setField(() => _model.author = v),
                    ),
                    _field(
                      _description,
                      l10n.createNewDescriptionLabel,
                      keyId: 'game.settings.field.description',
                      maxLines: 3,
                      onChanged: (v) =>
                          _model.setField(() => _model.description = v),
                    ),
                    _languageDropdown(l10n),
                    _field(
                      _contentWarnings,
                      l10n.createNewContentWarningsLabel,
                      keyId: 'game.settings.field.content_warnings',
                      onChanged: (v) =>
                          _model.setField(() => _model.contentWarnings = v),
                    ),
                    _field(
                      _license,
                      l10n.createNewLicenseLabel,
                      keyId: 'game.settings.field.license',
                      onChanged: (v) =>
                          _model.setField(() => _model.license = v),
                    ),
                    if (_importInvalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.createNewImportInvalid,
                          key: const ValueKey('game.settings.import.error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Wrap so the two buttons reflow to a second line on a narrow window
          // instead of overflowing; pinned below the scroll so they stay reachable.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('game.settings.import'),
                onPressed: widget.readOnly ? null : _import,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.createNewImport),
              ),
              FilledButton(
                key: const ValueKey('game.settings.save'),
                onPressed: (widget.readOnly || !_model.canSave)
                    ? null
                    : widget.onSave,
                child: Text(l10n.settingsSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String keyId,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey(keyId),
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // Language is a dropdown over the app's supported languages (stored as an ISO
  // code in metadata.language). It is OPTIONAL — a leading "not specified" item
  // (value "") keeps it clearable. A legacy free-text value (from before the
  // dropdown) that maps to no known language is kept as its own item so editing
  // an old adventure never silently drops its language. Uses initialValue so the
  // shown value re-syncs when the model changes externally (Abandon/discard).
  Widget _languageDropdown(AppLocalizations l10n) {
    final current = _model.language;
    final code = SupportedLanguages.codeFor(current);
    final unknownLegacy = code == null && current.trim().isNotEmpty;
    final value = code ?? (unknownLegacy ? current : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('game.settings.field.language'),
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: l10n.createNewLanguageLabel,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String>(
            key: const ValueKey('game.settings.field.language.item.unset'),
            value: '',
            child: Text(l10n.createNewLanguageUnset),
          ),
          if (unknownLegacy)
            DropdownMenuItem<String>(
              key: const ValueKey('game.settings.field.language.item.legacy'),
              value: current,
              child: Text(current),
            ),
          for (final entry in SupportedLanguages.names.entries)
            DropdownMenuItem<String>(
              key: ValueKey('game.settings.field.language.item.${entry.key}'),
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        onChanged: (v) => _model.setField(() => _model.language = v ?? ''),
      ),
    );
  }

  // metadata.system is IMMUTABLE after creation: the field is pre-filled with
  // the adventure's system and disabled (onChanged == null), so it shows
  // greyed out and cannot be opened or changed. `disabledHint` renders the
  // current system's display name (a disabled DropdownButton drops its items,
  // so the value must be shown here).
  Widget _systemDropdown(AppLocalizations l10n) {
    final current = _model.system;
    // Full name map (incl. any non-selectable system) so an existing
    // adventure of any supported system still shows its name here.
    final currentLabel = current == null ? null : GameSystems.allNames[current];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        key: const ValueKey('game.settings.field.system'),
        isExpanded: true,
        initialValue: current,
        decoration: InputDecoration(
          labelText: l10n.createNewSystemLabel,
          border: const OutlineInputBorder(),
          // Greys the label + border to read as a disabled field.
          enabled: false,
        ),
        hint: Text(l10n.createNewSystemHint),
        disabledHint: currentLabel == null ? null : Text(currentLabel),
        items: [
          for (final entry in GameSystems.allNames.entries)
            DropdownMenuItem<String?>(
              key: ValueKey('game.settings.field.system.item.${entry.key}'),
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        // null -> the dropdown is disabled; the system can never be changed.
        onChanged: null,
      ),
    );
  }
}
