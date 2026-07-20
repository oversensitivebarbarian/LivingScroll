import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Store-level coverage for `ProjectsStore.exportLatex`:
/// reads the library adventure + its images and produces the ZIP bytes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ProjectsStore();
  late Directory support;
  PathProviderPlatform? previous;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ls_latex_export');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
  });

  tearDown(() async {
    if (previous != null) PathProviderPlatform.instance = previous!;
    if (support.existsSync()) await support.delete(recursive: true);
  });

  /// Writes a byte file, creating parent directories.
  Future<void> writeFile(String rel, List<int> bytes) async {
    final f = File('${support.path}/Adventures/demo/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
  }

  /// Seeds `{Adventures}/demo` with a doc + SOME image files (bg1 is left out on
  /// purpose to check that a missing image is skipped).
  Future<void> seed() async {
    await writeFile(
      'LivingScroll.json',
      utf8.encode(
        jsonEncode({
          'metadata': {
            'name': 'Demo',
            'version': '1',
            'system': '7thsea2e',
            'language': 'en',
          },
          'images': [
            {'image_uuid': 'im1', 'name': 'Map'},
          ],
          'npcs': [
            {
              'npc_uuid': 'n1',
              'name': 'Guard',
              'full_image': 'f1',
              'description': 'A sentry.',
              'backstory': 'Once a soldier.',
            },
          ],
          'scenes': [
            {
              'scene_uuid': 's1',
              'name': 'Opening',
              'scene_type': 'start',
              'bg_image': 'bg1', // file NOT created -> skipped
              'images': ['im1'],
              'npcs': ['Guard'],
            },
          ],
        }),
      ),
    );
    await writeFile('cover.png', [1, 2, 3]);
    await writeFile('images/npcs/f1.png', [4, 5, 6]);
    await writeFile('images/other/im1.png', [7, 8, 9]);
  }

  test('produces a ZIP with main.tex + assets for the present files', () async {
    await seed();
    final result = await store.exportLatex('demo');
    expect(result, isNotNull);
    expect(result!.archiveBytes, isNotEmpty);
    expect(result.suggestedFileName, 'Demo-latex.zip');

    final names = ZipDecoder()
        .decodeBytes(result.archiveBytes)
        .files
        .map((f) => f.name)
        .toSet();
    expect(names, contains('main.tex'));
    expect(names, contains('assets/cover.png'));
    expect(names, contains('assets/npcfull_f1.png'));
    expect(names, contains('assets/img_im1.png'));
    // bg1 has no file on disk -> not packaged.
    expect(names, isNot(contains('assets/bg_bg1.png')));
  });

  test('the packaged main.tex references the adventure content', () async {
    await seed();
    final result = await store.exportLatex('demo');
    final archive = ZipDecoder().decodeBytes(result!.archiveBytes);
    final tex = archive.files.firstWhere((f) => f.name == 'main.tex');
    final source = utf8.decode(tex.content as List<int>);
    expect(source, contains(r'\chapter{Scenes}'));
    expect(
      source,
      contains(r'\section[{Opening (opening scene)}]{Opening (opening scene)'),
    );
    expect(source, contains(r'\chapter{NPCs}'));
    expect(source, contains(r'\hyperref[npc:n1]{'));
    // The missing background emits no graphic.
    expect(source, isNot(contains('bg_bg1.png')));
  });

  test('returns null for a missing adventure directory', () async {
    expect(await store.exportLatex('nope'), isNull);
  });

  test('a basic adventure exports main.tex + the adventure images only — the '
      'plain unbranded book layout, same as every other system, no vendored '
      'theme files', () async {
    await seed(); // seeds cover + NPC/scene images on disk — all now package
    // Rewrite the doc as a `basic` adventure (the seed uses 7thsea2e).
    await writeFile(
      'LivingScroll.json',
      utf8.encode(
        jsonEncode({
          'metadata': {
            'name': 'Demo',
            'version': '1',
            'system': 'basic',
            'language': 'en',
          },
          'images': [
            {'image_uuid': 'im1', 'name': 'Map'},
          ],
          'npcs': [
            {'npc_uuid': 'n1', 'name': 'Guard', 'full_image': 'f1'},
          ],
          'scenes': [
            {
              'scene_uuid': 's1',
              'name': 'Opening',
              'scene_type': 'start',
              'images': ['im1'],
              'npcs': ['Guard'],
            },
          ],
        }),
      ),
    );

    final result = await store.exportLatex('demo');

    expect(result, isNotNull);
    final files = ZipDecoder().decodeBytes(result!.archiveBytes).files;
    final names = files.map((f) => f.name).toSet();
    // Only main.tex + the adventure's own images — no vendored class/font/art.
    expect(names, {
      'main.tex',
      'assets/cover.png',
      'assets/npcfull_f1.png',
      'assets/img_im1.png',
    });
    final tex = utf8.decode(
      files.firstWhere((f) => f.name == 'main.tex').content as List<int>,
    );
    expect(tex, contains(r'\documentclass[11pt,a4paper,openany]{book}'));
    expect(tex, contains(r'\includegraphics'));
  });

  test('a 7thsea2e adventure uses the SAME plain book layout as every other '
      'system — no branded theme files', () async {
    await writeFile(
      'LivingScroll.json',
      utf8.encode(
        jsonEncode({
          'metadata': {
            'name': 'Reef',
            'version': '1',
            'system': '7thsea2e',
            'language': 'en',
          },
          'scenes': [
            {'scene_uuid': 's1', 'name': 'Opening', 'scene_type': 'start'},
          ],
          'npcs': [],
        }),
      ),
    );

    final result = await store.exportLatex('demo');

    expect(result, isNotNull);
    final archive = ZipDecoder().decodeBytes(result!.archiveBytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {'main.tex'});
    final tex = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'main.tex').content
          as List<int>,
    );
    expect(tex, contains(r'\documentclass[11pt,a4paper,openany]{book}'));
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
