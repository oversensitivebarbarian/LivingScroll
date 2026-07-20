import 'package:flutter/material.dart';

/// The glyph that denotes a scene's type (`scenes[].scene_type`), SHARED by the
/// new_scene form's "Typ sceny" radios and the scene tile's
/// leading icon so the two never diverge. Mirrors
/// [Scene.sceneTypes]; an unknown type falls back to the standard glyph.
IconData sceneTypeIcon(String sceneType) {
  switch (sceneType) {
    case 'start':
      return Icons.play_circle;
    case 'recurring':
      return Icons.change_circle;
    case 'end':
      return Icons.stop_circle;
    case 'standard':
    default:
      return Icons.circle;
  }
}
