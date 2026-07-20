import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for the adventure launch screen's new-game "Import progress"
/// (`ProjectsStore.importSaveProgress` — key_events, npcs and gm_notes) and the
/// resume-mode editable roster persistence (`ProjectsStore.writeSavePlayers`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_import_progress');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  /// Writes a `LivingScroll.json` under [root]/[dir] with the given collections.
  Future<void> seedDoc(
    String root,
    String dir, {
    List<Map<String, dynamic>> keyEvents = const [],
    List<Map<String, dynamic>> npcs = const [],
    List<Map<String, dynamic>> gmNotes = const [],
    List<Map<String, dynamic>> scenes = const [],
  }) async {
    final d = Directory('${support.path}/$root/$dir');
    await d.create(recursive: true);
    await File('${d.path}/LivingScroll.json').writeAsString(jsonEncode({
      'metadata': {'name': dir, 'system': 'basic'},
      'key_events': keyEvents,
      'npcs': npcs,
      'gm_notes': gmNotes,
      'scenes': scenes,
    }));
  }

  Map<String, dynamic> savedDoc(String saveName) {
    final f = File('${support.path}/Saves/$saveName/LivingScroll.json');
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  List<dynamic> savedKeyEvents(String saveName) =>
      savedDoc(saveName)['key_events'] as List;
  List<dynamic> savedNpcs(String saveName) => savedDoc(saveName)['npcs'] as List;
  List<dynamic> savedGmNotes(String saveName) =>
      savedDoc(saveName)['gm_notes'] as List;

  group('importSaveProgress key_events', () {
    test('adopts the finished save state for an existing uuid', () async {
      // The new save has the event unchecked; the finished save has it checked.
      await seedDoc('Saves', 'new', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'unchecked'},
      ]);
      await seedDoc('Finished', 'done-1', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'checked'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final events = savedKeyEvents('new');
      expect(events.length, 1);
      expect(events[0]['key_event_uuid'], 'ke1');
      expect(events[0]['state'], 'checked'); // adopted from the finished save
    });

    test('creates a missing uuid together with its state', () async {
      // The new save lacks ke2 entirely; it is created with its finished state.
      await seedDoc('Saves', 'new', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'unchecked'},
      ]);
      await seedDoc('Finished', 'done-1', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'checked'},
        {'key_event_uuid': 'ke2', 'name': 'Found map', 'state': 'checked'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final events = savedKeyEvents('new');
      expect(events.length, 2);
      final byUuid = {for (final e in events) e['key_event_uuid']: e};
      expect(byUuid['ke1']!['state'], 'checked');
      expect(byUuid['ke2'], isNotNull); // created
      expect(byUuid['ke2']!['name'], 'Found map'); // whole event copied
      expect(byUuid['ke2']!['state'], 'checked'); // with its state
    });

    test('is a no-op when the finished dir is missing', () async {
      await seedDoc('Saves', 'new', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'unchecked'},
      ]);

      await store.importSaveProgress(saveName: 'new', fromFinishedDir: 'nope');

      final events = savedKeyEvents('new');
      expect(events.length, 1);
      expect(events[0]['state'], 'unchecked'); // untouched
    });

    test('creates the key_events list when the new save has none', () async {
      // A save whose document carries no key_events collection at all.
      final d = Directory('${support.path}/Saves/bare');
      await d.create(recursive: true);
      await File('${d.path}/LivingScroll.json').writeAsString(jsonEncode({
        'metadata': {'name': 'bare', 'system': 'basic'},
        'scenes': [],
      }));
      await seedDoc('Finished', 'done-1', keyEvents: [
        {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'checked'},
      ]);

      await store.importSaveProgress(
          saveName: 'bare', fromFinishedDir: 'done-1');

      final events = savedKeyEvents('bare');
      expect(events.length, 1);
      expect(events[0]['state'], 'checked');
    });
  });

  group('importSaveProgress npcs', () {
    test('adopts the finished save state for an existing uuid', () async {
      // The new save's NPC is active; the finished save has it inactive.
      await seedDoc('Saves', 'new', npcs: [
        {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'active'},
      ]);
      await seedDoc('Finished', 'done-1', npcs: [
        {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'inactive'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final npcs = savedNpcs('new');
      expect(npcs.length, 1);
      expect(npcs[0]['npc_uuid'], 'p1');
      expect(npcs[0]['state'], 'inactive'); // adopted from the finished save
    });

    test('creates a missing uuid together with its state', () async {
      await seedDoc('Saves', 'new', npcs: [
        {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'active'},
      ]);
      await seedDoc('Finished', 'done-1', npcs: [
        {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'active'},
        {'npc_uuid': 'p2', 'name': 'Duke', 'state': 'inactive'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final npcs = savedNpcs('new');
      expect(npcs.length, 2);
      final byUuid = {for (final n in npcs) n['npc_uuid']: n};
      expect(byUuid['p1']!['state'], 'active');
      expect(byUuid['p2'], isNotNull); // created
      expect(byUuid['p2']!['name'], 'Duke'); // whole npc copied
      expect(byUuid['p2']!['state'], 'inactive'); // with its state
    });

    test('creates the npcs list when the new save has none', () async {
      final d = Directory('${support.path}/Saves/bare');
      await d.create(recursive: true);
      await File('${d.path}/LivingScroll.json').writeAsString(jsonEncode({
        'metadata': {'name': 'bare', 'system': 'basic'},
        'scenes': [],
      }));
      await seedDoc('Finished', 'done-1', npcs: [
        {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'inactive'},
      ]);

      await store.importSaveProgress(
          saveName: 'bare', fromFinishedDir: 'done-1');

      final npcs = savedNpcs('bare');
      expect(npcs.length, 1);
      expect(npcs[0]['state'], 'inactive');
    });
  });

  group('importSaveProgress gm_notes', () {
    test('copies an absent gmnote and links it to EVERY scene', () async {
      await seedDoc('Saves', 'new', scenes: [
        {'scene_uuid': 's1', 'name': 'Cave', 'scene_type': 'start'},
        {'scene_uuid': 's2', 'name': 'Tower', 'scene_type': 'standard'},
      ]);
      await seedDoc('Finished', 'done-1', gmNotes: [
        {'gmnote_uuid': 'g1', 'gmnote_content': 'Duke is secretly the villain.'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final notes = savedGmNotes('new');
      expect(notes.length, 1);
      expect(notes[0]['gmnote_uuid'], 'g1');
      expect(notes[0]['gmnote_content'], 'Duke is secretly the villain.');

      final scenes = savedDoc('new')['scenes'] as List;
      for (final s in scenes) {
        expect((s as Map)['gmnotes'], contains('g1')); // linked to EVERY scene
      }
    });

    test('a present gmnote uuid is left untouched (no duplicate, no relink)',
        () async {
      await seedDoc('Saves', 'new', scenes: [
        {
          'scene_uuid': 's1',
          'name': 'Cave',
          'scene_type': 'start',
          'gmnotes': ['g1'],
        },
      ], gmNotes: [
        {'gmnote_uuid': 'g1', 'gmnote_content': 'Original content.'},
      ]);
      await seedDoc('Finished', 'done-1', gmNotes: [
        {'gmnote_uuid': 'g1', 'gmnote_content': 'Different content from source.'},
      ]);

      await store.importSaveProgress(
          saveName: 'new', fromFinishedDir: 'done-1');

      final notes = savedGmNotes('new');
      expect(notes.length, 1); // not duplicated
      expect(notes[0]['gmnote_content'], 'Original content.'); // untouched

      final scenes = savedDoc('new')['scenes'] as List;
      final links = (scenes[0] as Map)['gmnotes'] as List;
      expect(links, ['g1']); // not relinked/duplicated
    });

    test('creates the gm_notes list when the new save has none', () async {
      final d = Directory('${support.path}/Saves/bare');
      await d.create(recursive: true);
      await File('${d.path}/LivingScroll.json').writeAsString(jsonEncode({
        'metadata': {'name': 'bare', 'system': 'basic'},
        'scenes': [
          {'scene_uuid': 's1', 'name': 'Cave', 'scene_type': 'start'},
        ],
      }));
      await seedDoc('Finished', 'done-1', gmNotes: [
        {'gmnote_uuid': 'g1', 'gmnote_content': 'Note.'},
      ]);

      await store.importSaveProgress(
          saveName: 'bare', fromFinishedDir: 'done-1');

      final notes = savedGmNotes('bare');
      expect(notes.length, 1);
      final scenes = savedDoc('bare')['scenes'] as List;
      expect((scenes[0] as Map)['gmnotes'], contains('g1'));
    });
  });

  test('is a no-op when the finished dir is missing (all collections)',
      () async {
    await seedDoc('Saves', 'new', keyEvents: [
      {'key_event_uuid': 'ke1', 'name': 'Met duke', 'state': 'unchecked'},
    ], npcs: [
      {'npc_uuid': 'p1', 'name': 'Guard', 'state': 'active'},
    ], gmNotes: [
      {'gmnote_uuid': 'g1', 'gmnote_content': 'Untouched.'},
    ]);

    await store.importSaveProgress(saveName: 'new', fromFinishedDir: 'nope');

    expect(savedKeyEvents('new')[0]['state'], 'unchecked');
    expect(savedNpcs('new')[0]['state'], 'active');
    expect(savedGmNotes('new')[0]['gmnote_content'], 'Untouched.');
  });

  group('writeSavePlayers', () {
    Future<void> seedSaveGroup(String saveName, Object groupJson) async {
      final d = Directory('${support.path}/Saves/$saveName');
      await d.create(recursive: true);
      await File('${d.path}/group.json').writeAsString(jsonEncode(groupJson));
    }

    Map<String, dynamic> readGroupJson(String saveName) {
      final f = File('${support.path}/Saves/$saveName/group.json');
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }

    test('rewrites the roster while preserving the group name', () async {
      await seedSaveGroup('save', {
        'group': 'Team A',
        'players': ['Alice', 'Bob'],
      });

      await store.writeSavePlayers('save', ['Alice', 'Bob', 'Cara']);

      final json = readGroupJson('save');
      expect(json['group'], 'Team A'); // group preserved
      expect(json['players'], ['Alice', 'Bob', 'Cara']);
    });

    test('normalizes the roster (trims, drops blanks, dedupes, keeps order)',
        () async {
      await seedSaveGroup('save', {'group': 'Team A', 'players': <String>[]});

      await store
          .writeSavePlayers('save', [' Dana ', '', 'Erin', '   ', 'Dana']);

      expect(readGroupJson('save')['players'], ['Dana', 'Erin']);
    });

    test('removing every player round-trips as an empty roster', () async {
      await seedSaveGroup('save', {
        'group': 'Team A',
        'players': ['Alice'],
      });

      await store.writeSavePlayers('save', []);

      final json = readGroupJson('save');
      expect(json['group'], 'Team A');
      expect(json['players'], isEmpty);
    });

    test('is a no-op when the save directory is absent', () async {
      await store.writeSavePlayers('ghost', ['Alice']);
      expect(
          File('${support.path}/Saves/ghost/group.json').existsSync(), isFalse);
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
