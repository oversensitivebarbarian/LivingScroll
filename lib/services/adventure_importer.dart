import 'dart:convert';

/// Pure rules for importing data from one adventure's `LivingScroll.json` into
/// another (Adventure settings → Import data). No I/O — operates on decoded JSON
/// maps; the store layer ([ProjectsStore.importInto]) writes the result and
/// copies the related media files.
///
/// The flow:
///   1. The picked file is parsed and structurally validated elsewhere; this
///      class takes the already-decoded import document.
///   2. [analyze] reports which content categories the import file carries (the
///      checkbox list) and whether it was built for the SAME game system as the
///      target — NPCs are only importable across MATCHING systems (their stat
///      block is system-bound).
///   3. [merge] applies the user's selection to the target document:
///        * every selected NON-scene collection is appended, PRESERVING uuids
///          (NPCs only when the systems match), but an element whose identity
///          (uuid / path colour / gm-note content) is already in the target is
///          SKIPPED — re-importing an overlapping pack never duplicates;
///        * scenes are special-cased — `next_scenes` is dropped, then every other
///          cross-reference is checked against the (now-merged) target and any
///          link whose target is missing is removed, BEFORE the scene is appended.
class AdventureImporter {
  const AdventureImporter();

  /// The importable content categories, in display order. `scenes` is special-
  /// cased by [merge]; every other entry is a plain append.
  static const List<String> categories = [
    'npcs',
    'key_events',
    'notes',
    'gm_notes',
    'images',
    'audio',
    'paths',
    'scenes',
  ];

  /// Non-scene collections merged by a straight append (uuids preserved).
  static const List<String> _plainCategories = [
    'npcs',
    'key_events',
    'notes',
    'gm_notes',
    'images',
    'audio',
    'paths',
  ];

  /// The unique-identity field per collection. An imported element is
  /// skipped when one with the same identity already exists in the target — uuids
  /// are stable ids and the editor keys edit/delete by them, so two entries
  /// sharing one is an invalid state. `paths` are keyed by `color` (at most one
  /// per colour); `gm_notes` carry no id and fall back to their content.
  static const Map<String, String> _idField = {
    'npcs': 'npc_uuid',
    'key_events': 'key_event_uuid',
    'notes': 'note_uuid',
    'images': 'image_uuid',
    'audio': 'audio_uuid',
    'paths': 'color',
    'scenes': 'scene_uuid',
  };

  /// Inspects [importDoc] against [targetDoc] and returns only the elements that
  /// are actually IMPORTABLE — i.e. NOT already in the target — grouped by
  /// category with a stable id + display label.
  ///
  /// Pre-filtering rules:
  ///   * an element whose identity (uuid / path colour / gm-note content) already
  ///     exists in the target's same collection is skipped (it is already there);
  ///   * NPCs are skipped ENTIRELY when the import targets a different game system
  ///     (their stat block is system-bound), and otherwise
  ///     skipped per-uuid like any other element.
  /// A category left with no importable elements is absent from [ImportAnalysis].
  ImportAnalysis analyze(Map importDoc, Map targetDoc) {
    final importSystem = _system(importDoc);
    final targetSystem = _system(targetDoc);
    final sameSystem = importSystem == targetSystem;

    final present = <String>[];
    final counts = <String, int>{};
    final items = <String, List<ImportItem>>{};
    for (final c in categories) {
      final v = importDoc[c];
      if (v is! List || v.isEmpty) continue;
      // NPCs from an incompatible system cannot be imported at all -> skipped.
      if (c == 'npcs' && !sameSystem) continue;
      // The identities already present in the target's same collection.
      final tv = targetDoc[c];
      final existing = {
        if (tv is List)
          for (final e in tv) _identity(c, e),
      };
      final list = <ImportItem>[
        for (final e in v)
          if (!existing.contains(_identity(c, e)))
            ImportItem(category: c, id: _identity(c, e), label: _label(c, e)),
      ];
      if (list.isEmpty) continue; // every element already in the target
      present.add(c);
      counts[c] = list.length;
      items[c] = list;
    }
    return ImportAnalysis(
      present: present,
      counts: counts,
      items: items,
      importSystem: importSystem,
      targetSystem: targetSystem,
      sameSystem: sameSystem,
    );
  }

  /// A human-readable label for one element of [category]: its name (or note
  /// name / gm-note content / path colour), falling back to its identity.
  String _label(String category, dynamic entry) {
    if (entry is Map) {
      for (final k in const ['name', 'note_name', 'note_content', 'color']) {
        final v = entry[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return _identity(category, entry);
  }

  /// Returns a NEW target document with the [selection] of [importDoc] merged in.
  /// [targetDoc] is not mutated.
  ///
  /// [selection] is per-element: category → set of selected element ids (the same
  /// ids as [ImportItem.id] / [_identity]). Only those individual elements are
  /// imported. When [sameSystem] is false the `npcs` category is dropped entirely
  /// (NPCs never cross systems).
  Map<String, dynamic> merge(
    Map targetDoc,
    Map importDoc,
    Map<String, Set<String>> selection, {
    required bool sameSystem,
  }) {
    // Shallow-copy the target, cloning the lists we may append to so the caller's
    // document is never mutated.
    final result = <String, dynamic>{};
    targetDoc.forEach((k, v) {
      result['$k'] = v is List ? List<dynamic>.from(v) : v;
    });

    final selected = <String, Set<String>>{
      for (final e in selection.entries) e.key: {...e.value},
    };
    if (!sameSystem) selected.remove('npcs');

    // 1) Append the SELECTED non-scene elements, preserving uuids. An imported
    //    element whose identity (uuid / colour / content) already exists in the
    //    target is SKIPPED — never appended a second time (the existing entry
    //    wins), so re-importing an overlapping pack cannot duplicate.
    for (final c in _plainCategories) {
      final sel = selected[c];
      if (sel == null || sel.isEmpty) continue;
      final imported = importDoc[c];
      if (imported is! List) continue;
      final current = result[c];
      final list = current is List ? current : (result[c] = <dynamic>[]);
      final seen = {for (final e in list) _identity(c, e)};
      for (final e in imported) {
        final id = _identity(c, e);
        if (!sel.contains(id)) continue; // element not selected
        if (seen.add(id)) list.add(e);
      }
    }

    // 2) Scenes: strip next_scenes, drop dangling links against the now-merged
    //    target, THEN append. (Order matters: a scene may link an element also
    //    imported in this same operation, which now exists in [result].) A scene
    //    whose scene_uuid already exists in the target is skipped (no duplicate).
    final sceneSel = selected['scenes'];
    if (sceneSel != null && sceneSel.isNotEmpty) {
      final imported = importDoc['scenes'];
      if (imported is List) {
        final current = result['scenes'];
        final scenes = current is List
            ? current
            : (result['scenes'] = <dynamic>[]);
        final seen = {for (final e in scenes) _identity('scenes', e)};
        for (final s in imported) {
          if (s is! Map) continue;
          final id = _identity('scenes', s);
          if (!sceneSel.contains(id)) continue; // scene not selected
          if (seen.add(id)) scenes.add(_cleanScene(s, result));
        }
      }
    }

    return result;
  }

  /// The dedup identity of [entry] within [collection]: its unique-id field when
  /// it has one ([_idField]), the gm-note content when it does not, else the whole
  /// value. Used to skip an imported element already present in the target.
  String _identity(String collection, dynamic entry) {
    final field = _idField[collection];
    if (field != null && entry is Map && entry[field] is String) {
      return entry[field] as String;
    }
    if (entry is Map && entry['note_content'] is String) {
      return 'content:${entry['note_content']}';
    }
    return jsonEncode(entry);
  }

  /// A copy of [scene] with `next_scenes` removed and every remaining cross-
  /// reference filtered to the elements actually present in [target].
  Map<String, dynamic> _cleanScene(Map scene, Map<String, dynamic> target) {
    final out = <String, dynamic>{};
    scene.forEach((k, v) => out['$k'] = v);

    // next_scenes is ALWAYS dropped on import (the imported scene graph does not
    // carry over).
    out.remove('next_scenes');

    // bg_image is a file reference (images/bg_images/<uuid>.png), NOT a member of
    // any collection, so it is kept verbatim; ProjectsStore copies the referenced
    // background-image file alongside the imported scene.

    _filterField(out, 'npcs', _idSet(target, 'npcs', 'name'), const ['name']);
    _filterField(
      out,
      'key_events',
      _idSet(target, 'key_events', 'name'),
      const ['name'],
    );
    _filterField(out, 'path_names', _idSet(target, 'paths', 'name'), const [
      'name',
    ]);
    _filterField(out, 'notes', _idSet(target, 'notes', 'note_uuid'), const [
      'note_uuid',
    ]);
    _filterField(out, 'images', _idSet(target, 'images', 'image_uuid'), const [
      'image_uuid',
    ]);
    _filterField(out, 'audio', _idSet(target, 'audio', 'audio_uuid'), const [
      'audio_uuid',
    ]);

    // visibility_rules.key_events are key_event_uuids; keep only those present in
    // the target. An empty gate collapses to "no rules".
    final vr = out['visibility_rules'];
    if (vr is Map) {
      final keUuids = _idSet(target, 'key_events', 'key_event_uuid');
      final kept = [
        for (final e
            in (vr['key_events'] is List ? vr['key_events'] as List : const []))
          if (keUuids.contains(_refKey(e, const []))) e,
      ];
      if (kept.isEmpty) {
        out.remove('visibility_rules');
      } else {
        final nvr = Map<String, dynamic>.from(vr);
        nvr['key_events'] = kept;
        out['visibility_rules'] = nvr;
      }
    }

    return out;
  }

  /// Filters the list at [out]\[field] to entries whose reference key is in
  /// [allowed]; leaves a non-list field untouched.
  void _filterField(
    Map out,
    String field,
    Set<String> allowed,
    List<String> keys,
  ) {
    final v = out[field];
    if (v is! List) return;
    out[field] = [
      for (final e in v)
        if (allowed.contains(_refKey(e, keys))) e,
    ];
  }

  /// The reference id of a list entry: a plain string, or the first of [keys]
  /// present on a `{name: …}` / `{note_uuid: …}` style reference object.
  String? _refKey(dynamic e, List<String> keys) {
    if (e is String) return e;
    if (e is Map) {
      for (final k in keys) {
        if (e[k] is String) return e[k] as String;
      }
    }
    return null;
  }

  /// The set of [idField] values across [doc]\[collection].
  Set<String> _idSet(Map doc, String collection, String idField) {
    final v = doc[collection];
    final out = <String>{};
    if (v is List) {
      for (final e in v) {
        if (e is Map && e[idField] is String) out.add(e[idField] as String);
      }
    }
    return out;
  }

  String _system(Map doc) {
    final m = doc['metadata'];
    if (m is Map && m['system'] is String) return m['system'] as String;
    return '';
  }
}

/// One importable element: which category it belongs to, its stable id (the
/// same identity [AdventureImporter] dedups/merges by) and a display label.
class ImportItem {
  const ImportItem({
    required this.category,
    required this.id,
    required this.label,
  });

  final String category;
  final String id;
  final String label;
}

/// What an import file carries and how it relates to the target adventure.
class ImportAnalysis {
  const ImportAnalysis({
    required this.present,
    required this.counts,
    required this.items,
    required this.importSystem,
    required this.targetSystem,
    required this.sameSystem,
  });

  /// Categories present (non-empty) in the import file, in display order.
  final List<String> present;

  /// Item count per present category.
  final Map<String, int> counts;

  /// Every individual element, per present category, in file order.
  final Map<String, List<ImportItem>> items;

  final String importSystem;
  final String targetSystem;

  /// Whether the import file was built for the SAME system as the target.
  final bool sameSystem;

  /// True when nothing is importable (every element is already in the target or
  /// was skipped as system-incompatible). The dialog shows the empty-state note.
  bool get isEmpty => present.isEmpty;

  /// The selection when the dialog opens: every importable element of every
  /// present category (category → set of element ids).
  Map<String, Set<String>> get defaultSelection => {
    for (final c in present) c: {for (final it in items[c]!) it.id},
  };
}
