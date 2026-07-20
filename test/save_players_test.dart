import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for the players (PC) roster in a save's `group.json`:
/// `startSaveFromLibrary` persists a normalized roster and
/// `readSavePlayers` reads it back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_players_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  /// Seeds a minimal library adventure at `{Adventures}/<dir>/LivingScroll.json`.
  Future<void> seedAdventure(
    String dir, {
    String name = 'Demo',
    String version = '1',
  }) async {
    final adv = Directory('${support.path}/Adventures/$dir');
    await adv.create(recursive: true);
    await File('${adv.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {'name': name, 'version': version, 'system': 'basic'},
        'scenes': [],
      }),
    );
  }

  Map<String, dynamic> readGroupJson(String saveName) {
    final f = File('${support.path}/Saves/$saveName/group.json');
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  test('startSaveFromLibrary writes a normalized players roster', () async {
    await seedAdventure('demo');
    final saveName = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Wednesday',
      // Whitespace-padded, an empty, a blank and a duplicate — all normalized.
      players: [' Alice ', 'Bob', '', '   ', 'Alice'],
    );
    expect(saveName, isNotNull);

    final json = readGroupJson(saveName!);
    expect(json['group'], 'Wednesday');
    expect(json['players'], ['Alice', 'Bob']); // trimmed, deduped, order kept
  });

  test('readSavePlayers reads the persisted roster', () async {
    await seedAdventure('demo');
    final saveName = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Wednesday',
      players: ['Alice', 'Bob', 'Cara'],
    );

    expect(await store.readSavePlayers(saveName!), ['Alice', 'Bob', 'Cara']);
  });

  test('empty players list is allowed and round-trips as empty', () async {
    await seedAdventure('demo');
    final saveName = await store.startSaveFromLibrary(
      adventureDir: 'demo',
      groupName: 'Solo',
    );

    expect(readGroupJson(saveName!)['players'], isEmpty);
    expect(await store.readSavePlayers(saveName), isEmpty);
  });

  test(
    'readSavePlayers returns empty when group.json has no players key',
    () async {
      final save = Directory('${support.path}/Saves/legacy');
      await save.create(recursive: true);
      await File(
        '${save.path}/group.json',
      ).writeAsString(jsonEncode({'group': 'Old'}));

      expect(await store.readSavePlayers('legacy'), isEmpty);
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
