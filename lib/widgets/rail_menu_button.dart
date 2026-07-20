import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// NavigationRail's default collapsed and extended widths in Material 3
/// (`_NavigationRailDefaultsM3`: minWidth 80, minExtendedWidth 256). The Menu
/// icon is centered within a leading box of [_railMinWidth] and the leading
/// tracks the rail width across the animation, so it lines up with the
/// destination icons without drifting while expanding/collapsing.
const double _railMinWidth = 80.0;
const double _railExtendedWidth = 256.0;

/// The side-navigation toggle for a [NavigationRail]'s `leading` slot, shared by
/// the app shell and the in-game shell.
///
/// It shows ONLY the Side Navigation icon — NO label, in any rail state. The
/// rail centers its `leading` widget, so this is made exactly as wide as the
/// rail (tracking its expand/collapse animation via
/// [NavigationRail.extendedAnimation]) with the icon pinned to the left in a
/// leading box matching the destination icons (centered when collapsed,
/// left-aligned at the destinations' axis when expanded). [tooltip] is the
/// hover/semantics hint only.
class RailMenuButton extends StatelessWidget {
  const RailMenuButton({super.key, required this.tooltip, required this.onTap});

  /// Hover/accessibility hint (not shown as a visible label).
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final animation = NavigationRail.extendedAnimation(context);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final width =
            _railMinWidth + (_railExtendedWidth - _railMinWidth) * t;
        return SizedBox(
          width: width,
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: SizedBox(
                  height: 48,
                  // Icon only (no label): a leading box matching the
                  // destination icons keeps it on their vertical axis.
                  child: SizedBox(
                    width: _railMinWidth,
                    child: Center(
                      child: Icon(Symbols.side_navigation, color: color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
