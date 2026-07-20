import 'dart:io';

import 'package:flutter/material.dart';

import '../create/cover_crop.dart';
import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../npcs/npcs_controller.dart';
import '../widgets/cover_picker.dart';
import '../widgets/npc_tile.dart';
import '../widgets/visibility_rules_editor.dart';
import 'cover_crop_dialog.dart';
import '../services/file_picker_service.dart';

/// Warns that an NPC's name must be unique. Shared by the editor's Save and the
/// rail guard's Save so both reject a duplicate with the same prompt.
Future<void> showNpcNameNotUniqueDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('npc.name.not.unique.dialog'),
      content: Text(l10n.npcsNameNotUnique),
      actions: [
        FilledButton(
          key: const ValueKey('npc.name.not.unique.ok'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.dialogOk),
        ),
      ],
    ),
  );
}

/// The Basic RPG NPC edit form: a full-height
/// full_image picker on the left; on the right an icon_image picker (derived from
/// the full image) beside Name + Description, then a full-width Backstory and the
/// visibility gate, with Cancel / Save pinned to the bottom.
///
/// Picking a full image runs TWO crops (full, then icon cropped from the full),
/// both 1:1.43. Bound to the shared [NpcsController]; the game shell writes the
/// staged images on save (via [onSave]).
class NpcBasicRpgScreen extends StatefulWidget {
  const NpcBasicRpgScreen({
    super.key,
    required this.controller,
    required this.imagesBasePath,
    required this.onSave,
    required this.onCancel,
  });

  final NpcsController controller;

  /// Absolute path to the adventure's `images/npcs/` dir (saved-image previews).
  final String imagesBasePath;

  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  State<NpcBasicRpgScreen> createState() => _NpcBasicRpgScreenState();
}

class _NpcBasicRpgScreenState extends State<NpcBasicRpgScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.editName,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.controller.editDescription,
  );
  late final TextEditingController _backstory = TextEditingController(
    text: widget.controller.editBackstory,
  );

  NpcsController get _model => widget.controller;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _name.dispose();
    _description.dispose();
    _backstory.dispose();
    super.dispose();
  }

  void _onModelChanged() => setState(() {});

  /// Pick a full image, then run the two locked-1:1.43 crops: the full image,
  /// then the icon cropped FROM the just-cropped full image. Cancelling the full
  /// crop stages nothing; cancelling the icon crop keeps the full, icon unset.
  Future<void> _pickFull() async {
    final path = await FilePickerService.instance.pickImage();
    if (path == null || !mounted) return;
    final fullCrop = await showCoverCropDialog(
      context,
      path,
      keyPrefix: 'npc_basicrpg.full_image.crop',
      title: AppLocalizations.of(context).npcsCropFull,
    );
    if (fullCrop == null) return;
    final tempFull = await ProjectsStore.cropToTempFull(path, fullCrop);
    _model.stageFull(tempFull);
    if (!mounted) return;
    final iconCrop = await showCoverCropDialog(
      context,
      tempFull,
      keyPrefix: 'npc_basicrpg.icon_image.crop',
      title: AppLocalizations.of(context).npcsCropIcon,
    );
    if (iconCrop != null) _model.stageIcon(iconCrop);
  }

  Future<void> _handleSave() async {
    if (!_model.isNameUnique(_model.editName)) {
      await showNpcNameNotUniqueDialog(context);
      return;
    }
    await widget.onSave();
  }

  File? _savedImage(String? uuid) {
    if (uuid == null) return null;
    final f = File('${widget.imagesBasePath}/$uuid.png');
    return f.existsSync() ? f : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final staged = _model.editFullStagedPath;
    final iconCrop = _model.editIconCrop;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // The whole form SCROLLS vertically, so a short window never overflows;
          // the Cancel/Save row stays pinned below.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageRow(l10n, staged, iconCrop),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('npc_basicrpg.field.name'),
                    controller: _name,
                    onChanged: (v) => _model.editName = v,
                    decoration: InputDecoration(
                      labelText: l10n.npcsNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('npc_basicrpg.field.description'),
                    controller: _description,
                    onChanged: (v) => _model.editDescription = v,
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: l10n.npcsDescriptionLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('npc_basicrpg.field.backstory'),
                    controller: _backstory,
                    onChanged: (v) => _model.editBackstory = v,
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: l10n.npcsBackstoryLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  VisibilityRulesEditor(
                    value: _model.editVisibility,
                    availableKeyEvents: _model.keyEvents,
                    onChanged: (v) => _model.editVisibility = v,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('npc_basicrpg.cancel'),
                onPressed: widget.onCancel,
                child: Text(l10n.unsavedCancel),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('npc_basicrpg.save'),
                onPressed: _model.canSave ? _handleSave : null,
                child: Text(l10n.settingsSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Images row — the full_image picker (left) beside the derived icon_image
  /// preview (right), both at the NPC grid tile size (NpcTile.maxExtent wide,
  /// 1:1.43). Same staging + double-crop flow as the 7th Sea editor. The
  /// fixed-size row scales DOWN to fit a narrow window (FittedBox), so it never
  /// overflows horizontally.
  Widget _imageRow(AppLocalizations l10n, String? staged, CoverCrop? iconCrop) {
    const iconHeight = NpcTile.maxExtent / NpcTile.aspectRatio;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: iconHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: NpcTile.maxExtent,
              height: iconHeight,
              child: AspectRatio(
                aspectRatio: 1 / 1.43,
                child: CoverPickerField(
                  key: const ValueKey('npc_basicrpg.full_image'),
                  source: staged,
                  crop: null,
                  existingCover: _savedImage(_model.editFullImageUuid),
                  label: l10n.npcsFullImageLabel,
                  onTap: _pickFull,
                ),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: NpcTile.maxExtent,
              height: iconHeight,
              child: CoverPickerField(
                key: const ValueKey('npc_basicrpg.icon_image'),
                source: iconCrop != null ? staged : null,
                crop: iconCrop,
                existingCover: _savedImage(_model.editIconImageUuid),
                label: l10n.npcsIconLabel,
                // The icon is DERIVED from the full image (not picked on its own):
                // a non-interactive preview, blank + inactive until one exists.
                onTap: null,
                showPlaceholder: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
