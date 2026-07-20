import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import '../npcs/npcs_controller.dart';
import '../npcs/seven_sea/seven_sea.dart';
import '../npcs/seven_sea/seven_sea_l10n.dart';
import '../npcs/stat_template.dart';
import '../services/file_picker_service.dart';
import '../widgets/cover_picker.dart';
import '../widgets/npc_tile.dart';
import '../widgets/visibility_rules_editor.dart';
import 'cover_crop_dialog.dart';
import 'npc_basicrpg_screen.dart' show showNpcNameNotUniqueDialog;
import 'unsaved_changes_dialog.dart';

/// The 7th Sea 2nd Edition NPC editor — a two-page form:
///
///  1. **Kind** — three radio buttons (Villain / Brute squad / Monster); only
///     one may be chosen. A "Next" button advances.
///  2. **Details** — the common NPC fields (full_image, icon_image, Name,
///     Description) plus the stats the chosen kind adds: a Monster none; a Brute
///     squad `strength`; a Villain `strength`, `influence`, a computed
///     `villainy_rank` and an `advantages` checklist. The inherited
///     visibility_rules editor sits at the bottom.
///
/// Bound to the shared [NpcsController]; the game shell writes the staged images
/// on save (via [onSave]) and persists only the applicable stats
/// ([SystemDef.pruneHiddenStats]).
class Npc7thSeaScreen extends StatefulWidget {
  const Npc7thSeaScreen({
    super.key,
    required this.controller,
    required this.imagesBasePath,
    required this.onSave,
    required this.onCancel,
  });

  final NpcsController controller;
  final String imagesBasePath;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  State<Npc7thSeaScreen> createState() => _Npc7thSeaScreenState();
}

class _Npc7thSeaScreenState extends State<Npc7thSeaScreen> {
  NpcsController get _model => widget.controller;
  StatTemplate get _template => _model.template;
  Map<String, dynamic> get _stats => _model.editStats;

  int _page = 0;
  final Map<String, TextEditingController> _text = {};

  /// A NEW NPC is built in TWO steps (pick the kind, then fill the details). An
  /// EXISTING NPC opens STRAIGHT on the details — its kind was chosen at creation
  /// and can NEVER be changed, so the kind page is
  /// skipped entirely.
  bool get _isNew => _model.isNew;
  int get _stepCount => _isNew ? 2 : 1;

  /// Which page the current step shows: `kind` (new NPC, step 1) or `details`.
  String get _currentPage => (_isNew && _page == 0) ? 'kind' : 'details';

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onModelChanged() => setState(() {});

  TextEditingController _ctl(String path, String current) =>
      _text[path] ??= TextEditingController(text: current);

  /// The current NPC kind (defaults to the template's first kind).
  String get _kind => _stats['kind'] as String? ?? SevenSea.kinds.first;

  /// Whether the given stat field is visible for the current kind (`showWhen`).
  bool _show(String key) {
    final f = _template.fieldFor(key);
    return f != null && isFieldVisible(f, _stats);
  }

  // --- images (staged like the other NPC editors) ---------------------------

  Future<void> _pickFull() async {
    final path = await FilePickerService.instance.pickImage();
    if (path == null || !mounted) return;
    final fullCrop = await showCoverCropDialog(
      context,
      path,
      keyPrefix: 'npc_7thsea.full_image.crop',
      title: AppLocalizations.of(context).npcsCropFull,
    );
    if (fullCrop == null) return;
    final tempFull = await ProjectsStore.cropToTempFull(path, fullCrop);
    _model.stageFull(tempFull);
    if (!mounted) return;
    final iconCrop = await showCoverCropDialog(
      context,
      tempFull,
      keyPrefix: 'npc_7thsea.icon_image.crop',
      title: AppLocalizations.of(context).npcsCropIcon,
    );
    if (iconCrop != null) _model.stageIcon(iconCrop);
  }

  File? _savedImage(String? uuid) {
    if (uuid == null) return null;
    final f = File('${widget.imagesBasePath}/$uuid.png');
    return f.existsSync() ? f : null;
  }

  Future<void> _handleSave() async {
    if (!_model.isNameUnique(_model.editName)) {
      await showNpcNameNotUniqueDialog(context);
      return;
    }
    await widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_page >= _stepCount) _page = _stepCount - 1;
    final onKind = _currentPage == 'kind';
    return Padding(
      key: const ValueKey('npc.7thsea.form'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader(l10n),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('npc.7thsea.page.$_currentPage'),
              child: onKind ? _kindPage(l10n) : _detailsPage(l10n),
            ),
          ),
          const SizedBox(height: 16),
          _navRow(l10n),
        ],
      ),
    );
  }

  Widget _stepHeader(AppLocalizations l10n) {
    final titleKey = _currentPage == 'kind'
        ? 'npcSeaPageKind'
        : 'npcSeaPageDetails';
    return Row(
      children: [
        Text(
          '${_page + 1}/$_stepCount',
          key: const ValueKey('npc.7thsea.step.indicator'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 12),
        Text(
          seaLabel(l10n, titleKey),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _navRow(AppLocalizations l10n) {
    final isLast = _page == _stepCount - 1;
    // All buttons grouped together at the END (Cancel, then Back, then
    // Next/Save) — never split to opposite window edges.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          key: const ValueKey('npc.7thsea.cancel'),
          onPressed: widget.onCancel,
          child: Text(l10n.unsavedCancel),
        ),
        const SizedBox(width: 12),
        if (_page > 0) ...[
          OutlinedButton(
            key: const ValueKey('npc.7thsea.back'),
            onPressed: () => setState(() => _page--),
            child: Text(l10n.npcSeaBack),
          ),
          const SizedBox(width: 12),
        ],
        if (!isLast)
          FilledButton(
            key: const ValueKey('npc.7thsea.next'),
            onPressed: () => setState(() => _page++),
            child: Text(l10n.npcSeaNext),
          )
        else
          FilledButton(
            key: const ValueKey('npc.7thsea.save'),
            onPressed: _model.canSave ? _handleSave : null,
            child: Text(l10n.settingsSave),
          ),
      ],
    );
  }

  // --- page 1: kind selector -------------------------------------------------

  Widget _kindPage(AppLocalizations l10n) {
    return RadioGroup<String>(
      groupValue: _kind,
      onChanged: (v) {
        if (v != null) _model.setStat('kind', v);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final kind in SevenSea.kinds)
            RadioListTile<String>(
              key: ValueKey('npc.7thsea.kind.$kind'),
              value: kind,
              title: Text(seaKindLabel(l10n, kind)),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  // --- page 2: details -------------------------------------------------------

  Widget _detailsPage(AppLocalizations l10n) {
    final staged = _model.editFullStagedPath;
    final iconCrop = _model.editIconCrop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The fixed-size image row scales DOWN to fit a narrow window (a plain
        // fixed Row overflowed horizontally — resize audit, Finding 4); on a wide
        // form it stays at its natural size, left-aligned.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 280,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: NpcTile.maxExtent,
                  height: 280,
                  child: AspectRatio(
                    aspectRatio: 1 / 1.43,
                    child: CoverPickerField(
                      key: const ValueKey('npc.7thsea.full_image'),
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
                  height: NpcTile.maxExtent / NpcTile.aspectRatio,
                  child: CoverPickerField(
                    key: const ValueKey('npc.7thsea.icon_image'),
                    source: iconCrop != null ? staged : null,
                    crop: iconCrop,
                    existingCover: _savedImage(_model.editIconImageUuid),
                    label: l10n.npcsIconLabel,
                    onTap: null,
                    showPlaceholder: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('npc.7thsea.name'),
          controller: _ctl('name', _model.editName),
          onChanged: (v) => _model.editName = v,
          decoration: InputDecoration(
            labelText: l10n.npcsNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('npc.7thsea.description'),
          controller: _ctl('description', _model.editDescription),
          onChanged: (v) => _model.editDescription = v,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.npcsDescriptionLabel,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_show('strength')) ...[
          const SizedBox(height: 16),
          _numeric(l10n, 'strength', l10n.statSeaStrength),
        ],
        if (_show('influence')) ...[
          const SizedBox(height: 16),
          _numeric(l10n, 'influence', l10n.statSeaInfluence),
        ],
        if (_show('villainy_rank')) ...[
          const SizedBox(height: 16),
          _villainyRank(l10n),
        ],
        if (_show('advantages')) ...[
          const SizedBox(height: 24),
          _advantages(l10n),
        ],
        if (_show('schemes')) ...[const SizedBox(height: 24), _schemes(l10n)],
        const SizedBox(height: 16),
        VisibilityRulesEditor(
          value: _model.editVisibility,
          availableKeyEvents: _model.keyEvents,
          onChanged: (v) => _model.editVisibility = v,
        ),
      ],
    );
  }

  /// A 3-digit numeric stat field (0–999): digits only, capped at 3 characters.
  Widget _numeric(AppLocalizations l10n, String key, String label) {
    final current = _stats[key];
    return TextField(
      key: ValueKey('npc.7thsea.field.$key'),
      controller: _ctl('int.$key', '${current ?? ''}'),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(SevenSea.statDigits),
      ],
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        _model.setStat(key, n ?? 0);
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// The computed, read-only Villainy Rank (= Strength + Influence).
  Widget _villainyRank(AppLocalizations l10n) {
    final value = SevenSea.derive('villainy_rank', _stats);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.statSeaVillainyRank,
        border: const OutlineInputBorder(),
        suffixText: l10n.npcSeaComputed,
      ),
      child: Text(
        '$value',
        key: const ValueKey('npc.7thsea.derived.villainy_rank'),
      ),
    );
  }

  /// The width, in px, of the WIDEST advantage label in [style] for the current
  /// locale — used to size a column so no advantage name is ever wrapped.
  double _widestAdvantageLabel(AppLocalizations l10n, TextStyle style) {
    var maxW = 0.0;
    for (final a in kAdvantages) {
      final tp = TextPainter(
        text: TextSpan(text: seaAdvantageLabel(l10n, a.key), style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      maxW = math.max(maxW, tp.width);
    }
    return maxW;
  }

  /// The Advantages checklist (Villain only): one checkbox per [kAdvantages]
  /// entry, labelled per locale (Polish name in `pl`, English otherwise). The
  /// tiles are laid out in COLUMNS whose count adapts to the form width AND the
  /// advantage names — sized so a name is never wrapped.
  Widget _advantages(AppLocalizations l10n) {
    final selected = <String>{
      for (final v in (_stats['advantages'] as List? ?? const [])) '$v',
    };

    void toggle(String key, bool on) {
      final next = {...selected};
      on ? next.add(key) : next.remove(key);
      final ordered = [
        for (final adv in kAdvantages)
          if (next.contains(adv.key)) adv.key,
      ];
      _model.setStat('advantages', ordered);
    }

    final labelStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    // A cell must hold the widest label plus the leading checkbox + padding, so
    // the name never wraps.
    final itemMinWidth = _widestAdvantageLabel(l10n, labelStyle) + 56;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statSeaAdvantages,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          key: const ValueKey('npc.7thsea.advantages.grid'),
          builder: (context, constraints) {
            final columns = SevenSea.advantageColumns(
              constraints.maxWidth,
              itemMinWidth,
            );
            final rows = <Widget>[];
            for (var i = 0; i < kAdvantages.length; i += columns) {
              final slice = kAdvantages.sublist(
                i,
                math.min(i + columns, kAdvantages.length),
              );
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in slice)
                      Expanded(
                        child: _advantageTile(
                          l10n,
                          a.key,
                          selected.contains(a.key),
                          labelStyle,
                          toggle,
                        ),
                      ),
                    // Pad the final short row so cells keep their column width.
                    for (var k = slice.length; k < columns; k++)
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
      ],
    );
  }

  Widget _advantageTile(
    AppLocalizations l10n,
    String key,
    bool checked,
    TextStyle labelStyle,
    void Function(String, bool) toggle,
  ) {
    return CheckboxListTile(
      key: ValueKey('npc.7thsea.advantage.$key'),
      value: checked,
      // A single, non-wrapping line — the column is sized to fit the widest name.
      title: Text(
        seaAdvantageLabel(l10n, key),
        style: labelStyle,
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (on) => toggle(key, on ?? false),
    );
  }

  // --- Schemes / Intrygi (Villain only) -------------------------------------

  /// The Schemes section (Villain only): a header with a **New scheme** button
  /// over a list of scheme tiles. Each scheme's cost is spent from `influence`.
  Widget _schemes(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final list = SevenSea.schemes(_stats);
    return Column(
      key: const ValueKey('npc.7thsea.schemes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.statSeaSchemes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: const ValueKey('npc.7thsea.scheme.new'),
              onPressed: _addScheme,
              icon: const Icon(Icons.add),
              label: Text(l10n.npcSeaSchemeNew),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _schemeTile(l10n, i, list[i], scheme),
          ),
      ],
    );
  }

  /// One scheme tile: the Tactic-Map icon, the scheme name, its cost and a delete
  /// button. Tapping the body opens the edit dialog.
  Widget _schemeTile(
    AppLocalizations l10n,
    int i,
    Map<String, dynamic> s,
    ColorScheme scheme,
  ) {
    final name = s['name'] is String ? s['name'] as String : '';
    final cost = s['cost'] is int ? s['cost'] as int : 0;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('npc.7thsea.scheme.tile.$i'),
        onTap: () => _editScheme(i),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          child: Row(
            children: [
              Icon(Symbols.tactic, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  key: ValueKey('npc.7thsea.scheme.tile.$i.name'),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${l10n.npcSeaSchemeCost}: $cost',
                key: ValueKey('npc.7thsea.scheme.tile.$i.cost'),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
              IconButton(
                key: ValueKey('npc.7thsea.scheme.tile.$i.delete'),
                icon: Icon(Icons.close, color: scheme.onSecondaryContainer),
                onPressed: () => _deleteScheme(i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addScheme() async {
    final available = SevenSea.availableInfluence(_stats);
    final result = await showSchemeDialog(context, available: available);
    if (result == null) return;
    _model.setStat('schemes', [
      ...SevenSea.schemes(_stats),
      {
        'type': SevenSea.schemeTypeScheme,
        'name': result.name,
        'cost': result.cost,
      },
    ]);
  }

  Future<void> _editScheme(int i) async {
    final all = SevenSea.schemes(_stats);
    if (i < 0 || i >= all.length) return;
    final cur = all[i];
    final result = await showSchemeDialog(
      context,
      // Editing a scheme may keep or lower its own cost, so exclude it from the
      // committed budget.
      available: SevenSea.availableInfluence(_stats, excludeIndex: i),
      initialName: cur['name'] is String ? cur['name'] as String : '',
      initialCost: cur['cost'] is int ? cur['cost'] as int : 0,
      editing: true,
    );
    if (result == null) return;
    final next = [...all];
    next[i] = {
      'type': cur['type'] ?? SevenSea.schemeTypeScheme,
      'name': result.name,
      'cost': result.cost,
    };
    _model.setStat('schemes', next);
  }

  void _deleteScheme(int i) {
    final all = SevenSea.schemes(_stats);
    if (i < 0 || i >= all.length) return;
    _model.setStat('schemes', [...all]..removeAt(i));
  }
}

/// Opens the add / edit Scheme dialog (name + cost), returning the entered
/// `(name, cost)` or null on Cancel / Abandon. [available] is the influence that
/// may still be spent — the entered cost must not exceed it. Implements the
/// unsaved-changes guard: cancelling with pending input prompts
/// Save / Abandon / Cancel.
Future<({String name, int cost})?> showSchemeDialog(
  BuildContext context, {
  required int available,
  String initialName = '',
  int initialCost = 0,
  bool editing = false,
}) {
  return showDialog<({String name, int cost})>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SchemeDialog(
      available: available,
      initialName: initialName,
      initialCost: initialCost,
      editing: editing,
    ),
  );
}

class _SchemeDialog extends StatefulWidget {
  const _SchemeDialog({
    required this.available,
    required this.initialName,
    required this.initialCost,
    required this.editing,
  });

  final int available;
  final String initialName;
  final int initialCost;
  final bool editing;

  @override
  State<_SchemeDialog> createState() => _SchemeDialogState();
}

class _SchemeDialogState extends State<_SchemeDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _cost = TextEditingController(
    text: widget.editing ? '${widget.initialCost}' : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  String get _nameText => _name.text.trim();
  int? get _costValue => int.tryParse(_cost.text.trim());

  /// The cost is a non-negative number within the available influence budget.
  bool get _costValid {
    final c = _costValue;
    return c != null && c >= 0 && c <= widget.available;
  }

  bool get _canSave => _nameText.isNotEmpty && _costValid;

  bool get _dirty =>
      _name.text != widget.initialName ||
      _cost.text != (widget.editing ? '${widget.initialCost}' : '');

  void _submit() {
    if (!_canSave) return;
    Navigator.of(context).pop((name: _nameText, cost: _costValue!));
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.save:
        if (_canSave) _submit(); // invalid input stays in the dialog
      case UnsavedChoice.abandon:
        Navigator.of(context).pop();
      case UnsavedChoice.cancel:
      case null:
        break; // stay in the scheme dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // digits-only input means cost is always >= 0; it is only INVALID when it
    // exceeds the available influence.
    final over = _costValue != null && _costValue! > widget.available;
    return AlertDialog(
      key: const ValueKey('npc.7thsea.scheme.dialog'),
      title: Text(
        widget.editing ? l10n.npcSeaSchemeEditTitle : l10n.npcSeaSchemeNew,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('npc.7thsea.scheme.dialog.name'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.npcSeaSchemeName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('npc.7thsea.scheme.dialog.cost'),
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(SevenSea.statDigits),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.npcSeaSchemeCost,
                helperText:
                    '${l10n.npcSeaSchemeAvailable}: ${widget.available}',
                // Over-budget -> red, and the confirm button disables.
                errorText: over
                    ? '${l10n.npcSeaSchemeAvailable}: ${widget.available}'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('npc.7thsea.scheme.dialog.cancel'),
          onPressed: _cancel,
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('npc.7thsea.scheme.dialog.add'),
          onPressed: _canSave ? _submit : null,
          child: Text(
            widget.editing ? l10n.settingsSave : l10n.npcSeaSchemeAdd,
          ),
        ),
      ],
    );
  }
}
