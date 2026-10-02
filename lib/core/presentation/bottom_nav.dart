import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The four app tabs, each with its label. The second tab opens the map, so
/// it is named for it; search lives in the home top bar.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _brand = Color(0xFF344E41);
  static const _idle = Color(0xFF868584);
  static const _border = Color(0xFFE0E0E0);

  /// Tab order is the page order in `MainScreen`.
  static final List<({String label, IconData icon, IconData activeIcon})> tabs =
      [
        // Figma draws the selected tab with the same glyph; colour and the
        // label weight carry the state.
        (label: 'Home', icon: LucideIcons.house, activeIcon: LucideIcons.house),
        (label: 'Map', icon: LucideIcons.map, activeIcon: LucideIcons.map),
        (
          label: 'Saved',
          icon: LucideIcons.bookmark,
          activeIcon: LucideIcons.bookmark,
        ),
        (
          label: 'Profile',
          icon: LucideIcons.userRound,
          activeIcon: LucideIcons.userRound,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        // Figma: 8 above, 2 below, 12 at the sides; 53 tall at the default
        // text size. No fixed height, so a larger text size cannot overflow.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _Tab(
                    label: tabs[i].label,
                    icon: i == currentIndex ? tabs[i].activeIcon : tabs[i].icon,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BottomNav._brand : BottomNav._idle;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      // No ink: the tab bar never had a splash, and the colour change is the
      // feedback.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  height: 1.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
