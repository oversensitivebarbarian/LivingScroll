import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for `party.json` persistence in a save:
/// `writePartyState` / `readPartyState` round-trip, and the absent/corrupt
/// fallbacks that make a resume drop back to a single track.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_party_state_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  Future<void> makeSaveDir(String name) async {
    await Directory('${support.path}/Saves/$name').create(recursive: true);
  }

  final snapshot = {
    'tracks': [
      {
        'id': 't-root',
        'current_scene_uuid': 's2',
        'pc_names': ['Alice'],
        'focused': true,
      },
      {
        'id': 't-2',
        'current_scene_uuid': 'adhoc-x',
        'pc_names': ['Bob'],
        'focused': false,
      },
    ],
    'adhoc_scenes': [
      {
        'scene_uuid': 'adhoc-x',
        'name': 'Ambush',
        'next_scenes': ['s4'],
      },
    ],
  };

  test(
    'writePartyState then readPartyState round-trips the snapshot',
    () async {
      await makeSaveDir('save1');
      await store.writePartyState('save1', snapshot);

      expect(
        File('${support.path}/Saves/save1/party.json').existsSync(),
        isTrue,
      );
      final read = await store.readPartyState('save1');
      expect(read, snapshot);
    },
  );

  test('readPartyState returns null when party.json is absent', () async {
    await makeSaveDir('fresh');
    expect(await store.readPartyState('fresh'), isNull);
  });

  test('writePartyState tolerates a missing save dir (no throw)', () async {
    // No save dir created — best-effort write must not throw, and read is null.
    await store.writePartyState('ghost', snapshot);
    expect(await store.readPartyState('ghost'), isNull);
  });

  test('readPartyState returns null on corrupt json', () async {
    await makeSaveDir('broken');
    await File(
      '${support.path}/Saves/broken/party.json',
    ).writeAsString('{ this is not json');
    expect(await store.readPartyState('broken'), isNull);
  });

  test('readFinishedPartyState reads party.json from {Finished}', () async {
    final fin = Directory('${support.path}/Finished/FinOne');
    await fin.create(recursive: true);
    await File('${fin.path}/party.json').writeAsString(
      '{"tracks":[],"adhoc_scenes":'
      '[{"scene_uuid":"adhoc-1","name":"Ambush","next_scenes":["s4"]}]}',
    );

    final read = await store.readFinishedPartyState('FinOne');
    expect((read?['adhoc_scenes'] as List).first, {
      'scene_uuid': 'adhoc-1',
      'name': 'Ambush',
      'next_scenes': ['s4'],
    });
    expect(await store.readFinishedPartyState('missing'), isNull);
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
