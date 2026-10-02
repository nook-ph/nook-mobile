import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/state_styles.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// "Nothing matches “matcha” near IT Park with Open now and Wifi on."
String searchNoResultsLine({
  required String query,
  String? place,
  required List<String> filters,
}) {
  final q = query.trim();
  final parts = <String>[
    q.isEmpty ? 'Nothing matches' : 'Nothing matches “$q”',
    if (place != null && place.isNotEmpty) 'near $place',
  ];
  var line = parts.join(' ');
  if (filters.isNotEmpty) {
    final list = filters.length == 1
        ? filters.first
        : '${filters.sublist(0, filters.length - 1).join(', ')} and ${filters.last}';
    line += ' with $list on';
  }
  return '$line.';
}

/// No results: the query, place and filters repeated, with the two ways out.
class SearchEmptyView extends StatelessWidget {
  const SearchEmptyView({
    super.key,
    required this.line,
    this.onClearFilters,
    this.onSearchNearMe,
  });

  final String line;
  final VoidCallback? onClearFilters;
  final VoidCallback? onSearchNearMe;

  @override
  Widget build(BuildContext context) {
    final clear = onClearFilters;
    final nearMe = onSearchNearMe;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
      children: [
        const Icon(LucideIcons.searchX, size: 32, color: SearchTokens.muted),
        const SizedBox(height: 8),
        Text(
          'No cafes found',
          textAlign: TextAlign.center,
          style: SearchTokens.text(context, size: 16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          line,
          textAlign: TextAlign.center,
          style: SearchTokens.text(context, color: SearchTokens.muted),
        ),
        if (clear != null || nearMe != null) const SizedBox(height: 20),
        if (clear != null)
          SearchPillButton(label: 'Clear filters', onTap: clear),
        if (clear != null && nearMe != null) const SizedBox(height: 8),
        if (nearMe != null)
          SearchPillButton(
            label: 'Search near my location',
            outlined: true,
            onTap: nearMe,
          ),
      ],
    );
  }
}

/// A failed search, drawn inside the results area under the header and
/// chips: 48pt tinted circle, title, one line, and a hugging 44pt pill.
/// It starts 120 below the results' top padding instead of centring on the
/// page, so it sits where results would.
class SearchErrorBlock extends StatelessWidget {
  const SearchErrorBlock({super.key, required this.error, this.onRetry});

  final ErrorInfo error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final signIn = error.type == ErrorType.sessionExpired;
    final retry = onRetry;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Results pad 12/20, the block 120/20 inside it.
      padding: const EdgeInsets.fromLTRB(40, 132, 40, 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: StateStyles.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FullPageErrorWidget.iconFor(error.type),
              size: 22,
              color: StateStyles.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.title,
            textAlign: TextAlign.center,
            style: StateStyles.text(16, FontWeight.w600, StateStyles.ink),
          ),
          const SizedBox(height: 8),
          Text(
            error.subtitle,
            textAlign: TextAlign.center,
            style: StateStyles.text(14, FontWeight.w400, StateStyles.muted),
          ),
          if (retry != null) ...[
            // The design's 8 spacer between two 8 gaps.
            const SizedBox(height: 24),
            StatePillButton(
              label: signIn ? 'Sign in' : 'Try again',
              filled: signIn,
              onTap: retry,
            ),
          ],
        ],
      ),
    );
  }
}

/// The grey card above results that came back without a position: location
/// is off or was never asked for, and no place is chosen.
class SearchLocationOffCard extends StatelessWidget {
  const SearchLocationOffCard({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  static const message =
      'Turn on location to see the closest cafes first, or choose a place to '
      'search near.';

  @override
  Widget build(BuildContext context) {
    final dismiss = onDismiss;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SearchTokens.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: SearchTokens.text(context, size: 12)),
          ),
          if (dismiss != null) ...[
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Dismiss',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                child: const Icon(
                  LucideIcons.x,
                  size: 14,
                  color: SearchTokens.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
