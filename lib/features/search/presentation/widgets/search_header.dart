import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// Back arrow and the grey search field, then the "Near …" row that says
/// where distances are measured from and opens the place chooser.
class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.origin,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onOriginTap,
    required this.onReset,
    this.location = SearchLocationStatus.available,
    this.onTurnOn,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SearchOrigin? origin;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onOriginTap;
  final VoidCallback onReset;

  /// Whether the phone's location can be used; only read with no [origin].
  final SearchLocationStatus location;

  /// "Turn on", shown while location is off.
  final VoidCallback? onTurnOn;

  /// What follows "Near" when no place is chosen.
  static String phoneLabel(SearchLocationStatus location) => switch (location) {
    SearchLocationStatus.available => 'Current location',
    SearchLocationStatus.notAsked => 'Choose a place',
    SearchLocationStatus.off => 'Location is off',
  };

  @override
  Widget build(BuildContext context) {
    final place = origin;
    final off = place == null && location == SearchLocationStatus.off;
    final turnOn = onTurnOn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: () => context.pop(),
                    child: const SizedBox(
                      width: 24,
                      height: 48,
                      child: Icon(
                        LucideIcons.arrowLeft,
                        size: 24,
                        color: SearchTokens.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: SearchTokens.field,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: SearchTokens.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: onChanged,
                            onSubmitted: onSubmitted,
                            textInputAction: TextInputAction.search,
                            cursorColor: SearchTokens.brand,
                            style: SearchTokens.text(context),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Search cafes or people',
                              hintStyle: SearchTokens.text(
                                context,
                                color: SearchTokens.muted,
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) return const SizedBox();
                            return Semantics(
                              button: true,
                              label: 'Clear search',
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onClear,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: SearchTokens.muted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 21,
            child: Row(
              children: [
                const SizedBox(width: 36),
                Flexible(
                  child: Semantics(
                    button: true,
                    label:
                        place == null &&
                            location != SearchLocationStatus.available
                        ? '${phoneLabel(location)}. Choose a place to search near'
                        : 'Search near ${place?.fullLabel ?? 'current location'}. Change place',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOriginTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            place == null
                                ? LucideIcons.navigation
                                : LucideIcons.mapPin,
                            size: 14,
                            color: SearchTokens.brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Near',
                            style: SearchTokens.text(
                              context,
                              color: SearchTokens.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              place?.fullLabel ?? phoneLabel(location),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SearchTokens.text(
                                context,
                                weight: FontWeight.w600,
                                color: off
                                    ? SearchTokens.muted
                                    : SearchTokens.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 16,
                            color: SearchTokens.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (place != null) ...[
                  const Spacer(),
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: 'Search near current location',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReset,
                      child: Text(
                        'Reset',
                        style: SearchTokens.text(
                          context,
                          size: 12,
                          weight: FontWeight.w500,
                          color: SearchTokens.brand,
                        ),
                      ),
                    ),
                  ),
                ] else if (off && turnOn != null) ...[
                  const Spacer(),
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: 'Turn on location',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: turnOn,
                      child: Text(
                        'Turn on',
                        style: SearchTokens.text(
                          context,
                          size: 12,
                          weight: FontWeight.w600,
                          color: SearchTokens.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
