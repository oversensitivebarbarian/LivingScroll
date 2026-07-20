import 'package:flutter/painting.dart';

/// A path colour: a stable [id] (used in widget keys) and its [color].
class PathColorDef {
  const PathColorDef(this.id, this.color);

  final String id;
  final Color color;
}

/// The six path colours. The Paths section renders exactly one tile per
/// entry.
const List<PathColorDef> pathColors = <PathColorDef>[
  PathColorDef('yellow', Color(0xFFF0C800)),
  PathColorDef('green', Color(0xFF009E50)),
  PathColorDef('red', Color(0xFFD22828)),
  PathColorDef('blue', Color(0xFF1EA0DC)),
  PathColorDef('violet', Color(0xFF6E00B4)),
  PathColorDef('orange', Color(0xFFE66400)),
];
