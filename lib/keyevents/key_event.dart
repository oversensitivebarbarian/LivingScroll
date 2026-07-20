/// One key event: a stable [uuid]
/// (`key_event_uuid`, minted on creation) and a [name] (UNIQUE — the value other
/// entities reference, e.g. a note's `visibility_rules.key_events` or a scene's
/// `key_events`). [name] is the only authored field.
///
/// [checked] mirrors the `state` field, which is app-managed runtime state
/// (gameplay), not edited in the authoring form; it is preserved on round-trip
/// and defaults to unchecked for a new event.
class KeyEvent {
  KeyEvent({
    required this.uuid,
    required this.name,
    this.checked = false,
    this.immutable = false,
  });

  /// `key_event_uuid` — a stable identifier generated when the event is created.
  /// References to the event are by [name], not by this; the uuid is the durable
  /// identity that survives a rename.
  final String uuid;

  /// The event's name — unique within the document's `key_events`.
  String name;

  /// `state == "checked"` (app-managed; defaults to unchecked).
  bool checked;

  /// Runtime save-only flag: part of the immutable base content stamped at
  /// save creation — frozen in the save-edit editor. Absent/`false` in
  /// projects and exports; serialized only when `true`.
  bool immutable;

  factory KeyEvent.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    return KeyEvent(
      uuid: s(json['key_event_uuid']),
      name: s(json['name']),
      checked: json['state'] == 'checked',
      immutable: json['immutable'] == true,
    );
  }

  /// The object written to LivingScroll.json's `key_events[]`.
  Map<String, dynamic> toJson() => {
    'name': name,
    'key_event_uuid': uuid,
    'state': checked ? 'checked' : 'unchecked',
    if (immutable) 'immutable': true,
  };
}
