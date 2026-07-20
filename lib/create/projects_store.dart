import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../services/adventure_importer.dart';
import '../services/adventure_packager.dart';
import '../services/latex/latex_exporter.dart';
import '../services/latex/latex_model.dart';
import '../services/living_scroll_validator.dart';
import '../util/uuid.dart';
import 'cover_crop.dart';
import 'game_systems.dart';

/// The outcome of [ProjectsStore.export]: the unpacked adventure saved in the
/// Adventures library, plus the portable `.ls` archive bytes the UI can offer as
/// a download.
class ExportResult {
  const ExportResult({
    required this.unpackedDir,
    required this.archiveBytes,
    required this.suggestedFileName,
  });

  /// `{Adventures}/<title>/` — the saved, unpacked adventure.
  final Directory unpackedDir;

  /// The `.ls` (standard zip + comment header) bytes for download.
  final List<int> archiveBytes;

  /// Default file name suggested by the save dialog (`<title>.ls`).
  final String suggestedFileName;
}

/// The outcome of [ProjectsStore.exportPart]: a TEMPORARY `.lse` archive (kept
/// nowhere permanent) the UI offers as a download and then deletes when the
/// export dialog closes.
class PartExportResult {
  const PartExportResult({
    required this.tempFile,
    required this.suggestedFileName,
  });

  /// The temp `.lse` file; deleted by the caller after the dialog closes.
  final File tempFile;

  /// Default file name suggested by the save dialog (`<title>.lse`).
  final String suggestedFileName;
}

/// The outcome of [ProjectsStore.exportLatex]: the ZIP bytes of a LaTeX export
/// (`main.tex` + `assets/`) and the file name to suggest in the save dialog.
class LatexExportResult {
  const LatexExportResult({
    required this.archiveBytes,
    required this.suggestedFileName,
  });

  /// The `.zip` bytes (`main.tex` at the root + the referenced images).
  final List<int> archiveBytes;

  /// Default file name suggested by the save dialog (`<title>-latex.zip`).
  final String suggestedFileName;
}

/// One adventure as listed in the Create grid.
class AdventureSummary {
  const AdventureSummary({
    required this.slug,
    required this.name,
    this.cover,
    this.valid = true,
    this.version = '',
    this.system = '',
    this.author = '',
    this.description = '',
    this.group = '',
    this.finishedAt,
  });

  /// Directory name under `{Projects}`.
  final String slug;

  /// `metadata.name` (falls back to the slug when missing).
  final String name;

  /// The cover file (`cover.png`/`cover.jpg`) if one exists.
  final File? cover;

  /// Whether `LivingScroll.json` is schema-valid AND its `metadata.system` is a
  /// system this build supports. An invalid adventure cannot be opened (opening
  /// it would throw); its tile renders greyed with a Block glyph.
  final bool valid;

  /// Metadata shown by the Library Adventures info dialog (`metadata.version` /
  /// `.system` / `.author` / `.description`); empty when absent.
  final String version;
  final String system;
  final String author;
  final String description;

  /// The group a SAVE/FINISHED playthrough is for (read from the save's
  /// `group.json`, which moves with the save into `{Finished}`); empty for other
  /// summaries. When non-empty the tile shows it in a bottom overlay.
  final String group;

  /// When this playthrough was FINISHED, parsed from the `{Finished}` directory's
  /// trailing move timestamp (`<saveName>-yyyymmddHHMMSS`); null for non-finished
  /// summaries. The Finished tile shows it (locale-formatted) under the group.
  final DateTime? finishedAt;
}

/// One import staged on the new-adventure form: the unpacked archive's
/// [sourceDir] (holds its media), the decoded [doc], the per-element [selection]
/// and whether it targets the new adventure's [sameSystem]. Applied to the freshly
/// created adventure on Create via [ProjectsStore.importInto] — the SAME path the
/// Adventure settings Import uses.
class StagedImport {
  const StagedImport({
    required this.sourceDir,
    required this.doc,
    required this.selection,
    required this.sameSystem,
  });

  final String sourceDir;
  final Map<String, dynamic> doc;
  final Map<String, Set<String>> selection;
  final bool sameSystem;
}

/// One entry of the Adventures-library index (`Settings/adventures.json`): the
/// identity of an adventure saved under `{Adventures}` (the fields cached in a
/// `.ls` header) plus the directory it lives in. Used as a fast lookup so an
/// export can detect that the SAME adventure is already in the library.
class LibraryEntry {
  const LibraryEntry({
    required this.title,
    required this.version,
    required this.system,
    required this.author,
    required this.language,
    required this.dir,
  });

  final String title;
  final String version;
  final String system;
  final String author;
  final String language;

  /// The directory name under `{Adventures}` holding this adventure.
  final String dir;

  /// Identity match (the dir is NOT part of the identity).
  bool sameIdentity(LibraryEntry o) =>
      title == o.title &&
      version == o.version &&
      system == o.system &&
      author == o.author &&
      language == o.language;

  Map<String, dynamic> toJson() => {
    'title': title,
    'version': version,
    'system': system,
    'author': author,
    'language': language,
    'dir': dir,
  };

  static String _s(Object? v) => v is String ? v : '';

  factory LibraryEntry.fromJson(Map json) => LibraryEntry(
    title: _s(json['title']),
    version: _s(json['version']),
    system: _s(json['system']),
    author: _s(json['author']),
    language: _s(json['language']),
    dir: _s(json['dir']),
  );

  /// Builds an identity-only entry (dir empty) from an adventure's `metadata`.
  factory LibraryEntry.fromMetadata(Object? metadata, {String dir = ''}) {
    String s(String key) {
      final v = metadata is Map ? metadata[key] : null;
      return v is String ? v : '';
    }

    return LibraryEntry(
      title: s('name'),
      version: s('version'),
      system: s('system'),
      author: s('author'),
      language: s('language'),
      dir: dir,
    );
  }
}

/// Outcome of importing a `.ls` into the Adventures library
/// ([ProjectsStore.importLsToLibrary]).
enum LibraryImportStatus {
  /// Unpacked into `{Adventures}` and recorded in the index.
  added,

  /// An adventure with the same identity is already in the library; skipped.
  duplicate,

  /// The archive could not be unpacked or its LivingScroll.json failed PUBLISHED
  /// validation; nothing was imported.
  invalid,
}

/// Which user-files root the EDITOR operates a single adventure under: the
/// default `{Projects}`, or `{Saves}` to reopen a started game
/// (`{Saves}/<name>`) for save-content editing.
enum AdventureBase { projects, saves }

/// Reads and writes adventure projects under the user-files root:
/// `getApplicationSupportDirectory()/Projects/<slug>/` — or, when constructed
/// with `editBase: AdventureBase.saves`, `{Saves}/<name>/` for editing a started
/// game. Library / save / finished operations always resolve their own
/// dedicated roots regardless of [editBase].
class ProjectsStore {
  const ProjectsStore({this.editBase = AdventureBase.projects});

  /// The per-adventure editor base (`{Projects}` vs `{Saves}`). See [_editRoot].
  final AdventureBase editBase;

  static const ProjectValidator _validator = ProjectValidator();

  /// Cover IMAGE PROFILE: portrait 1:1.43.
  static const int coverWidth = 1000;
  static const int coverHeight = 1430;

  /// The root the EDITOR reads/writes a single adventure under, chosen by
  /// [editBase]: `{Projects}/<slug>` (default) or `{Saves}/<name>` (save-content
  /// editing). Every per-adventure editor op (read/update/
  /// write*/import*/media paths/delete*/cloneNpc/export) resolves through this,
  /// so a save-based store operates entirely within `{Saves}/<name>`.
  ///
  /// Project-management ops (create/list/cloneAdventure/delete/
  /// copyLibraryAdventureToProject) also resolve here, but are only ever invoked
  /// on the DEFAULT (projects) store — never on a save-based one.
  Future<Directory> _editRoot() async {
    final support = await getApplicationSupportDirectory();
    final sub = editBase == AdventureBase.saves ? 'Saves' : 'Projects';
    return Directory('${support.path}/$sub');
  }

  /// `{Adventures}` — the library of published `.ls` archives.
  Future<Directory> _adventuresDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/Adventures');
  }

  /// `Settings/adventures.json` — the Adventures-library index (alongside the
  /// settings `overrides.json`). A fast lookup of every adventure in the library.
  Future<File> _adventuresIndexFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/Settings/adventures.json');
  }

  /// The Adventures-library index (`Settings/adventures.json`). Empty when the
  /// file is absent or unreadable (never throws to the caller).
  Future<List<LibraryEntry>> libraryIndex() async {
    final file = await _adventuresIndexFile();
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map) LibraryEntry.fromJson(e),
        ];
      }
    } catch (_) {
      // Corrupt index -> treat as empty rather than crashing.
    }
    return const [];
  }

  Future<void> _writeLibraryIndex(List<LibraryEntry> entries) async {
    final file = await _adventuresIndexFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final e in entries) e.toJson()]),
    );
  }

  /// Imports a portable `.ls` archive at [lsPath] into the Adventures library: it
  /// is unpacked to a temp dir, its `LivingScroll.json` is validated at PUBLISHED
  /// level, then copied into `{Adventures}/<title>/` with an entry recorded in the
  /// index. Returns the outcome ([LibraryImportStatus]); the temp dir is always
  /// cleaned up.
  ///
  /// When an adventure with the SAME identity is already in the library: with
  /// [overwrite] false it returns [LibraryImportStatus.duplicate] (nothing
  /// written), so the caller can prompt; with [overwrite] true its directory is
  /// REPLACED in place and the entry updated.
  Future<LibraryImportStatus> importLsToLibrary(
    String lsPath, {
    bool overwrite = false,
    AdventurePackager packager = const AdventurePackager(),
  }) async {
    final tmp = await Directory.systemTemp.createTemp('ls_lib_import_');
    try {
      Map<String, dynamic>? doc;
      try {
        packager.unpack(bytes: await File(lsPath).readAsBytes(), dest: tmp);
        final decoded = jsonDecode(
          await File('${tmp.path}/LivingScroll.json').readAsString(),
        );
        if (decoded is Map<String, dynamic>) doc = decoded;
      } catch (_) {
        doc = null;
      }
      if (doc == null || !const PublishedAdventureValidator().isValid(doc)) {
        return LibraryImportStatus.invalid;
      }
      final metadata = doc['metadata'];
      final index = List<LibraryEntry>.of(await libraryIndex());
      final identity = LibraryEntry.fromMetadata(metadata);
      final existing = index.indexWhere((e) => e.sameIdentity(identity));
      if (existing >= 0 && !overwrite) {
        return LibraryImportStatus.duplicate;
      }

      final adventures = await _adventuresDir();
      await adventures.create(recursive: true);

      Directory dest;
      if (existing >= 0) {
        // Overwrite: replace the existing library directory in place.
        dest = Directory('${adventures.path}/${index[existing].dir}');
        if (await dest.exists()) await dest.delete(recursive: true);
        await dest.create(recursive: true);
      } else {
        final title = metadata is Map && metadata['name'] is String
            ? metadata['name'] as String
            : 'adventure';
        dest = _uniqueDir(adventures, _sanitizeFileName(title));
      }
      await _copyDirectory(tmp, dest);

      final dirName = dest.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final entry = LibraryEntry.fromMetadata(metadata, dir: dirName);
      if (existing >= 0) {
        index[existing] = entry;
      } else {
        index.add(entry);
      }
      await _writeLibraryIndex(index);
      return LibraryImportStatus.added;
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  }

  /// Copies a library adventure (`{Adventures}/[dir]`) into `{Projects}` as a new,
  /// editable project under a uniquely-named directory; the copy's `metadata.name`
  /// is made unique among projects. Returns the new project slug (empty if the
  /// source is missing). The Library "Copy as project" action.
  Future<String> copyLibraryAdventureToProject(String dir) async {
    final adventures = await _adventuresDir();
    final src = Directory('${adventures.path}/$dir');
    if (!src.existsSync()) return '';

    final projects = await _editRoot();
    await projects.create(recursive: true);
    final srcJson = File('${src.path}/LivingScroll.json');
    final doc = srcJson.existsSync() ? _decode(srcJson) : null;
    final srcName = _nameOf(doc) ?? dir;
    final newName = await _uniqueAdventureName(projects, srcName);
    final newSlug = await _uniqueSlug(projects, newName);
    final dst = Directory('${projects.path}/$newSlug');

    await _copyDir(src, dst);

    final dstJson = File('${dst.path}/LivingScroll.json');
    if (dstJson.existsSync() && doc != null) {
      final copy = Map<String, dynamic>.from(doc);
      final metadata = (doc['metadata'] is Map)
          ? Map<String, dynamic>.from(doc['metadata'] as Map)
          : <String, dynamic>{};
      metadata['name'] = newName;
      copy['metadata'] = metadata;
      await dstJson.writeAsString(
        const JsonEncoder.withIndent('  ').convert(copy),
      );
    }
    return newSlug;
  }

  /// Copies an archived session (`{Finished}/[dir]`) into `{Projects}` as a new,
  /// editable project under a uniquely-named directory; the copy's `metadata.name`
  /// is made unique among projects. Every `key_events[].state` is reset to
  /// "unchecked" in the copy (the finished game's own progress is not carried
  /// into the new project), and every GM note is DROPPED — `gm_notes[]` is
  /// emptied and every scene's `gmnotes[]` link list is cleared (GM notes are
  /// session-specific asides from the played game, not adventure content worth
  /// carrying into a fresh project). Returns the new project slug (empty if the
  /// source is missing). The Library Finished tile's "Copy as project" action.
  Future<String> copyFinishedToProject(String dir) async {
    final finished = await _finishedDir();
    final src = Directory('${finished.path}/$dir');
    if (!src.existsSync()) return '';

    final projects = await _editRoot();
    await projects.create(recursive: true);
    final srcJson = File('${src.path}/LivingScroll.json');
    final doc = srcJson.existsSync() ? _decode(srcJson) : null;
    final srcName = _nameOf(doc) ?? dir;
    final newName = await _uniqueAdventureName(projects, srcName);
    final newSlug = await _uniqueSlug(projects, newName);
    final dst = Directory('${projects.path}/$newSlug');

    await _copyDir(src, dst);

    final dstJson = File('${dst.path}/LivingScroll.json');
    if (dstJson.existsSync() && doc != null) {
      final copy = Map<String, dynamic>.from(doc);
      final metadata = (doc['metadata'] is Map)
          ? Map<String, dynamic>.from(doc['metadata'] as Map)
          : <String, dynamic>{};
      metadata['name'] = newName;
      copy['metadata'] = metadata;
      final events = copy['key_events'];
      if (events is List) {
        copy['key_events'] = [
          for (final e in events)
            if (e is Map)
              {...Map<String, dynamic>.from(e), 'state': 'unchecked'}
            else
              e,
        ];
      }
      copy['gm_notes'] = <dynamic>[];
      final scenes = copy['scenes'];
      if (scenes is List) {
        copy['scenes'] = [
          for (final s in scenes)
            if (s is Map)
              {...Map<String, dynamic>.from(s), 'gmnotes': <dynamic>[]}
            else
              s,
        ];
      }
      await dstJson.writeAsString(
        const JsonEncoder.withIndent('  ').convert(copy),
      );
    }
    return newSlug;
  }

  // --- Starting a playthrough (Library Adventures -> Saves) ----------------

  /// The `{Saves}` directory name for a playthrough of [title] (version
  /// [version]) by group [group] — the convention `<title>-<version>-<group>`,
  /// sanitized for the filesystem.
  static String saveDirName(String title, String version, String group) =>
      _sanitizeFileName('$title-$version-$group');

  /// The decoded `LivingScroll.json` of the library adventure in
  /// `{Adventures}/<dir>`, or null when missing/unreadable.
  Future<Map<String, dynamic>?> readAdventure(String dir) async {
    final adventures = await _adventuresDir();
    final json = File('${adventures.path}/$dir/LivingScroll.json');
    if (!json.existsSync()) return null;
    final decoded = _decode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Builds a LaTeX export (`main.tex` + `assets/`, as ZIP bytes) for the library
  /// adventure in `{Adventures}/<dir>`. The document
  /// headings localize to the adventure's own `metadata.language`; asset paths and
  /// their bytes are resolved against the adventure directory (a missing image is
  /// simply skipped). Returns null when the adventure is missing/unreadable. Reads
  /// only — nothing is written to disk here (the caller offers the bytes for
  /// download).
  Future<LatexExportResult?> exportLatex(String dir) async {
    final adventures = await _adventuresDir();
    final root = Directory('${adventures.path}/$dir');
    final doc = _decode(File('${root.path}/LivingScroll.json'));
    if (doc is! Map<String, dynamic>) return null;

    final metadata = doc['metadata'];
    String meta(String key) => (metadata is Map && metadata[key] is String)
        ? metadata[key] as String
        : '';

    final export = buildLatexExport(
      doc,
      LatexLabels.forLanguage(meta('language')),
      assetExists: (rel) => File('${root.path}/$rel').existsSync(),
    );

    final bytes = zipLatexExport(
      export,
      (rel) => File('${root.path}/$rel').readAsBytesSync(),
    );

    final title = meta('name').isNotEmpty ? meta('name') : dir;
    return LatexExportResult(
      archiveBytes: bytes,
      suggestedFileName: '${_sanitizeFileName('$title-latex')}.zip',
    );
  }

  /// Whether a save directory named [saveName] already exists under `{Saves}`.
  Future<bool> saveExists(String saveName) async {
    final saves = await _savesDir();
    return Directory('${saves.path}/$saveName').existsSync();
  }

  /// The absolute path of the `{Saves}/<saveName>` playthrough directory.
  Future<String> savePath(String saveName) async {
    final saves = await _savesDir();
    return '${saves.path}/$saveName';
  }

  /// Overwrites the `{Saves}/<saveName>` playthrough's `LivingScroll.json` with
  /// [doc] (used when a gameplay session adds a GM note to the save).
  Future<void> writeSaveDocument(
    String saveName,
    Map<String, dynamic> doc,
  ) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/LivingScroll.json');
    if (!file.parent.existsSync()) return;
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(doc));
  }

  /// The decoded `LivingScroll.json` of the `{Saves}/<saveName>` playthrough.
  Future<Map<String, dynamic>?> readSave(String saveName) async {
    final saves = await _savesDir();
    final json = File('${saves.path}/$saveName/LivingScroll.json');
    if (!json.existsSync()) return null;
    final decoded = _decode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Copies the library adventure `{Adventures}/<adventureDir>` into `{Saves}`
  /// under the save-name convention (`<title>-<version>-<group>`), as a fresh
  /// playthrough. Returns the save name; returns null when the source is missing,
  /// or when that save already exists and [overwrite] is false. With [overwrite]
  /// true an existing save (and ALL its progress) is deleted first.
  Future<String?> startSaveFromLibrary({
    required String adventureDir,
    required String groupName,
    List<String> players = const [],
    bool overwrite = false,
  }) async {
    final adventures = await _adventuresDir();
    final src = Directory('${adventures.path}/$adventureDir');
    if (!src.existsSync()) return null;

    final doc = _decode(File('${src.path}/LivingScroll.json'));
    final metadata = (doc != null && doc['metadata'] is Map)
        ? doc['metadata'] as Map
        : const {};
    String meta(String k) =>
        (metadata[k] is String) ? metadata[k] as String : '';
    final title = meta('name').isNotEmpty ? meta('name') : adventureDir;
    final saveName = saveDirName(title, meta('version'), groupName.trim());

    final saves = await _savesDir();
    await saves.create(recursive: true);
    final dst = Directory('${saves.path}/$saveName');
    if (dst.existsSync()) {
      if (!overwrite) return null;
      await dst.delete(recursive: true);
    }
    await _copyDir(src, dst);
    // Stamp every base object `immutable: true`: the content
    // that exists at save creation is frozen against edit/delete in the
    // save-content editor; elements added later stay mutable. Runs on every
    // creation path (incl. overwrite, which copies fresh above).
    if (doc is Map) {
      _stampImmutable(doc);
      await File(
        '${dst.path}/LivingScroll.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(doc));
    }
    // Record the group this playthrough is for, plus the player-character (PC)
    // names — so a resume can show / restore them, and party split has a roster
    // to operate on (tracks <= players). Empty/whitespace names are dropped and
    // duplicates removed, preserving entry order.
    await File('${dst.path}/group.json').writeAsString(
      jsonEncode({
        'group': groupName.trim(),
        'players': _normalizePlayers(players),
      }),
    );
    return saveName;
  }

  /// Trims, drops empty/whitespace-only entries and de-duplicates [players]
  /// while preserving first-seen order. Shared by the save writer and any caller
  /// that needs the canonical roster shape.
  static List<String> _normalizePlayers(List<String> players) {
    final seen = <String>{};
    final out = <String>[];
    for (final p in players) {
      final name = p.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      out.add(name);
    }
    return out;
  }

  /// The group name a `{Saves}/<saveName>` playthrough is for (from its
  /// `group.json`), or empty when absent.
  Future<String> readSaveGroup(String saveName) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/group.json');
    if (!file.existsSync()) return '';
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['group'] is String) {
        return decoded['group'] as String;
      }
    } catch (_) {}
    return '';
  }

  /// The player-character (PC) names a `{Saves}/<saveName>` playthrough is for
  /// (from its `group.json` `players` list), or empty when absent. Party split
  /// uses this roster (a session can split into at most
  /// `min(players.length, PartyController.maxParallelTracks)` tracks).
  Future<List<String>> readSavePlayers(String saveName) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/group.json');
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['players'] is List) {
        return [
          for (final e in decoded['players'] as List)
            if (e is String) e,
        ];
      }
    } catch (_) {}
    return const [];
  }

  /// Rewrites the `players` roster of a `{Saves}/<saveName>` playthrough's
  /// `group.json`, PRESERVING its `group` name (the save dir already encodes the
  /// group, so it is never changed here). Used when a RESUME edits the roster on
  /// the launch screen — the roster is editable there (add/remove/rename), unlike
  /// the group. [players] is normalized (trimmed, blanks dropped, de-duplicated,
  /// first-seen order kept) like the writer in [startSaveFromLibrary]. A no-op
  /// when the save (or its group.json) is absent.
  Future<void> writeSavePlayers(String saveName, List<String> players) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/group.json');
    if (!file.parent.existsSync()) return;
    var group = '';
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map && decoded['group'] is String) {
          group = decoded['group'] as String;
        }
      } catch (_) {}
    }
    await file.writeAsString(
      jsonEncode({'group': group, 'players': _normalizePlayers(players)}),
    );
  }

  /// Imports the PROGRESS of a `{Finished}/<fromFinishedDir>` archived session
  /// into a fresh `{Saves}/<saveName>` playthrough (the launch screen's "Import
  /// progress" for a NEW game — the source is picked from a Saves-style grid of
  /// the FINISHED games, excluding same-game finished sessions). THREE
  /// collections carry over:
  ///   * `key_events[]`, keyed by `key_event_uuid` — an ABSENT uuid is CREATED
  ///     (the whole event copied, with its `state`); a PRESENT uuid has its
  ///     `state` SET to the finished save's state.
  ///   * `npcs[]`, keyed by `npc_uuid` — the SAME rule as key_events: an ABSENT
  ///     uuid is CREATED (the whole NPC copied, with its `state`); a PRESENT
  ///     uuid has its `state` (active/inactive) SET to the finished save's
  ///     state.
  ///   * `gm_notes[]`, keyed by `gmnote_uuid` — an ABSENT uuid is COPIED IN
  ///     (`gmnote_uuid` + `gmnote_content`) and linked to EVERY scene's
  ///     `gmnotes[]` (a GM note is ALWAYS global); a
  ///     PRESENT uuid is left untouched (a GM note has no runtime state to
  ///     adopt).
  /// Nothing else carries over (scenes, notes, images, paths, ...). A no-op
  /// when either document is missing. Writes the new save's
  /// `LivingScroll.json` in place.
  Future<void> importSaveProgress({
    required String saveName,
    required String fromFinishedDir,
  }) async {
    final source = await readFinished(fromFinishedDir);
    if (source == null) return;
    final target = await readSave(saveName);
    if (target == null) return;

    // Shared by key_events[] and npcs[]: match by [uuidKey], creating an
    // absent entry (copied whole, with its state) and adopting the state of a
    // present one.
    void importStateByUuid(String collectionKey, String uuidKey) {
      final srcList = source[collectionKey];
      if (srcList is! List || srcList.isEmpty) return;
      final tgtRaw = target[collectionKey];
      final tgtList = tgtRaw is List
          ? tgtRaw
          : (target[collectionKey] = <dynamic>[]);
      for (final se in srcList) {
        if (se is! Map) continue;
        final uuid = se[uuidKey];
        if (uuid is! String || uuid.isEmpty) continue;
        Map? existing;
        for (final te in tgtList) {
          if (te is Map && te[uuidKey] == uuid) {
            existing = te;
            break;
          }
        }
        if (existing == null) {
          // uuid absent -> create it together with its state (copy the whole entry).
          tgtList.add(Map<String, dynamic>.from(se));
        } else {
          // uuid present -> adopt the finished save's state.
          existing['state'] = se['state'];
        }
      }
    }

    importStateByUuid('key_events', 'key_event_uuid');
    importStateByUuid('npcs', 'npc_uuid');

    // gm_notes[]: a GM note carries no runtime state, so a PRESENT uuid is
    // left untouched; an ABSENT one is copied in and linked to EVERY scene's
    // gmnotes[] (a GM note is always global — mirrors PlaythroughScreen._addGmNote).
    final srcNotes = source['gm_notes'];
    if (srcNotes is List && srcNotes.isNotEmpty) {
      final tgtNotesRaw = target['gm_notes'];
      final tgtNotes = tgtNotesRaw is List
          ? tgtNotesRaw
          : (target['gm_notes'] = <dynamic>[]);
      final tgtScenesRaw = target['scenes'];
      final tgtScenes = tgtScenesRaw is List ? tgtScenesRaw : const [];
      for (final sn in srcNotes) {
        if (sn is! Map) continue;
        final uuid = sn['gmnote_uuid'];
        if (uuid is! String || uuid.isEmpty) continue;
        final exists = tgtNotes.any(
          (n) => n is Map && n['gmnote_uuid'] == uuid,
        );
        if (exists) continue;
        tgtNotes.add({
          'gmnote_uuid': uuid,
          'gmnote_content': sn['gmnote_content'] is String
              ? sn['gmnote_content']
              : '',
        });
        for (final s in tgtScenes) {
          if (s is! Map) continue;
          final links = s['gmnotes'] is List
              ? s['gmnotes'] as List
              : (s['gmnotes'] = <dynamic>[]);
          if (!links.contains(uuid)) links.add(uuid);
        }
      }
    }

    await writeSaveDocument(saveName, target);
  }

  /// The playthrough's recorded scene history (the scene UUIDs entered, in
  /// order) from `{Saves}/<saveName>/history.json`, or empty when absent. Each
  /// entry is a `scene_uuid` — an author scene (`scenes[]`) OR a runtime ad-hoc
  /// scene (`party.json` `adhoc_scenes[]`). The last entry is where a resume
  /// continues (the last visited scene).
  Future<List<String>> readSaveHistory(String saveName) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/history.json');
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is String) e,
        ];
      }
    } catch (_) {}
    return const [];
  }

  /// Appends [sceneUuid] to the playthrough's `history.json` (a JSON list of the
  /// scene UUIDs visited, in order) under `{Saves}/<saveName>`. An entry may be an
  /// author `scene_uuid` OR a runtime ad-hoc scene's uuid (resolved via
  /// `party.json` on resume/replay). Used by a gameplay session to record
  /// progress; a dry run never calls this.
  Future<void> appendSaveHistory(String saveName, String sceneUuid) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/history.json');
    final history = <dynamic>[];
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) history.addAll(decoded);
      } catch (_) {
        // A corrupt history starts over rather than crashing the session.
      }
    }
    history.add(sceneUuid);
    // Best-effort: the save dir may have been removed (deleted / finished) while
    // a fire-and-forget write was in flight — don't crash on a vanished path.
    try {
      await file.writeAsString(jsonEncode(history));
    } catch (_) {}
  }

  /// The party-split snapshot for `{Saves}/<saveName>` from its `party.json`
  /// (the tracks + runtime ad-hoc scenes), or null when absent/unreadable. A
  /// null result means "no split state persisted" — the host then resumes as a
  /// single track. `party.json` is the ONLY file party split adds to a save; the
  /// global progress (`history.json`, `key_events[].state`, `scenes[].visited`)
  /// is unchanged.
  Future<Map<String, dynamic>?> readPartyState(String saveName) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/party.json');
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Writes the party-split snapshot [json] to `{Saves}/<saveName>/party.json`
  /// (gameplay only — the host calls it after every track mutation). Best-effort,
  /// like [appendSaveHistory]: a vanished save dir (deleted / finished mid-write)
  /// is tolerated rather than crashing the session.
  Future<void> writePartyState(
    String saveName,
    Map<String, dynamic> json,
  ) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/party.json');
    if (!file.parent.existsSync()) return;
    try {
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
    } catch (_) {}
  }

  /// Deletes an in-progress playthrough directory `{Saves}/<saveName>` and all
  /// its contents (the Library Saves tile's delete button). The game progress is
  /// lost.
  Future<void> deleteSave(String saveName) async {
    final saves = await _savesDir();
    final dir = Directory('${saves.path}/$saveName');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// The absolute path of a `{Finished}/<dir>` archived session.
  Future<String> finishedPath(String dir) async {
    final finished = await _finishedDir();
    return '${finished.path}/$dir';
  }

  /// The decoded `LivingScroll.json` of a `{Finished}/<dir>` archived session.
  Future<Map<String, dynamic>?> readFinished(String dir) async {
    final finished = await _finishedDir();
    final json = File('${finished.path}/$dir/LivingScroll.json');
    if (!json.existsSync()) return null;
    final decoded = _decode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// The recorded scene chronology (scene UUIDs, in order) of a `{Finished}/<dir>`
  /// archived session — the replay's playback order. Each entry is an author or
  /// ad-hoc `scene_uuid`. Empty when absent.
  Future<List<String>> readFinishedHistory(String dir) async {
    final finished = await _finishedDir();
    final file = File('${finished.path}/$dir/history.json');
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is String) e,
        ];
      }
    } catch (_) {}
    return const [];
  }

  /// The party-split snapshot of a `{Finished}/<dir>` archived session (its
  /// `party.json`, which moved into `{Finished}` with the save), or null when
  /// absent/unreadable. Replay reads its `adhoc_scenes[]` so a recorded ad-hoc
  /// scene resolves by uuid. Sibling of [readPartyState] under `{Finished}`.
  Future<Map<String, dynamic>?> readFinishedPartyState(String dir) async {
    final finished = await _finishedDir();
    final file = File('${finished.path}/$dir/party.json');
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Permanently deletes a `{Finished}/<dir>` archived session (the Library
  /// Finished tile's delete button). It cannot be recovered.
  Future<void> deleteFinished(String dir) async {
    final finished = await _finishedDir();
    final d = Directory('${finished.path}/$dir');
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Archives a finished playthrough: MOVES `{Saves}/<saveName>` into
  /// `{Finished}` under a name with a move timestamp appended
  /// (`<saveName>-<yyyymmddHHMMSS>`), so the completed game is kept read-only in
  /// the Finished library. Returns the finished directory name, or null when the
  /// save is missing. (The save no longer exists under `{Saves}` afterwards.)
  Future<String?> finishSave(String saveName) async {
    final saves = await _savesDir();
    final src = Directory('${saves.path}/$saveName');
    if (!src.existsSync()) return null;
    final finished = await _finishedDir();
    await finished.create(recursive: true);

    final stamp = _timestamp();
    var name = '$saveName-$stamp';
    var dst = Directory('${finished.path}/$name');
    var i = 2;
    while (dst.existsSync()) {
      name = '$saveName-$stamp-$i';
      dst = Directory('${finished.path}/$name');
      i++;
    }
    await src.rename(dst.path);
    return name;
  }

  /// A compact local timestamp `yyyymmddHHMMSS`, valid in a directory name.
  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  /// Persists the live gameplay session state into the save's own
  /// `LivingScroll.json` (so the playthrough can be resumed). Called on each
  /// navigation to the next scene:
  ///   * commits the carried [checkedKeyEvents] into `key_events[].state`
  ///     (`checked` for the listed names, `unchecked` for the rest), and
  ///   * marks the scene being left ([visitedSceneUuid]) with `"visited": true`,
  ///     UNLESS it is a `recurring` scene — a recurring scene is never marked
  ///     visited (it may be re-entered, so it must stay available), and
  ///   * sets every NPC in [inactiveNpcUuids] (by `npc_uuid`) to
  ///     `"state": "inactive"` — the NPCs the GM greyed out this scene, and
  ///   * marks every note in [seenNoteUuids] (by `note_uuid`) and every image in
  ///     [seenImageUuids] (by `image_uuid`) with `"seen": true` — the visible
  ///     notes/images of the scene being left (they join the "seen" gallery).
  /// A dry run (preview) never calls this.
  Future<void> commitSaveProgress(
    String saveName, {
    required Set<String> checkedKeyEvents,
    required String visitedSceneUuid,
    Set<String> inactiveNpcUuids = const {},
    Set<String> seenNoteUuids = const {},
    Set<String> seenImageUuids = const {},
  }) async {
    final saves = await _savesDir();
    final file = File('${saves.path}/$saveName/LivingScroll.json');
    if (!file.existsSync()) return;
    final doc = _decode(file);
    if (doc == null) return;

    if (doc['key_events'] is List) {
      for (final e in doc['key_events'] as List) {
        if (e is Map) {
          final name = e['name'];
          e['state'] = (name is String && checkedKeyEvents.contains(name))
              ? 'checked'
              : 'unchecked';
        }
      }
    }
    if (inactiveNpcUuids.isNotEmpty && doc['npcs'] is List) {
      for (final n in doc['npcs'] as List) {
        if (n is Map && inactiveNpcUuids.contains(n['npc_uuid'])) {
          n['state'] = 'inactive';
        }
      }
    }
    if (visitedSceneUuid.isNotEmpty && doc['scenes'] is List) {
      for (final s in doc['scenes'] as List) {
        if (s is Map && s['scene_uuid'] == visitedSceneUuid) {
          // A RECURRING scene is never marked visited: it can be entered again
          // and again, so it must stay available rather than be recorded as a
          // one-time, already-seen scene.
          if (s['scene_type'] != 'recurring') s['visited'] = true;
          break;
        }
      }
    }
    // The visible notes/images of the scene being left become "seen" (a bool
    // runtime flag), so they surface in the play view's seen gallery.
    if (seenNoteUuids.isNotEmpty && doc['notes'] is List) {
      for (final n in doc['notes'] as List) {
        if (n is Map && seenNoteUuids.contains(n['note_uuid'])) {
          n['seen'] = true;
        }
      }
    }
    if (seenImageUuids.isNotEmpty && doc['images'] is List) {
      for (final im in doc['images'] as List) {
        if (im is Map && seenImageUuids.contains(im['image_uuid'])) {
          im['seen'] = true;
        }
      }
    }
    // Best-effort (see appendSaveHistory): tolerate a vanished save dir.
    try {
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(doc));
    } catch (_) {}
  }

  /// Deletes a library adventure: removes `{Adventures}/[dir]` and its entry from
  /// the index (`Settings/adventures.json`). The Library "Delete" action.
  Future<void> deleteLibraryAdventure(String dir) async {
    final adventures = await _adventuresDir();
    final target = Directory('${adventures.path}/$dir');
    if (await target.exists()) await target.delete(recursive: true);
    final index = List<LibraryEntry>.of(await libraryIndex())
      ..removeWhere((e) => e.dir == dir);
    await _writeLibraryIndex(index);
  }

  /// The library entry whose identity (title/version/system/author/language)
  /// matches [metadata], or `null` when the adventure is not yet in the library.
  Future<LibraryEntry?> findLibraryDuplicate(Object? metadata) async {
    final identity = LibraryEntry.fromMetadata(metadata);
    for (final e in await libraryIndex()) {
      if (e.sameIdentity(identity)) return e;
    }
    return null;
  }

  /// Exports [slug]: saves the UNPACKED adventure (a copy of its project
  /// directory) under `{Adventures}/<title>/`, records it in the library index
  /// (`Settings/adventures.json`), and also builds the portable single-file `.ls`
  /// archive bytes (variant B — the title/version/system/author/language header is
  /// cached in the zip comment, see [AdventurePackager]) for the caller to offer
  /// as a download. The caller validates publish-readiness first.
  ///
  /// When [overwrite] is true and an adventure with the SAME identity is already
  /// in the index, its directory is REPLACED in place (and its index entry
  /// updated); otherwise a fresh uniquely-named directory is added.
  Future<ExportResult> export(
    String slug, {
    bool overwrite = false,
    AdventurePackager packager = const AdventurePackager(),
  }) async {
    final projects = await _editRoot();
    final source = Directory('${projects.path}/$slug');
    final metadata = (await read(slug))?['metadata'];
    final title = metadata is Map && metadata['name'] is String
        ? metadata['name'] as String
        : slug;
    final base = _sanitizeFileName(title);

    // 1. Save the unpacked adventure into the Adventures library, maintaining the
    //    index. On overwrite, replace the matching directory in place.
    final adventures = await _adventuresDir();
    await adventures.create(recursive: true);
    final index = List<LibraryEntry>.of(await libraryIndex());
    final identity = LibraryEntry.fromMetadata(metadata);
    final existing = index.indexWhere((e) => e.sameIdentity(identity));

    Directory unpacked;
    if (overwrite && existing >= 0) {
      unpacked = Directory('${adventures.path}/${index[existing].dir}');
      if (await unpacked.exists()) await unpacked.delete(recursive: true);
      await unpacked.create(recursive: true);
    } else {
      unpacked = _uniqueDir(adventures, base);
    }
    await _copyDirectory(source, unpacked);

    final dirName = unpacked.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final entry = LibraryEntry.fromMetadata(metadata, dir: dirName);
    if (overwrite && existing >= 0) {
      index[existing] = entry;
    } else {
      index.add(entry);
    }
    await _writeLibraryIndex(index);

    // 2. Build the .ls bytes for download.
    final bytes = packager.pack(
      sourceDir: source,
      header: AdventurePackager.headerFromMetadata(metadata),
    );

    return ExportResult(
      unpackedDir: unpacked,
      archiveBytes: bytes,
      suggestedFileName: '$base.ls',
    );
  }

  /// Partially exports [slug] as a `.lse` archive (same packing + cached header
  /// as [export]), written to a TEMPORARY location only — never the Adventures
  /// library. Returns the temp file so the caller can offer it as a download and
  /// then [deleteTemp] it once the dialog closes. The caller validates name +
  /// system first ([PartExportValidator]).
  Future<PartExportResult> exportPart(
    String slug, {
    AdventurePackager packager = const AdventurePackager(),
  }) async {
    final projects = await _editRoot();
    final source = Directory('${projects.path}/$slug');
    final metadata = (await read(slug))?['metadata'];
    final title = metadata is Map && metadata['name'] is String
        ? metadata['name'] as String
        : slug;
    final base = _sanitizeFileName(title);

    final bytes = packager.pack(
      sourceDir: source,
      header: AdventurePackager.headerFromMetadata(metadata),
    );

    final tmp = await _exportTmpDir();
    await tmp.create(recursive: true);
    final file = _uniqueFile(tmp, base, 'lse');
    await file.writeAsBytes(bytes);

    return PartExportResult(tempFile: file, suggestedFileName: '$base.lse');
  }

  /// Deletes a temporary export file (e.g. a `.lse` after its dialog closes).
  Future<void> deleteTemp(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// `<support>/.export_tmp` — scratch space for download-only artifacts.
  Future<Directory> _exportTmpDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/.export_tmp');
  }

  /// `<base>.<ext>` under [dir], or `<base> 2.<ext>`, … when taken.
  File _uniqueFile(Directory dir, String base, String ext) {
    var candidate = File('${dir.path}/$base.$ext');
    var i = 2;
    while (candidate.existsSync()) {
      candidate = File('${dir.path}/$base $i.$ext');
      i++;
    }
    return candidate;
  }

  /// A filesystem-safe base name (illegal characters replaced with `_`).
  static String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'adventure' : cleaned;
  }

  /// `<base>` under [dir], or `<base> 2`, `<base> 3`, … when taken; created.
  Directory _uniqueDir(Directory dir, String base) {
    var candidate = Directory('${dir.path}/$base');
    var i = 2;
    while (candidate.existsSync()) {
      candidate = Directory('${dir.path}/$base $i');
      i++;
    }
    candidate.createSync(recursive: true);
    return candidate;
  }

  /// Recursively copies every file under [source] into [dest] (preserving the
  /// relative tree).
  Future<void> _copyDirectory(Directory source, Directory dest) async {
    for (final entity in source.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(source.path.length + 1);
      final target = File('${dest.path}/$relative');
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }

  /// `{Saves}` — in-progress playthroughs (unpacked adventures + game progress).
  Future<Directory> _savesDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/Saves');
  }

  /// `{Finished}` — completed adventures kept READ-ONLY.
  Future<Directory> _finishedDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/Finished');
  }

  /// Lists the adventures under `{Projects}` (directories with a
  /// `LivingScroll.json`), sorted by slug for a stable grid order.
  Future<List<AdventureSummary>> list() async =>
      _summariesIn(await _editRoot());

  /// Lists the unpacked `.ls` adventures under `{Adventures}` (Library tab).
  Future<List<AdventureSummary>> listAdventures() async =>
      _summariesIn(await _adventuresDir());

  /// Lists the in-progress playthroughs under `{Saves}` (Library tab).
  Future<List<AdventureSummary>> listSaves() async =>
      _summariesIn(await _savesDir(), withGroup: true);

  /// Lists the completed read-only adventures under `{Finished}` (Library tab).
  /// Each carries its playthrough group AND completion date for the tile overlay.
  Future<List<AdventureSummary>> listFinished() async => _summariesIn(
    await _finishedDir(),
    withGroup: true,
    withFinishedDate: true,
  );

  /// The adventures directly under [root] (subdirectories carrying a
  /// `LivingScroll.json`), sorted by directory name for a stable grid order.
  /// When [withGroup] is set (the Saves/Finished roots), each summary also carries
  /// the playthrough's group from its `group.json`; when [withFinishedDate] is set
  /// (the Finished root), it also carries the completion date parsed from the
  /// directory's trailing move timestamp — both for the tile's bottom overlay.
  Future<List<AdventureSummary>> _summariesIn(
    Directory root, {
    bool withGroup = false,
    bool withFinishedDate = false,
  }) async {
    if (!await root.exists()) return const [];

    final result = <AdventureSummary>[];
    final entries = root.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final dir in entries) {
      final json = File('${dir.path}/LivingScroll.json');
      if (!json.existsSync()) continue;
      final slug = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final decoded = _decode(json);
      final name = _nameOf(decoded);
      final valid =
          decoded != null &&
          _validator.isValid(decoded, supportedSystems: GameSystems.ids);
      final metadata = (decoded != null) ? decoded['metadata'] : null;
      String meta(String key) => (metadata is Map && metadata[key] is String)
          ? metadata[key] as String
          : '';
      result.add(
        AdventureSummary(
          slug: slug,
          name: name ?? slug,
          cover: _findCover(dir),
          valid: valid,
          version: meta('version'),
          system: meta('system'),
          author: meta('author'),
          description: meta('description'),
          group: withGroup ? _groupOf(dir) : '',
          finishedAt: withFinishedDate ? _finishedAtOf(slug) : null,
        ),
      );
    }
    return result;
  }

  /// Creates a new adventure directory under `{Projects}`:
  ///   * writes a base `LivingScroll.json` from [metadata] (empty collections),
  ///   * applies each staged [imports] entry via [importInto] (the SAME merge +
  ///     media-copy path the Adventure settings Import uses), and
  ///   * when [coverSourcePath] is given, crops/scales it to the cover profile
  ///     and saves it as `cover.jpg`.
  /// Returns the created slug.
  Future<String> create({
    required Map<String, String> metadata,
    String? coverSourcePath,
    CoverCrop? coverCrop,
    List<StagedImport>? imports,
  }) async {
    final root = await _editRoot();
    await root.create(recursive: true);
    final slug = await _uniqueSlug(root, metadata['name'] ?? 'adventure');
    final dir = Directory('${root.path}/$slug');
    await dir.create();

    final document = _buildDocument(metadata);
    await File(
      '${dir.path}/LivingScroll.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(document));

    // Apply the staged imports (selected elements + media) onto the new adventure.
    for (final imp in imports ?? const <StagedImport>[]) {
      await importInto(
        slug: slug,
        sourceDir: imp.sourceDir,
        importDoc: imp.doc,
        selection: imp.selection,
        sameSystem: imp.sameSystem,
      );
    }

    if (coverSourcePath != null) {
      await _writeCover(
        coverSourcePath,
        coverCrop,
        File('${dir.path}/cover.jpg'),
      );
    }
    return slug;
  }

  /// Reads the decoded `LivingScroll.json` of [slug], or `null` when missing /
  /// unreadable.
  Future<Map<String, dynamic>?> read(String slug) async {
    final root = await _editRoot();
    final json = File('${root.path}/$slug/LivingScroll.json');
    if (!await json.exists()) return null;
    try {
      final decoded = jsonDecode(await json.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The existing cover file (`cover.png`/`cover.jpg`) of [slug], if any.
  Future<File?> coverFile(String slug) async {
    final root = await _editRoot();
    return _findCover(Directory('${root.path}/$slug'));
  }

  /// Updates an existing adventure (Adventure settings):
  ///   * replaces `metadata` in the existing `LivingScroll.json` (every other
  ///     collection is preserved), and
  ///   * when [coverSourcePath] is given, crops/scales it to the cover profile
  ///     and overwrites `cover.jpg`.
  /// The directory already exists — nothing is created. (Importing data is a
  /// separate, immediate operation — see [importInto].)
  Future<void> update({
    required String slug,
    required Map<String, String> metadata,
    String? coverSourcePath,
    CoverCrop? coverCrop,
  }) async {
    final root = await _editRoot();
    final dir = Directory('${root.path}/$slug');
    final jsonFile = File('${dir.path}/LivingScroll.json');

    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['metadata'] = metadata;

    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );

    if (coverSourcePath != null) {
      await _writeCover(
        coverSourcePath,
        coverCrop,
        File('${dir.path}/cover.jpg'),
      );
    }
  }

  /// Imports the user-selected [selection] of categories from a decoded import
  /// document [importDoc] (whose media lives under [sourceDir]) into the existing
  /// adventure [slug]'s `LivingScroll.json`. The merge rules live in
  /// [AdventureImporter.merge] (next_scenes stripped, dangling scene links
  /// pruned, NPCs only when [sameSystem]); this method additionally copies the
  /// RELATED media files (location/NPC/other images, audio) of the imported items
  /// from [sourceDir] into the adventure. Best-effort on media: a referenced file
  /// missing in the source is skipped, the element is still imported.
  Future<void> importInto({
    required String slug,
    required String sourceDir,
    required Map<String, dynamic> importDoc,
    required Map<String, Set<String>> selection,
    required bool sameSystem,
  }) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final targetDoc = existing is Map<String, dynamic>
        ? existing
        : <String, dynamic>{};

    final merged = const AdventureImporter().merge(
      targetDoc,
      importDoc,
      selection,
      sameSystem: sameSystem,
    );

    await _copyImportMedia(slug, sourceDir, importDoc, selection, sameSystem);

    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(merged),
    );
  }

  /// Copies the media files of the imported items from [sourceDir]'s adventure
  /// layout (`images/locations`, `images/npcs`, `images/other`, `audio`) into
  /// [slug]. Mirrors the categories merged by [AdventureImporter.merge].
  Future<void> _copyImportMedia(
    String slug,
    String sourceDir,
    Map<String, dynamic> importDoc,
    Map<String, Set<String>> selection,
    bool sameSystem,
  ) async {
    Future<void> copyPng(String srcSub, String destDir, String? uuid) async {
      if (uuid == null || uuid.isEmpty) return;
      final src = File('$sourceDir/$srcSub/$uuid.png');
      if (!src.existsSync()) return;
      await Directory(destDir).create(recursive: true);
      await src.copy('$destDir/$uuid.png');
    }

    List<Map> items(String key) => importDoc[key] is List
        ? (importDoc[key] as List).whereType<Map>().toList()
        : const [];

    // Whether the element with [id] was individually selected in [category].
    bool selected(String category, String? id) =>
        id != null && (selection[category]?.contains(id) ?? false);

    if (sameSystem && (selection['npcs']?.isNotEmpty ?? false)) {
      final dest = await npcImagesPath(slug);
      for (final n in items('npcs')) {
        if (!selected('npcs', n['npc_uuid'] as String?)) continue;
        await copyPng('images/npcs', dest, n['full_image'] as String?);
        await copyPng('images/npcs', dest, n['icon_image'] as String?);
      }
    }
    if (selection['images']?.isNotEmpty ?? false) {
      final dest = await imagesOtherPath(slug);
      for (final i in items('images')) {
        final id = i['image_uuid'] as String?;
        if (!selected('images', id)) continue;
        await copyPng('images/other', dest, id);
      }
    }
    // A selected scene brings its background image file (images/bg_images/) — bg
    // images are files only (no collection), so they travel with the scene.
    if (selection['scenes']?.isNotEmpty ?? false) {
      final dest = await bgImagesPath(slug);
      for (final s in items('scenes')) {
        if (!selected('scenes', s['scene_uuid'] as String?)) continue;
        await copyPng('images/bg_images', dest, s['bg_image'] as String?);
      }
    }
    if (selection['audio']?.isNotEmpty ?? false) {
      final srcDir = Directory('$sourceDir/audio');
      if (srcDir.existsSync()) {
        final files = srcDir.listSync().whereType<File>().toList();
        final dest = await audioPath(slug);
        for (final a in items('audio')) {
          final uuid = a['audio_uuid'];
          if (uuid is! String || uuid.isEmpty) continue;
          if (!selected('audio', uuid)) continue;
          for (final f in files) {
            final name = f.uri.pathSegments.last;
            final dot = name.lastIndexOf('.');
            final base = dot > 0 ? name.substring(0, dot) : name;
            if (base == uuid) {
              await Directory(dest).create(recursive: true);
              await f.copy('$dest/$name');
              break;
            }
          }
        }
      }
    }
  }

  /// Replaces the `paths` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the Paths editor's Save.
  Future<void> writePaths(String slug, List<Map<String, dynamic>> paths) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['paths'] = paths;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Replaces the `notes` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the Notes editor's Save / delete.
  Future<void> writeNotes(String slug, List<Map<String, dynamic>> notes) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['notes'] = notes;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Replaces the `key_events` collection of [slug]'s `LivingScroll.json` in
  /// place, preserving every other field. Used by the Key events editor's Save.
  Future<void> writeKeyEvents(
    String slug,
    List<Map<String, dynamic>> keyEvents,
  ) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['key_events'] = keyEvents;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Replaces the `scenes` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the scene editor's Save / delete.
  Future<void> writeScenes(
    String slug,
    List<Map<String, dynamic>> scenes,
  ) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['scenes'] = scenes;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Replaces the `audio` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the Soundtracks add / delete.
  Future<void> writeAudio(String slug, List<Map<String, dynamic>> audio) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['audio'] = audio;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Copies the picked audio file [sourcePath] into [slug]'s `audio/` directory,
  /// named by [uuid] keeping the source extension (`audio/<uuid>.<ext>`), and
  /// returns the written file.
  Future<File> importAudio(String slug, String sourcePath, String uuid) async {
    final root = await _editRoot();
    final dir = Directory('${root.path}/$slug/audio');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$uuid${_extension(sourcePath)}');
    await File(sourcePath).copy(target.path);
    return target;
  }

  /// Absolute path to [slug]'s `audio/` directory (where soundtracks live).
  Future<String> audioPath(String slug) async {
    final root = await _editRoot();
    return '${root.path}/$slug/audio';
  }

  /// The on-disk file for the track [uuid] (`audio/<uuid>.<ext>`), or `null`.
  Future<File?> audioFile(String slug, String uuid) async {
    final root = await _editRoot();
    final dir = Directory('${root.path}/$slug/audio');
    if (!dir.existsSync()) return null;
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      if (base == uuid) return f;
    }
    return null;
  }

  /// Deletes the audio file for the track [uuid] under [slug]'s `audio/`, if any.
  Future<void> deleteAudioFile(String slug, String uuid) async {
    final f = await audioFile(slug, uuid);
    if (f != null && await f.exists()) await f.delete();
  }

  /// The extension of [path] including the leading dot (e.g. `.mp3`), or empty.
  String _extension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot) : '';
  }

  /// Replaces the `images` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the Images add / delete.
  Future<void> writeImages(
    String slug,
    List<Map<String, dynamic>> images,
  ) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['images'] = images;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Absolute path to [slug]'s `images/other/` directory (the general image pool
  /// shown in the Images section).
  Future<String> imagesOtherPath(String slug) async {
    final root = await _editRoot();
    return '${root.path}/$slug/images/other';
  }

  /// Converts the picked image [sourcePath] to PNG (no crop/scale — an "other"
  /// image) and writes it to `images/other/<imageUuid>.png`.
  Future<File> importImage(
    String slug,
    String sourcePath,
    String imageUuid,
  ) async {
    final dir = Directory(await imagesOtherPath(slug));
    await dir.create(recursive: true);
    final target = File('${dir.path}/$imageUuid.png');
    final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
    if (decoded == null) {
      await File(sourcePath).copy(target.path);
    } else {
      await target.writeAsBytes(img.encodePng(decoded));
    }
    return target;
  }

  /// The on-disk file for the image [imageUuid] under `images/other/`, or `null`.
  Future<File?> imageFile(String slug, String imageUuid) async {
    final f = File('${await imagesOtherPath(slug)}/$imageUuid.png');
    return f.existsSync() ? f : null;
  }

  /// Deletes the image file [imageUuid] under `images/other/`, if any.
  Future<void> deleteImageFile(String slug, String imageUuid) async {
    final f = await imageFile(slug, imageUuid);
    if (f != null && await f.exists()) await f.delete();
  }

  /// Absolute path to [slug]'s `images/bg_images/` directory — the dedicated pool
  /// of scene BACKGROUND images (`scenes.bg_image`). Background images are files
  /// only (no collection, no name, no visibility rules); the Background image
  /// picker browses this directory.
  Future<String> bgImagesPath(String slug) async {
    final root = await _editRoot();
    return '${root.path}/$slug/images/bg_images';
  }

  /// The image_uuids of every background image on disk (the `*.png` files under
  /// `images/bg_images/`, sorted). Drives the Background image picker.
  Future<List<String>> listBgImages(String slug) async {
    final dir = Directory(await bgImagesPath(slug));
    if (!dir.existsSync()) return const [];
    final uuids = <String>[
      for (final f in dir.listSync().whereType<File>())
        if (f.uri.pathSegments.last.toLowerCase().endsWith('.png'))
          f.uri.pathSegments.last.replaceFirst(
            RegExp(r'\.png$', caseSensitive: false),
            '',
          ),
    ]..sort();
    return uuids;
  }

  /// Converts the picked image [sourcePath] to PNG (no crop/scale — a background
  /// image) and writes it to `images/bg_images/<imageUuid>.png`.
  Future<File> importBgImage(
    String slug,
    String sourcePath,
    String imageUuid,
  ) async {
    final dir = Directory(await bgImagesPath(slug));
    await dir.create(recursive: true);
    final target = File('${dir.path}/$imageUuid.png');
    final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
    if (decoded == null) {
      await File(sourcePath).copy(target.path);
    } else {
      await target.writeAsBytes(img.encodePng(decoded));
    }
    return target;
  }

  /// Cascade-deletes the key_event named [name] from [slug]'s
  /// `LivingScroll.json`: strips every reference to the name across the
  /// document's collections (each entity's `visibility_rules.key_events`, each
  /// scene's `key_events[]`) AND removes the event itself from `key_events[]`.
  Future<void> deleteKeyEvent(String slug, String name) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    if (!jsonFile.existsSync()) return;
    final existing = jsonDecode(jsonFile.readAsStringSync());
    if (existing is! Map<String, dynamic>) return;
    final document = Map<String, dynamic>.from(existing);
    _cascadeRemoveKeyEvent(document, name);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Removes every reference to the key_event [name] across [document], then the
  /// event itself from `key_events[]`. References are mixed:
  /// `visibility_rules.key_events` hold the event's `key_event_uuid`, while
  /// `scenes.key_events[]` hold its name — so both the uuid and the name are
  /// needed to strip every reference.
  void _cascadeRemoveKeyEvent(Map<String, dynamic> document, String name) {
    final uuid = _keyEventUuid(document, name);
    for (final entry in document.entries) {
      // The events themselves are handled last; only strip references here.
      if (entry.key == 'key_events') continue;
      final value = entry.value;
      if (value is! List) continue;
      for (final item in value) {
        if (item is Map) _stripEventReference(item, name, uuid);
      }
    }
    final events = document['key_events'];
    if (events is List) {
      events.removeWhere((e) => e is Map && e['name'] == name);
    }
  }

  /// The `key_event_uuid` of the event named [name] (empty when absent).
  String _keyEventUuid(Map<String, dynamic> document, String name) {
    final events = document['key_events'];
    if (events is List) {
      for (final e in events) {
        if (e is Map && e['name'] == name) {
          final id = e['key_event_uuid'];
          return id is String ? id : '';
        }
      }
    }
    return '';
  }

  /// Drops the event's [uuid] from an item's `visibility_rules.key_events`
  /// (collapsing an emptied rule to nothing) and the event's
  /// [name] from a direct `key_events[]` reference list (e.g. a scene's).
  void _stripEventReference(Map item, String name, String uuid) {
    final rules = item['visibility_rules'];
    if (rules is Map) {
      final refs = rules['key_events'];
      if (refs is List) {
        refs.removeWhere((e) => e == uuid);
        if (refs.isEmpty) item.remove('visibility_rules');
      }
    }
    final direct = item['key_events'];
    if (direct is List) {
      direct.removeWhere((e) => e == name || (e is Map && e['name'] == name));
    }
  }

  // --- NPCs ---------------------------------------------------------------

  /// NPC role-image PROFILES: portrait 1:1.43.
  static const int npcFullWidth = 1000;
  static const int npcFullHeight = 1430;
  static const int npcIconWidth = 400;
  static const int npcIconHeight = 572;

  /// Absolute path to [slug]'s `images/npcs/` directory.
  Future<String> npcImagesPath(String slug) async {
    final root = await _editRoot();
    return '${root.path}/$slug/images/npcs';
  }

  /// Replaces the `npcs` collection of [slug]'s `LivingScroll.json` in place,
  /// preserving every other field. Used by the NPC editor's Save.
  Future<void> writeNpcs(String slug, List<Map<String, dynamic>> npcs) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    final existing = jsonFile.existsSync()
        ? jsonDecode(jsonFile.readAsStringSync())
        : null;
    final document = (existing is Map<String, dynamic>)
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    document['npcs'] = npcs;
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Crops [sourcePath] to [crop] (or a centered 1:1.43 region) and scales it to
  /// the full NPC profile, writing a temp PNG used BOTH as the icon-crop source
  /// and as the saved full image. Returns the temp file path.
  static Future<String> cropToTempFull(
    String sourcePath,
    CoverCrop? crop,
  ) async {
    final dir = await Directory.systemTemp.createTemp('ls_npc_');
    final target = File('${dir.path}/full.png');
    final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
    if (decoded == null) {
      await File(sourcePath).copy(target.path);
    } else {
      await target.writeAsBytes(
        img.encodePng(_cropScale(decoded, crop, npcFullWidth, npcFullHeight)),
      );
    }
    return target.path;
  }

  /// Writes the staged full PNG [fullPngPath] (already at the full profile) to
  /// `images/npcs/<uuid>.png`.
  Future<File> writeNpcFullImage(
    String slug,
    String fullPngPath,
    String uuid,
  ) async {
    final dir = Directory(await npcImagesPath(slug));
    await dir.create(recursive: true);
    final target = File('${dir.path}/$uuid.png');
    final decoded = img.decodeImage(await File(fullPngPath).readAsBytes());
    if (decoded == null) {
      await File(fullPngPath).copy(target.path);
    } else {
      final out = img.copyResize(
        decoded,
        width: npcFullWidth,
        height: npcFullHeight,
      );
      await target.writeAsBytes(img.encodePng(out));
    }
    return target;
  }

  /// Crops the staged full PNG [fullPngPath] by [iconCrop] and scales it to the
  /// icon profile, writing `images/npcs/<uuid>.png`.
  Future<File> writeNpcIconImage(
    String slug,
    String fullPngPath,
    CoverCrop iconCrop,
    String uuid,
  ) async {
    final dir = Directory(await npcImagesPath(slug));
    await dir.create(recursive: true);
    final target = File('${dir.path}/$uuid.png');
    final decoded = img.decodeImage(await File(fullPngPath).readAsBytes());
    if (decoded == null) {
      await File(fullPngPath).copy(target.path);
    } else {
      await target.writeAsBytes(
        img.encodePng(
          _cropScale(decoded, iconCrop, npcIconWidth, npcIconHeight),
        ),
      );
    }
    return target;
  }

  /// The on-disk image for the NPC image [uuid] under `images/npcs/`, or `null`.
  Future<File?> npcImageFile(String slug, String uuid) async {
    final f = File('${await npcImagesPath(slug)}/$uuid.png');
    return f.existsSync() ? f : null;
  }

  /// Deletes the NPC image file [uuid] under `images/npcs/`, if any.
  Future<void> deleteNpcImage(String slug, String? uuid) async {
    if (uuid == null) return;
    final f = await npcImageFile(slug, uuid);
    if (f != null && await f.exists()) await f.delete();
  }

  /// Cascade-deletes the NPC [npcUuid] from [slug]'s `LivingScroll.json`: removes
  /// its `npcs[]` entry, strips its name from every scene's `npcs[]`, and deletes
  /// its full/icon image files.
  Future<void> deleteNpc(String slug, String npcUuid) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    if (!jsonFile.existsSync()) return;
    final existing = jsonDecode(jsonFile.readAsStringSync());
    if (existing is! Map<String, dynamic>) return;
    final document = Map<String, dynamic>.from(existing);
    final npcs = document['npcs'];
    if (npcs is! List) return;
    Map? entry;
    for (final n in npcs) {
      if (n is Map && n['npc_uuid'] == npcUuid) {
        entry = n;
        break;
      }
    }
    if (entry == null) return;
    final name = entry['name'];
    final scenes = document['scenes'];
    if (scenes is List) {
      for (final s in scenes) {
        if (s is! Map) continue;
        final refs = s['npcs'];
        if (refs is List) {
          refs.removeWhere((e) => e == name || (e is Map && e['name'] == name));
        }
      }
    }
    npcs.removeWhere((n) => n is Map && n['npc_uuid'] == npcUuid);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    final full = entry['full_image'];
    final icon = entry['icon_image'];
    await deleteNpcImage(slug, full is String ? full : null);
    await deleteNpcImage(slug, icon is String ? icon : null);
  }

  /// Clones the NPC [npcUuid] in [slug]'s `LivingScroll.json`: appends a copy
  /// with a fresh `npc_uuid`, a UNIQUE name (the original + " cloned"), and the
  /// full/icon images copied to new ids.
  Future<void> cloneNpc(String slug, String npcUuid) async {
    final root = await _editRoot();
    final jsonFile = File('${root.path}/$slug/LivingScroll.json');
    if (!jsonFile.existsSync()) return;
    final existing = jsonDecode(jsonFile.readAsStringSync());
    if (existing is! Map<String, dynamic>) return;
    final document = Map<String, dynamic>.from(existing);
    final npcs = document['npcs'];
    if (npcs is! List) return;
    Map? src;
    for (final n in npcs) {
      if (n is Map && n['npc_uuid'] == npcUuid) {
        src = n;
        break;
      }
    }
    if (src == null) return;
    final clone = Map<String, dynamic>.from(src);
    clone['npc_uuid'] = uuidV4();
    final baseName = src['name'] is String ? src['name'] as String : '';
    clone['name'] = _uniqueNpcName(npcs, '$baseName cloned');
    final srcFull = src['full_image'];
    if (srcFull is String && srcFull.isNotEmpty) {
      final newId = uuidV4();
      await _copyNpcImage(slug, srcFull, newId);
      clone['full_image'] = newId;
    }
    final srcIcon = src['icon_image'];
    if (srcIcon is String && srcIcon.isNotEmpty) {
      final newId = uuidV4();
      await _copyNpcImage(slug, srcIcon, newId);
      clone['icon_image'] = newId;
    }
    npcs.add(clone);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// A name unique within [npcs]: [base], else `base 2`, `base 3`, …
  String _uniqueNpcName(List npcs, String base) {
    bool taken(String n) => npcs.any((e) => e is Map && e['name'] == n);
    if (!taken(base)) return base;
    var i = 2;
    while (taken('$base $i')) {
      i++;
    }
    return '$base $i';
  }

  /// Copies an NPC image file `<srcUuid>.png` to `<dstUuid>.png`.
  Future<void> _copyNpcImage(
    String slug,
    String srcUuid,
    String dstUuid,
  ) async {
    final src = await npcImageFile(slug, srcUuid);
    if (src == null) return;
    final dir = Directory(await npcImagesPath(slug));
    await dir.create(recursive: true);
    await src.copy('${dir.path}/$dstUuid.png');
  }

  /// Crops [decoded] to [crop] (normalized) — or a centered [w]:[h] region when
  /// none is given — then scales it to exactly [w]x[h].
  static img.Image _cropScale(
    img.Image decoded,
    CoverCrop? crop,
    int w,
    int h,
  ) {
    final int x, y, cropW, cropH;
    if (crop != null) {
      cropW = (crop.width * decoded.width).round();
      cropH = (crop.height * decoded.height).round();
      x = (crop.left * decoded.width).round();
      y = (crop.top * decoded.height).round();
    } else {
      final targetRatio = w / h;
      final srcRatio = decoded.width / decoded.height;
      if (srcRatio > targetRatio) {
        cropH = decoded.height;
        cropW = (cropH * targetRatio).round();
      } else {
        cropW = decoded.width;
        cropH = (cropW / targetRatio).round();
      }
      x = (decoded.width - cropW) ~/ 2;
      y = (decoded.height - cropH) ~/ 2;
    }
    final cropped = img.copyCrop(
      decoded,
      x: x.clamp(0, decoded.width - 1),
      y: y.clamp(0, decoded.height - 1),
      width: cropW.clamp(1, decoded.width),
      height: cropH.clamp(1, decoded.height),
    );
    return img.copyResize(cropped, width: w, height: h);
  }

  /// Clones the adventure [slug]: copies its whole directory to a NEW unique slug
  /// directory under `{Projects}` and renames the copy (metadata.name = the
  /// original + " cloned", disambiguated to stay unique among adventure names,
  /// mirroring NPC clone). Returns the new slug.
  Future<String> cloneAdventure(String slug) async {
    final root = await _editRoot();
    final srcDir = Directory('${root.path}/$slug');
    if (!srcDir.existsSync()) return slug;

    final srcJson = File('${srcDir.path}/LivingScroll.json');
    final doc = srcJson.existsSync() ? _decode(srcJson) : null;
    final srcName = _nameOf(doc) ?? slug;
    final newName = await _uniqueAdventureName(root, '$srcName cloned');
    final newSlug = await _uniqueSlug(root, newName);
    final dstDir = Directory('${root.path}/$newSlug');

    await _copyDir(srcDir, dstDir);

    final dstJson = File('${dstDir.path}/LivingScroll.json');
    if (dstJson.existsSync() && doc != null) {
      final cloneDoc = Map<String, dynamic>.from(doc);
      final metadata = (doc['metadata'] is Map)
          ? Map<String, dynamic>.from(doc['metadata'] as Map)
          : <String, dynamic>{};
      metadata['name'] = newName;
      cloneDoc['metadata'] = metadata;
      await dstJson.writeAsString(
        const JsonEncoder.withIndent('  ').convert(cloneDoc),
      );
    }
    return newSlug;
  }

  /// An adventure name unique across `{Projects}`: [base], else `base 2`, …
  Future<String> _uniqueAdventureName(Directory root, String base) async {
    final names = <String>{};
    if (root.existsSync()) {
      for (final dir in root.listSync().whereType<Directory>()) {
        final f = File('${dir.path}/LivingScroll.json');
        if (!f.existsSync()) continue;
        final n = _nameOf(_decode(f));
        if (n != null) names.add(n);
      }
    }
    if (!names.contains(base)) return base;
    var i = 2;
    while (names.contains('$base $i')) {
      i++;
    }
    return '$base $i';
  }

  /// Recursively copies the contents of [src] into [dst].
  Future<void> _copyDir(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    for (final entity in src.listSync(recursive: true)) {
      final rel = entity.path.substring(src.path.length + 1);
      if (entity is Directory) {
        await Directory('${dst.path}/$rel').create(recursive: true);
      } else if (entity is File) {
        final target = File('${dst.path}/$rel');
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
      }
    }
  }

  /// Deletes the adventure directory for [slug].
  Future<void> delete(String slug) async {
    final root = await _editRoot();
    final dir = Directory('${root.path}/$slug');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // --- internals ----------------------------------------------------------

  /// Assembles the LivingScroll.json document: form metadata on top, empty
  /// content collections, with any imported collections merged in.
  Map<String, dynamic> _buildDocument(Map<String, String> metadata) {
    return <String, dynamic>{
      'metadata': metadata,
      'images': <dynamic>[],
      'audio': <dynamic>[],
      'paths': <dynamic>[],
      'key_events': <dynamic>[],
      'notes': <dynamic>[],
      'gm_notes': <dynamic>[],
      'npcs': <dynamic>[],
      'scenes': <dynamic>[],
    };
  }

  /// The top-level object collections stamped `immutable: true` when a save is
  /// created. Mirrors [_buildDocument] minus `metadata`
  /// (not a collection of objects) — `bg_images` are files, not a collection.
  static const List<String> _stampCollections = [
    'images',
    'audio',
    'paths',
    'key_events',
    'notes',
    'gm_notes',
    'npcs',
    'scenes',
  ];

  /// Marks EVERY object of EVERY collection in [doc] `immutable: true` — the base
  /// content that existed when a save was created is frozen in the save-content
  /// editor. Mutates [doc] in place; a fresh copy from
  /// `{Adventures}` carries no flags yet, so this always sets `true`.
  static void _stampImmutable(Map doc) {
    for (final key in _stampCollections) {
      final list = doc[key];
      if (list is! List) continue;
      for (final item in list) {
        if (item is Map) item['immutable'] = true;
      }
    }
  }

  /// Crops the source to the cover region, scales it to the exact profile size,
  /// and writes it as JPG. Uses [crop] (a normalized 1:1.43 region selected in
  /// the crop step); falls back to a centered 1:1.43 crop when none is given.
  Future<void> _writeCover(
    String sourcePath,
    CoverCrop? crop,
    File target,
  ) async {
    final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
    if (decoded == null) return;

    final int x, y, cropW, cropH;
    if (crop != null) {
      cropW = (crop.width * decoded.width).round();
      cropH = (crop.height * decoded.height).round();
      x = (crop.left * decoded.width).round();
      y = (crop.top * decoded.height).round();
    } else {
      const targetRatio = coverWidth / coverHeight;
      final srcRatio = decoded.width / decoded.height;
      if (srcRatio > targetRatio) {
        cropH = decoded.height;
        cropW = (cropH * targetRatio).round();
      } else {
        cropW = decoded.width;
        cropH = (cropW / targetRatio).round();
      }
      x = (decoded.width - cropW) ~/ 2;
      y = (decoded.height - cropH) ~/ 2;
    }

    final cropped = img.copyCrop(
      decoded,
      x: x.clamp(0, decoded.width - 1),
      y: y.clamp(0, decoded.height - 1),
      width: cropW.clamp(1, decoded.width),
      height: cropH.clamp(1, decoded.height),
    );
    final scaled = img.copyResize(
      cropped,
      width: coverWidth,
      height: coverHeight,
    );
    await target.writeAsBytes(img.encodeJpg(scaled, quality: 90));
  }

  /// A filesystem-safe, unique directory name derived from the title.
  Future<String> _uniqueSlug(Directory root, String name) async {
    final base =
        name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '')
            .isEmpty
        ? 'adventure'
        : name
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
              .replaceAll(RegExp(r'^-+|-+$'), '');
    var slug = base;
    var n = 2;
    while (Directory('${root.path}/$slug').existsSync()) {
      slug = '$base-$n';
      n++;
    }
    return slug;
  }

  /// Decodes [json] to a JSON object, or `null` when missing/unreadable/not an
  /// object (an unreadable document is treated as invalid by the caller).
  Map? _decode(File json) {
    try {
      final decoded = jsonDecode(json.readAsStringSync());
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// `metadata.name` from an already-decoded document, or `null` when absent.
  String? _nameOf(Map? decoded) {
    final metadata = (decoded != null) ? decoded['metadata'] : null;
    final name = (metadata is Map) ? metadata['name'] : null;
    return (name is String && name.isNotEmpty) ? name : null;
  }

  File? _findCover(Directory dir) {
    for (final name in ['cover.png', 'cover.jpg', 'cover.jpeg']) {
      final f = File('${dir.path}/$name');
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// The completion time parsed from a `{Finished}` directory name's trailing move
  /// timestamp (`<saveName>-yyyymmddHHMMSS`, optionally `-<n>` for collisions, as
  /// written by [finishSave]/[_timestamp]), or null when the name carries none.
  DateTime? _finishedAtOf(String dirName) {
    final match = RegExp(r'(\d{14})(?:-\d+)?$').firstMatch(dirName);
    if (match == null) return null;
    final s = match.group(1)!;
    int at(int start, int len) => int.parse(s.substring(start, start + len));
    try {
      return DateTime(
        at(0, 4),
        at(4, 2),
        at(6, 2),
        at(8, 2),
        at(10, 2),
        at(12, 2),
      );
    } catch (_) {
      return null;
    }
  }

  /// The group recorded in a save dir's `group.json` (`{"group": "<group>"}`),
  /// or empty when absent/unreadable. Sync sibling of [readSaveGroup] for the
  /// per-tile summary listing.
  String _groupOf(Directory dir) {
    final file = File('${dir.path}/group.json');
    if (!file.existsSync()) return '';
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map && decoded['group'] is String) {
        return decoded['group'] as String;
      }
    } catch (_) {}
    return '';
  }
}
