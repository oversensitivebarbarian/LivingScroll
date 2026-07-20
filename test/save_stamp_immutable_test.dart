import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for save creation: `startSaveFromLibrary` stamps
/// `immutable: true` on EVERY object of EVERY collection in the new save's
/// LivingScroll.json, while leaving the source library
/// adventure untouched. Overwrite re-stamps from a fresh copy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_stamp_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  /// A library adventure with one object in every stamped collection.
  Map<String, dynamic> fullDocument() => {
    'metadata': {'name': 'Demo', 'version': '1', 'system': 'basic'},
    'images': [
      {'image_uuid': 'i1', 'name': 'Map'},
    ],
    'audio': [
      {'audio_uuid': 'a1', 'name': 'Theme'},
    ],
    'paths': [
      {'name': 'Red path', 'color': 'red', 'description': 'd'},
    ],
    'key_events': [
      {'key_event_uuid': 'k1', 'name': 'Alarm', 'state': 'unchecked'},
    ],
    'notes': [
      {'note_uuid': 'no1', 'note_name': 'Clue', 'note_content': 't'},
    ],
    'gm_notes': [
      {'gmnote_uuid': 'g1', 'gmnote_content': 'gm'},
    ],
    'npcs': [
      {'npc_uuid': 'n1', 'name': 'Guard', 'state': 'active'},
    ],
    'scenes': [
      {'scene_uuid': 's1', 'name': 'Room', 'scene_type': 'start'},
    ],
  };

  Future<void> seedAdventure(String dir, Map<String, dynamic> doc) async {
    final adv = Directory('${support.path}/Adventures/$dir');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(jsonEncode(doc));
  }

  Map<String, dynamic> readDoc(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  const collections = [
    'images',
    'audio',
    'paths',
    'key_events',
    'notes',
    'gm_notes',
    'npcs',
    'scenes',
  ];

  test('stamps immutable:true on every object of every collection', () async {
    await seedAdventure('demo', fullDocument());
    final saveName = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Wed',
    );
    expect(saveName, isNotNull);

    final saved = readDoc('${support.path}/Saves/$saveName/LivingScroll.json');
    for (final key in collections) {
      final list = saved[key] as List;
      expect(list, isNotEmpty, reason: '$key should have an object');
      for (final item in list) {
        expect(
          (item as Map)['immutable'],
          isTrue,
          reason: '$key object must be stamped immutable',
        );
      }
    }
    // metadata is not a collection of objects — never stamped.
    expect((saved['metadata'] as Map).containsKey('immutable'), isFalse);
  });

  test('the source library adventure is NOT stamped', () async {
    await seedAdventure('demo', fullDocument());
    await store.startSaveFromLibrary(adventureDir: 'demo', groupName: 'Wed');

    final src = readDoc('${support.path}/Adventures/demo/LivingScroll.json');
    for (final key in collections) {
      for (final item in (src[key] as List)) {
        expect(
          (item as Map).containsKey('immutable'),
          isFalse,
          reason: 'source $key must stay unstamped',
        );
      }
    }
  });

  test('overwrite re-stamps from a fresh copy', () async {
    await seedAdventure('demo', fullDocument());
    final name = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Wed',
    );

    // A second start with the same identity + overwrite copies fresh and stamps.
    final name2 = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Wed',
      overwrite: true,
    );
    expect(name2, name); // same save-name convention

    final saved = readDoc('${support.path}/Saves/$name2/LivingScroll.json');
    expect((saved['scenes'] as List).first['immutable'], isTrue);
    expect((saved['npcs'] as List).first['immutable'], isTrue);
  });

  test(
    'without overwrite an existing save is not touched (returns null)',
    () async {
      await seedAdventure('demo', fullDocument());
      final name = await store.startSaveFromLibrary(
        adventureDir: 'demo',
        groupName: 'Wed',
      );
      final again = await store.startSaveFromLibrary(
        adventureDir: 'demo',
        groupName: 'Wed',
      );
      expect(name, isNotNull);
      expect(again, isNull); // save exists, overwrite false
    },
  );
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
