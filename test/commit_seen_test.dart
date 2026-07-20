import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Unit coverage for the `seen` runtime flag: `commitSaveProgress` marks the
/// notes / images passed in [seenNoteUuids] / [seenImageUuids] with `seen: true`
/// in the save's LivingScroll.json, leaving the rest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_seen_test');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  const saveName = 'Demo-1-Team';

  Future<void> seedSave() async {
    final dir = Directory('${support.path}/Saves/$saveName');
    await dir.create(recursive: true);
    await File('${dir.path}/LivingScroll.json').writeAsString(
      jsonEncode({
        'metadata': {'name': 'Demo', 'version': '1', 'system': 'basic'},
        'images': [
          {'image_uuid': 'i1', 'name': 'Map', 'seen': false},
          {'image_uuid': 'i2', 'name': 'Sketch', 'seen': false},
        ],
        'notes': [
          {
            'note_uuid': 'n1',
            'note_name': 'Clue',
            'note_content': 'x',
            'seen': false,
          },
          {
            'note_uuid': 'n2',
            'note_name': 'Aside',
            'note_content': 'y',
            'seen': false,
          },
        ],
        'key_events': [],
        'scenes': [
          {'scene_uuid': 's1', 'name': 'Opening', 'scene_type': 'start'},
        ],
      }),
    );
  }

  Map<String, dynamic> readDoc() =>
      jsonDecode(
            File(
              '${support.path}/Saves/$saveName/LivingScroll.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  bool? seenOf(List list, String idKey, String id) {
    for (final e in list) {
      if (e is Map && e[idKey] == id) return e['seen'] as bool?;
    }
    return null;
  }

  test('marks only the passed notes / images as seen', () async {
    await seedSave();
    await store.commitSaveProgress(
      saveName,
      checkedKeyEvents: const {},
      visitedSceneUuid: 's1',
      seenNoteUuids: {'n1'},
      seenImageUuids: {'i1'},
    );

    final doc = readDoc();
    expect(seenOf(doc['notes'] as List, 'note_uuid', 'n1'), isTrue);
    expect(seenOf(doc['notes'] as List, 'note_uuid', 'n2'), isFalse);
    expect(seenOf(doc['images'] as List, 'image_uuid', 'i1'), isTrue);
    expect(seenOf(doc['images'] as List, 'image_uuid', 'i2'), isFalse);
  });

  test('an empty seen set leaves every flag untouched', () async {
    await seedSave();
    await store.commitSaveProgress(
      saveName,
      checkedKeyEvents: const {},
      visitedSceneUuid: 's1',
    );

    final doc = readDoc();
    expect(seenOf(doc['notes'] as List, 'note_uuid', 'n1'), isFalse);
    expect(seenOf(doc['images'] as List, 'image_uuid', 'i1'), isFalse);
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
