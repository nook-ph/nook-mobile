import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The four app tabs, each with its label. The second tab opens the map, so
/// it is named for it; search lives in the home top bar.
///
/// Drawn as a floating glass capsule, after the iOS 26 tab bar: the page
/// shows through it, blurred; a capsule marks the selected tab and slides
/// to the next one; pressing a tab swells that capsule into a clear lens,
/// which can be dragged along the bar to pick a tab.
class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _brand = Color(0xFF344E41);
  static const _idle = Color(0xFF5F5E5C);

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

  /// The bar's height as last laid out, safe-area inset and the gap under
  /// the capsule included, so app-wide toasts (the merge toast) can sit
  /// above it; 0 before the first layout.
  static final ValueNotifier<double> height = ValueNotifier(0);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  /// The tab under the finger while pressed or dragged; null otherwise.
  int? _held;

  static const _pad = 4.0;
  static const _spring = Duration(milliseconds: 420);

  int _indexAt(double dx, double width) =>
      (dx / (width / BottomNav.tabs.length)).floor().clamp(
        0,
        BottomNav.tabs.length - 1,
      );

  void _hold(int? index) {
    if (index == _held) return;
    if (index != null && _held != null) HapticFeedback.selectionClick();
    setState(() => _held = index);
  }

  void _release({bool select = false}) {
    final index = _held;
    setState(() => _held = null);
    if (select && index != null) widget.onTap(index);
  }

  /// The bar: frosted, with the page bent at its rim.
  static const _barGlass = LiquidGlassSettings(
    glassColor: Color(0x8CFFFFFF),
    thickness: 22,
    blur: 8,
    refractiveIndex: 1.25,
    chromaticAberration: 0.01,
    lightIntensity: 0.7,
    ambientStrength: 0.4,
    saturation: 1.3,
  );

  /// The lens: clear and thick, so the icons under it bend and split
  /// at the edge.
  static const _lensGlass = LiquidGlassSettings(
    glassColor: Color(0x0FFFFFFF),
    thickness: 32,
    blur: 0,
    refractiveIndex: 1.45,
    chromaticAberration: 0.04,
    lightIntensity: 1,
    ambientStrength: 0.2,
    saturation: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return _ReportHeight(
      child: Padding(
        // Floats over the page: clear of the screen edges and resting just
        // above the home indicator.
        padding: EdgeInsets.fromLTRB(20, 0, 20, inset > 0 ? inset - 6 : 12),
        child: LayoutBuilder(builder: _tabs),
      ),
    );
  }

  Widget _tabs(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final tabWidth = (width - 2 * _pad) / BottomNav.tabs.length;
    final held = _held;
    final at = held ?? widget.currentIndex;

    return GestureDetector(
      onHorizontalDragStart: (d) => _hold(_indexAt(d.localPosition.dx, width)),
      onHorizontalDragUpdate: (d) => _hold(_indexAt(d.localPosition.dx, width)),
      onHorizontalDragEnd: (_) => _release(select: true),
      onHorizontalDragCancel: _release,
      // The lens swells past the bar's edge, so nothing here clips.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, box) => LiquidGlass.withOwnLayer(
                  settings: _barGlass,
                  shape: LiquidRoundedSuperellipse(
                    borderRadius: box.maxHeight / 2,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          // The selection capsule, hidden while the lens stands in for it.
          AnimatedPositioned(
            duration: _spring,
            curve: Curves.easeOutBack,
            left: _pad + at * tabWidth,
            top: _pad,
            bottom: _pad,
            width: tabWidth,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: held == null ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: BottomNav._brand.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Padding(
            // 10 above and below the glyph and label inside the 4pt rim. No
            // fixed height, so a larger text size cannot overflow.
            padding: const EdgeInsets.symmetric(horizontal: _pad),
            child: Row(
              children: [
                for (var i = 0; i < BottomNav.tabs.length; i++)
                  Expanded(
                    child: _Tab(
                      label: BottomNav.tabs[i].label,
                      icon: i == widget.currentIndex
                          ? BottomNav.tabs[i].activeIcon
                          : BottomNav.tabs[i].icon,
                      selected: i == widget.currentIndex,
                      onDown: () => _hold(i),
                      onCancel: _release,
                      onTap: () {
                        setState(() => _held = null);
                        widget.onTap(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
          // The lens: drawn over the icons, so they bend inside it.
          AnimatedPositioned(
            duration: _spring,
            curve: Curves.easeOutBack,
            left: _pad + at * tabWidth,
            top: _pad,
            bottom: _pad,
            width: tabWidth,
            child: IgnorePointer(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 260),
                curve: held != null ? Curves.easeOutBack : Curves.easeInCubic,
                scale: held != null ? 1.3 : 0.7,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: held != null ? 1 : 0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, visibility, _) => visibility == 0
                      ? const SizedBox.expand()
                      : LayoutBuilder(
                          builder: (context, box) => LiquidGlass.withOwnLayer(
                            settings: _lensGlass.copyWith(
                              visibility: visibility,
                            ),
                            shape: LiquidRoundedSuperellipse(
                              borderRadius: box.maxHeight / 2,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onDown,
    required this.onCancel,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onDown;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BottomNav._brand : BottomNav._idle;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onDown(),
        onTapCancel: onCancel,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

/// Writes its child's laid-out height into [BottomNav.height].
class _ReportHeight extends StatefulWidget {
  const _ReportHeight({required this.child});

  final Widget child;

  @override
  State<_ReportHeight> createState() => _ReportHeightState();
}

class _ReportHeightState extends State<_ReportHeight> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null) BottomNav.height.value = size.height;
    });
    return widget.child;
  }
}
