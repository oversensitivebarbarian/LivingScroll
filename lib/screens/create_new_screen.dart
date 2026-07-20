import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../create/create_new_controller.dart';
import '../create/game_systems.dart';
import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../l10n/supported_languages.dart';
import '../services/adventure_importer.dart';
import '../services/adventure_packager.dart';
import '../services/file_picker_service.dart';
import '../services/living_scroll_validator.dart';
import '../widgets/cover_picker.dart';
import 'cover_crop_dialog.dart';
import 'import_selection_dialog.dart';

/// The new-adventure form: a full-height cover picker on the left, the
/// metadata fields + Import/Create actions on the right.
///
/// State lives on the shared [CreateNewController] so the shell's navigation
/// guard can read [CreateNewController.isDirty]. On Create the form writes the
/// project via [ProjectsStore] and calls [onCreated] (the shell then opens the
/// game screen).
class CreateNewScreen extends StatefulWidget {
  const CreateNewScreen({
    super.key,
    required this.controller,
    required this.onCreated,
    this.store = const ProjectsStore(),
  });

  final CreateNewController controller;

  /// Invoked after the project has been written (shell navigates to game).
  final ValueChanged<String> onCreated;

  final ProjectsStore store;

  /// Supported game systems (id -> display name). Single source of truth in
  /// [GameSystems.catalogue]; surfaced here for the System dropdown and reused
  /// by the Adventure settings field.
  static final Map<String, String> systems = GameSystems.names;

  @override
  State<CreateNewScreen> createState() => _CreateNewScreenState();
}

class _CreateNewScreenState extends State<CreateNewScreen> {
  late final TextEditingController _title;
  late final TextEditingController _version;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _contentWarnings;
  late final TextEditingController _license;

  bool _importInvalid = false;

  /// Temp directories of unpacked staged archives — kept alive until Create (the
  /// media is copied then) and deleted on dispose (covers Create and Abandon).
  final List<String> _stagedDirs = [];

  CreateNewController get _model => widget.controller;

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
    // Clean up any unpacked archives staged on this form.
    for (final path in _stagedDirs) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    _model.removeListener(_onModelChanged);
    _title.dispose();
    _version.dispose();
    _author.dispose();
    _description.dispose();
    _contentWarnings.dispose();
    _license.dispose();
    super.dispose();
  }

  // Rebuild on model changes (e.g. Create-enabled toggles as required fields
  // get filled). Text fields keep their own editing controllers, so this never
  // disturbs the cursor.
  void _onModelChanged() => setState(() {});

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

  /// Import works exactly like the Adventure settings form: pick a portable
  /// `.ls`/`.lse` archive, unpack it, validate by extension (`.ls` -> PUBLISHED,
  /// `.lse` -> PROJECT), then show the per-element selection dialog (filtered
  /// against what is already staged + the chosen system). The selection is STAGED
  /// and applied to the new adventure on Create.
  Future<void> _import() async {
    final path = await FilePickerService.instance.pickArchive();
    if (path == null) return;

    final workDir = await Directory.systemTemp.createTemp('ls_import_');
    var keep = false;
    try {
      Map<String, dynamic>? doc;
      try {
        const AdventurePackager().unpack(
          bytes: await File(path).readAsBytes(),
          dest: workDir,
        );
        final decoded = jsonDecode(
          await File('${workDir.path}/LivingScroll.json').readAsString(),
        );
        if (decoded is Map<String, dynamic>) doc = decoded;
      } catch (_) {
        doc = null;
      }
      final LivingScrollValidator validator =
          path.toLowerCase().endsWith('.lse')
          ? const ProjectValidator()
          : const PublishedAdventureValidator();
      if (doc == null || !validator.isValid(doc)) {
        if (mounted) setState(() => _importInvalid = true);
        return;
      }
      if (mounted) setState(() => _importInvalid = false);

      final stagedDoc = doc; // non-null below
      // Analyze against the form's system + what is already staged (dedup).
      final analysis = const AdventureImporter().analyze(
        stagedDoc,
        _stagedTargetDoc(),
      );
      if (!mounted) return;
      final selection = await showImportSelectionDialog(context, analysis);
      if (selection == null || selection.values.every((s) => s.isEmpty)) return;

      keep = true;
      _stagedDirs.add(workDir.path);
      _model.setField(
        () => _model.imports.add(
          StagedImport(
            sourceDir: workDir.path,
            doc: stagedDoc,
            selection: selection,
            sameSystem: analysis.sameSystem,
          ),
        ),
      );
    } finally {
      if (!keep && await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// The document the next import is analyzed against: the chosen system plus the
  /// elements already staged (so a re-import won't offer duplicates).
  Map<String, dynamic> _stagedTargetDoc() {
    var doc = <String, dynamic>{
      'metadata': {'system': _model.system ?? ''},
    };
    for (final imp in _model.imports) {
      doc = const AdventureImporter().merge(
        doc,
        imp.doc,
        imp.selection,
        sameSystem: imp.sameSystem,
      );
      doc['metadata'] = {'system': _model.system ?? ''};
    }
    return doc;
  }

  Future<void> _create() async {
    final slug = await widget.store.create(
      metadata: _model.metadata,
      coverSourcePath: _model.coverSourcePath,
      coverCrop: _model.coverCrop,
      imports: _model.imports,
    );
    if (!mounted) return;
    widget.onCreated(slug);
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
                          key: const ValueKey('create_new.cover'),
                          source: _model.coverSourcePath,
                          crop: _model.coverCrop,
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
                    keyId: 'create_new.field.title',
                    onChanged: (v) => _model.setField(() => _model.title = v),
                  ),
                  _field(
                    _version,
                    l10n.createNewVersionLabel,
                    keyId: 'create_new.field.version',
                    onChanged: (v) => _model.setField(() => _model.version = v),
                  ),
                  _systemDropdown(l10n),
                  _field(
                    _author,
                    l10n.createNewAuthorLabel,
                    keyId: 'create_new.field.author',
                    onChanged: (v) => _model.setField(() => _model.author = v),
                  ),
                  _field(
                    _description,
                    l10n.createNewDescriptionLabel,
                    keyId: 'create_new.field.description',
                    maxLines: 3,
                    onChanged: (v) =>
                        _model.setField(() => _model.description = v),
                  ),
                  _languageDropdown(l10n),
                  _field(
                    _contentWarnings,
                    l10n.createNewContentWarningsLabel,
                    keyId: 'create_new.field.content_warnings',
                    onChanged: (v) =>
                        _model.setField(() => _model.contentWarnings = v),
                  ),
                  _field(
                    _license,
                    l10n.createNewLicenseLabel,
                    keyId: 'create_new.field.license',
                    onChanged: (v) => _model.setField(() => _model.license = v),
                  ),
                  if (_importInvalid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.createNewImportInvalid,
                        key: const ValueKey('create_new.import.error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else if (_model.imports.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.createNewImportSuccess,
                        key: const ValueKey('create_new.import.staged'),
                      ),
                    ),
                ],
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
                key: const ValueKey('create_new.import'),
                onPressed: _import,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.createNewImport),
              ),
              FilledButton(
                key: const ValueKey('create_new.create'),
                onPressed: _model.canCreate ? _create : null,
                child: Text(l10n.createNewCreate),
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
  // (value "") keeps it clearable. A legacy free-text value that maps to no
  // known language is preserved as its own item so Save never silently drops it.
  Widget _languageDropdown(AppLocalizations l10n) {
    final current = _model.language;
    final code = SupportedLanguages.codeFor(current);
    final unknownLegacy = code == null && current.trim().isNotEmpty;
    final value = code ?? (unknownLegacy ? current : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('create_new.field.language'),
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: l10n.createNewLanguageLabel,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String>(
            key: const ValueKey('create_new.field.language.item.unset'),
            value: '',
            child: Text(l10n.createNewLanguageUnset),
          ),
          if (unknownLegacy)
            DropdownMenuItem<String>(
              key: const ValueKey('create_new.field.language.item.legacy'),
              value: current,
              child: Text(current),
            ),
          for (final entry in SupportedLanguages.names.entries)
            DropdownMenuItem<String>(
              key: ValueKey('create_new.field.language.item.${entry.key}'),
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        onChanged: (v) => _model.setField(() => _model.language = v ?? ''),
      ),
    );
  }

  Widget _systemDropdown(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        key: const ValueKey('create_new.field.system'),
        isExpanded: true,
        initialValue: _model.system,
        decoration: InputDecoration(
          labelText: l10n.createNewSystemLabel,
          border: const OutlineInputBorder(),
        ),
        hint: Text(l10n.createNewSystemHint),
        items: [
          for (final entry in CreateNewScreen.systems.entries)
            DropdownMenuItem<String?>(
              key: ValueKey('create_new.field.system.item.${entry.key}'),
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        onChanged: (value) => _model.setField(() => _model.system = value),
      ),
    );
  }
}
