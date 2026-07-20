/// One soundtrack: a stable [uuid] (`audio_uuid`,
/// minted on add) and a derived [name] (the DISPLAY NAME — track title (+ artist)
/// or the file name without extension; UNIQUE within `audio[]`).
///
/// References to the track are by [uuid] (what `scenes.audio[]` store), not by
/// [name]; the on-disk audio file is `audio/<uuid>.<ext>`.
class Soundtrack {
  Soundtrack({required this.uuid, required this.name, this.immutable = false});

  /// `audio_uuid` — stable identifier; also names the file under `audio/`.
  final String uuid;

  /// The derived display name — unique within the document's `audio`.
  String name;

  /// Runtime save-only flag: part of the immutable base
  /// content stamped at save creation — frozen in the save-edit editor.
  /// Absent/`false` in projects and exports; serialized only when `true`.
  bool immutable;

  factory Soundtrack.fromJson(Map json) {
    String s(Object? v) => v is String ? v : '';
    return Soundtrack(
      uuid: s(json['audio_uuid']),
      name: s(json['name']),
      immutable: json['immutable'] == true,
    );
  }

  /// The object written to LivingScroll.json's `audio[]`.
  Map<String, dynamic> toJson() => {
    'audio_uuid': uuid,
    'name': name,
    if (immutable) 'immutable': true,
  };
}
