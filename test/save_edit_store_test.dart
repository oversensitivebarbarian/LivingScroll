import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for save-content editing: a `ProjectsStore(editBase: saves)` resolves
/// every per-adventure editor op under `{Saves}/<name>` (not `{Projects}`), and a
/// read→write cycle preserves the save's runtime fields
/// (visited/seen/state/immutable) and other collections.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const projects = ProjectsStore();
  const saveStore = ProjectsStore(editBase: AdventureBase.saves);
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_save_edit_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  Future<void> writeJson(String path, Map<String, dynamic> doc) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(doc));
  }

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('read resolves the save under {Saves}, not {Projects}', () async {
    await writeJson('${support.path}/Saves/game1/LivingScroll.json', {
      'metadata': {'name': 'S', 'system': 'basic'},
      'scenes': [
        {
          'scene_uuid': 's1',
          'name': 'Room',
          'immutable': true,
          'visited': true,
        },
      ],
    });
    // A project of the same slug must NOT be what the save store reads.
    await writeJson('${support.path}/Projects/game1/LivingScroll.json', {
      'metadata': {'name': 'PROJECT', 'system': 'basic'},
      'scenes': [],
    });

    final fromSave = await saveStore.read('game1');
    expect((fromSave!['metadata'] as Map)['name'], 'S');
    expect((fromSave['scenes'] as List).single['immutable'], isTrue);

    // The default (projects) store reads the project instead.
    final fromProject = await projects.read('game1');
    expect((fromProject!['metadata'] as Map)['name'], 'PROJECT');
  });

  test(
    'writeScenes writes under {Saves} and preserves other collections',
    () async {
      await writeJson('${support.path}/Saves/game1/LivingScroll.json', {
        'metadata': {'name': 'S', 'system': 'basic'},
        'gm_notes': [
          {'gmnote_uuid': 'g1', 'gmnote_content': 'gm', 'immutable': true},
        ],
        'scenes': [
          {'scene_uuid': 's1', 'name': 'Room', 'immutable': true},
        ],
      });

      // Add a new (mutable) scene alongside the immutable base scene.
      await saveStore.writeScenes('game1', [
        {'scene_uuid': 's1', 'name': 'Room', 'immutable': true},
        {'scene_uuid': 's2', 'name': 'New'}, // mutable, no flag
      ]);

      final saved = readJson('${support.path}/Saves/game1/LivingScroll.json');
      expect((saved['scenes'] as List).length, 2);
      expect((saved['scenes'] as List)[0]['immutable'], isTrue);
      expect((saved['scenes'] as List)[1].containsKey('immutable'), isFalse);
      // Other collections untouched.
      expect((saved['gm_notes'] as List).single['gmnote_uuid'], 'g1');
      // {Projects} was never written.
      expect(
        File('${support.path}/Projects/game1/LivingScroll.json').existsSync(),
        isFalse,
      );
    },
  );

  test('media paths resolve under {Saves}/<name>', () async {
    expect(
      await saveStore.imagesOtherPath('game1'),
      '${support.path}/Saves/game1/images/other',
    );
    expect(
      await saveStore.audioPath('game1'),
      '${support.path}/Saves/game1/audio',
    );
    expect(
      await saveStore.bgImagesPath('game1'),
      '${support.path}/Saves/game1/images/bg_images',
    );
    // The default store still resolves under {Projects}.
    expect(
      await projects.imagesOtherPath('game1'),
      '${support.path}/Projects/game1/images/other',
    );
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
