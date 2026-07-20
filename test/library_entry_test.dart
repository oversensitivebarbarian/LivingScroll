import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/projects_store.dart';

void main() {
  LibraryEntry e({
    String title = 'T',
    String version = '1',
    String system = 'basic',
    String author = 'A',
    String language = 'en',
    String dir = '',
  }) =>
      LibraryEntry(
        title: title,
        version: version,
        system: system,
        author: author,
        language: language,
        dir: dir,
      );

  test('sameIdentity ignores the directory', () {
    expect(e(dir: 'X').sameIdentity(e(dir: 'Y')), isTrue);
  });

  test('sameIdentity is false when any identity field differs', () {
    expect(e().sameIdentity(e(title: 'U')), isFalse);
    expect(e().sameIdentity(e(version: '2')), isFalse);
    expect(e().sameIdentity(e(system: '7thsea2e')), isFalse);
    expect(e().sameIdentity(e(author: 'B')), isFalse);
    expect(e().sameIdentity(e(language: 'pl')), isFalse);
  });

  test('fromMetadata reads the five identity fields (+ dir)', () {
    final entry = LibraryEntry.fromMetadata(
      {
        'name': 'Demo',
        'version': '1.0.0',
        'system': 'basic',
        'author': 'Ada',
        'language': 'pl',
        'description': 'ignored',
      },
      dir: 'Demo',
    );
    expect(entry.title, 'Demo');
    expect(entry.version, '1.0.0');
    expect(entry.system, 'basic');
    expect(entry.author, 'Ada');
    expect(entry.language, 'pl');
    expect(entry.dir, 'Demo');
  });

  test('json round-trips (identity + dir)', () {
    final original = e(dir: 'D');
    final back = LibraryEntry.fromJson(original.toJson());
    expect(back.sameIdentity(original), isTrue);
    expect(back.dir, 'D');
  });
}
