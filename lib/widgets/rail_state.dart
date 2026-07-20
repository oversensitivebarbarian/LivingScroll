import 'package:flutter/foundation.dart';

/// App-wide open/closed state of the navigation rail (the "roller"), shared by
/// EVERY screen's rail so the expand/collapse choice is PRESERVED when the user
/// moves between views — the app shell (Home/Create/Library/Settings), the
/// in-game editor, the Play view and the adventure launch screen all read and
/// write this single [ValueNotifier].
///
/// The state is PERSISTED between app launches: `main.dart` restores it from
/// `{Settings}/overrides.json` (`railExtended` stub) on startup and writes it
/// back on every change. The in-memory default (before that restore) is
/// collapsed (`false`). Each rail screen listens to [extended] and rebuilds on
/// change, and toggles it via [toggle] instead of a local field, so a change
/// made on one screen is reflected on all the others.
class RailState {
  RailState._();

  /// `true` when the rail is expanded (icons + labels), `false` when collapsed
  /// (icons only). Starts collapsed.
  static final ValueNotifier<bool> extended = ValueNotifier<bool>(false);

  /// Flips the shared expanded/collapsed state (wired to each rail's Menu
  /// button / Side Navigation toggle).
  static void toggle() => extended.value = !extended.value;
}
