/// Validates a decoded `LivingScroll.json` against its expected shape.
/// There are TWO levels, differing only in how complete the
/// `metadata` must be (both always enforce the structural schema):
///
///   * [ProjectValidator] — a work-in-progress PROJECT (under `{Projects}`,
///     shown on the Create grid). Only `metadata.name` (title) and
///     `metadata.system` are required; the other metadata fields are optional
///     (an adventure freshly created from the form, with just a title + system,
///     is valid). Pass `supportedSystems` so a project whose stored system this
///     build cannot open is flagged invalid (its tile renders with a Block).
///
///   * [PublishedAdventureValidator] — a finished, PUBLISHED adventure. The
///     COMPLETE metadata set is required (a published file must carry every
///     field). Used by the Import-data flow, which validates an externally
///     prepared file before merging its collections.
///
/// Both checks are pragmatic and pure: the document must be an object with a
/// `metadata` object whose
/// required fields are non-empty strings (and whose optional fields, when
/// present, are strings), and every known content collection that is present
/// must be a JSON list. When `supportedSystems` is given, `metadata.system`
/// must additionally be one of those ids.
abstract class LivingScrollValidator {
  const LivingScrollValidator();

  /// Every `metadata` string field.
  static const List<String> allMetadata = [
    'name',
    'system',
    'version',
    'author',
    'description',
    'language',
    'content_warnings',
    'license',
  ];

  /// The metadata fields REQUIRED for a PUBLISHED adventure: every field in
  /// [allMetadata] EXCEPT `content_warnings`, which is OPTIONAL at every level (a
  /// content warning is not mandatory — an adventure may simply have none).
  static const List<String> publishedRequiredMetadata = [
    'name',
    'system',
    'version',
    'author',
    'description',
    'language',
    'license',
  ];

  /// Top-level content collections that, when present, must be JSON lists.
  static const List<String> collections = [
    'images',
    'audio',
    'paths',
    'key_events',
    'notes',
    'gm_notes',
    'npcs',
    'scenes',
  ];

  /// The metadata fields this level requires as NON-EMPTY strings. Fields in
  /// [allMetadata] not listed here are optional (must be a string when present).
  List<String> get requiredMetadata;

  /// Returns a list of human-readable errors; empty means the document is valid.
  ///
  /// When [supportedSystems] is non-null, `metadata.system` must be one of its
  /// ids (otherwise the adventure cannot be opened by this build).
  List<String> validate(Object? decoded, {Set<String>? supportedSystems}) {
    final errors = <String>[];

    if (decoded is! Map) {
      return ['Root must be a JSON object.'];
    }

    final metadata = decoded['metadata'];
    if (metadata is! Map) {
      errors.add('`metadata` must be an object.');
    } else {
      for (final field in allMetadata) {
        final value = metadata[field];
        if (requiredMetadata.contains(field)) {
          if (value is! String || value.isEmpty) {
            errors.add('`metadata.$field` must be a non-empty string.');
          }
        } else if (metadata.containsKey(field) && value is! String) {
          errors.add('`metadata.$field` must be a string when present.');
        }
      }
      if (supportedSystems != null) {
        final system = metadata['system'];
        if (system is! String || !supportedSystems.contains(system)) {
          errors.add('`metadata.system` "$system" is not a supported system.');
        }
      }
    }

    for (final key in collections) {
      if (decoded.containsKey(key) && decoded[key] is! List) {
        errors.add('`$key` must be a list.');
      }
    }

    return errors;
  }

  bool isValid(Object? decoded, {Set<String>? supportedSystems}) =>
      validate(decoded, supportedSystems: supportedSystems).isEmpty;
}

/// Validates a work-in-progress PROJECT: only the title (`name`) and `system`
/// are required; every other metadata field is optional. See
/// [LivingScrollValidator].
class ProjectValidator extends LivingScrollValidator {
  const ProjectValidator();

  @override
  List<String> get requiredMetadata => const ['name', 'system'];
}

/// Validates a PUBLISHED adventure: the complete metadata set is required —
/// EXCEPT `content_warnings`, which stays optional. See [LivingScrollValidator].
class PublishedAdventureValidator extends LivingScrollValidator {
  const PublishedAdventureValidator();

  @override
  List<String> get requiredMetadata =>
      LivingScrollValidator.publishedRequiredMetadata;
}
