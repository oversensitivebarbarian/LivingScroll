import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/create/game_systems.dart';
import 'package:living_scroll/services/living_scroll_validator.dart';

/// A complete, schema-valid document; [system] is the metadata.system value.
Map<String, dynamic> _full({String system = 'basic'}) => {
      'metadata': <String, dynamic>{
        'name': 'Demo',
        'system': system,
        'version': '1.0.0',
        'author': 'A',
        'description': 'd',
        'language': 'en',
        'content_warnings': 'none',
        'license': 'x',
      },
      'images': [],
      'audio': [],
      'paths': [],
      'key_events': [],
      'notes': [],
      'gm_notes': [],
      'npcs': [],
      'scenes': [],
    };

/// A project document with only title + system; the rest empty (as the
/// new-adventure form writes it).
Map<String, dynamic> _minimal({String system = 'basic'}) => {
      'metadata': <String, dynamic>{
        'name': 'Demo',
        'system': system,
        'version': '',
        'author': '',
        'description': '',
        'language': '',
        'content_warnings': '',
        'license': '',
      },
      'images': [],
    };

void main() {
  const project = ProjectValidator();
  const published = PublishedAdventureValidator();

  group('shared structural checks', () {
    test('root must be a JSON object', () {
      expect(project.isValid('nope'), isFalse);
      expect(published.isValid(<dynamic>[]), isFalse);
    });

    test('a present collection that is not a list is invalid', () {
      final doc = _full();
      doc['notes'] = {'not': 'a list'};
      expect(project.isValid(doc), isFalse);
      expect(published.isValid(doc), isFalse);
    });

    test('an optional metadata field that is not a string is invalid', () {
      final doc = _minimal();
      (doc['metadata'] as Map)['author'] = 42; // present but not a string
      expect(project.isValid(doc), isFalse);
    });
  });

  group('ProjectValidator (title + system)', () {
    test('a minimal project (title + system, rest empty) is valid', () {
      expect(project.isValid(_minimal()), isTrue);
      expect(project.validate(_minimal()), isEmpty);
    });

    test('a full document is also valid', () {
      expect(project.isValid(_full()), isTrue);
    });

    test('missing title is invalid', () {
      final doc = _minimal();
      (doc['metadata'] as Map).remove('name');
      expect(project.isValid(doc), isFalse);
    });

    test('missing system is invalid', () {
      final doc = _minimal();
      (doc['metadata'] as Map)['system'] = '';
      expect(project.isValid(doc), isFalse);
    });

    test('an unsupported system fails when systems are checked', () {
      expect(project.isValid(_minimal(system: 'generic')), isTrue); // not checked
      expect(
          project.isValid(_minimal(system: 'generic'),
              supportedSystems: GameSystems.ids),
          isFalse);
      expect(
          project.isValid(_minimal(system: 'basic'),
              supportedSystems: GameSystems.ids),
          isTrue);
    });
  });

  group('PublishedAdventureValidator (complete metadata)', () {
    test('a full document is valid', () {
      expect(published.isValid(_full()), isTrue);
    });

    test('a minimal project is NOT publishable (optional fields empty)', () {
      expect(published.isValid(_minimal()), isFalse);
    });

    test('any single empty metadata field fails publication', () {
      final doc = _full();
      (doc['metadata'] as Map)['license'] = '';
      expect(published.isValid(doc), isFalse);
    });

    test('content_warnings is optional — empty or absent still validates', () {
      final empty = _full();
      (empty['metadata'] as Map)['content_warnings'] = '';
      expect(published.isValid(empty), isTrue);

      final absent = _full();
      (absent['metadata'] as Map).remove('content_warnings');
      expect(published.isValid(absent), isTrue);
    });
  });

  test('GameSystems supports Basic RPG and 7th Sea 2e', () {
    expect(GameSystems.ids, {'basic', '7thsea2e'});
    expect(GameSystems.catalogue['basic']!.name, 'Basic RPG');
    expect(GameSystems.catalogue['7thsea2e']!.name, '7th Sea 2nd Edition');
    // Both are selectable for new adventures.
    expect(GameSystems.names.keys, containsAll({'basic', '7thsea2e'}));
  });
}
