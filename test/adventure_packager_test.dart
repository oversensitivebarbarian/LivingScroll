import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/adventure_packager.dart';

void main() {
  const packager = AdventurePackager();

  late Directory source;

  setUp(() {
    source = Directory.systemTemp.createTempSync('ls_pack_');
    File('${source.path}/LivingScroll.json')
        .writeAsStringSync('{"metadata":{"name":"Demo"}}');
    Directory('${source.path}/images/other').createSync(recursive: true);
    File('${source.path}/images/other/a1.png')
        .writeAsBytesSync(List<int>.generate(64, (i) => i));
  });

  tearDown(() {
    if (source.existsSync()) source.deleteSync(recursive: true);
  });

  test('the header round-trips through the zip comment', () {
    final header = AdventurePackager.headerFromMetadata(const {
      'name': 'The Demo',
      'version': '2.1.0',
      'system': 'basic',
      'author': 'Ada',
      'language': 'pl',
      'description': 'ignored',
    });
    final bytes = packager.pack(sourceDir: source, header: header);

    final read = packager.readHeader(bytes);
    expect(read, isNotNull);
    expect(read!['title'], 'The Demo');
    expect(read['version'], '2.1.0');
    expect(read['system'], 'basic');
    expect(read['author'], 'Ada');
    expect(read['language'], 'pl');
    // Only the cached header fields are stored (not the whole metadata).
    expect(read.containsKey('description'), isFalse);
  });

  test('the output is a standard zip containing every project file', () {
    final bytes = packager.pack(
      sourceDir: source,
      header: const {'title': 'Demo'},
    );

    // Decodable by a standard zip reader (no prepended header / preamble).
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('LivingScroll.json'));
    expect(names, contains('images/other/a1.png'));

    // The archived LivingScroll.json is the authoritative metadata source.
    final json = archive.files.firstWhere((f) => f.name == 'LivingScroll.json');
    expect(
        String.fromCharCodes(json.content as List<int>), contains('"Demo"'));
  });

  test('already-compressed media is stored, JSON is deflated', () {
    final bytes = packager.pack(
      sourceDir: source,
      header: const {'title': 'Demo'},
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final png = archive.files.firstWhere((f) => f.name.endsWith('a1.png'));
    final json = archive.files.firstWhere((f) => f.name == 'LivingScroll.json');
    // PNG is already compressed -> stored; JSON -> deflated.
    expect(png.compress, isFalse);
    expect(json.compress, isTrue);
  });

  test('readHeader returns null for non-archive bytes', () {
    expect(packager.readHeader(const [1, 2, 3, 4]), isNull);
  });

  test('unpack restores every file and directory of the packed tree', () {
    final bytes = packager.pack(
      sourceDir: source,
      header: const {'title': 'Demo'},
    );

    final dest = Directory.systemTemp.createTempSync('ls_unpack_');
    addTearDown(() {
      if (dest.existsSync()) dest.deleteSync(recursive: true);
    });
    packager.unpack(bytes: bytes, dest: dest);

    // The LivingScroll.json round-trips byte-for-byte.
    final json = File('${dest.path}/LivingScroll.json');
    expect(json.existsSync(), isTrue);
    expect(json.readAsStringSync(), '{"metadata":{"name":"Demo"}}');

    // Nested media is recreated under the same relative path, intact.
    final png = File('${dest.path}/images/other/a1.png');
    expect(png.existsSync(), isTrue);
    expect(png.readAsBytesSync(), List<int>.generate(64, (i) => i));
  });
}
