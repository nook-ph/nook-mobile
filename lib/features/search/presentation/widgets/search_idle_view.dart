import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// Tags offered on the idle screen. Real tag names, so a tap filters.
const kSearchIdleBestFor = [
  'Solo Work / Study',
  'Student Friendly',
  'Group Hangout',
  'Specialty Coffee',
];
const kSearchIdleAmenities = [
  'Free WiFi',
  'Power Outlets',
  'Air Conditioned',
  'Parking Available',
];

/// Before typing: recent searches, then Best for and Amenities chips that
/// start a search without typing.
class SearchIdleView extends StatelessWidget {
  const SearchIdleView({
    super.key,
    required this.recents,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onTagTap,
    this.onClearRecents,
    this.locationCard,
  });

  /// "Clear all" beside the recents title.
  final VoidCallback? onClearRecents;

  /// The "Search near you" card, shown first while location was never asked.
  final Widget? locationCard;

  final List<String> recents;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    final title = SearchTokens.text(context, weight: FontWeight.w600);
    final clear = onClearRecents;
    final card = locationCard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (card != null) ...[card, const SizedBox(height: 20)],
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text('Recent searches', style: title)),
              if (clear != null)
                Semantics(
                  button: true,
                  label: 'Clear all recent searches',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: clear,
                    child: Text(
                      'Clear all',
                      style: SearchTokens.text(
                        context,
                        size: 12,
                        weight: FontWeight.w500,
                        color: SearchTokens.brand,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final query in recents)
            _RecentRow(
              query: query,
              onTap: () => onRecentTap(query),
              onRemove: () => onRecentRemove(query),
            ),
          const SizedBox(height: 20),
        ],
        _ChipSection(
          title: 'Best for',
          tags: kSearchIdleBestFor,
          onTap: onTagTap,
        ),
        const SizedBox(height: 20),
        _ChipSection(
          title: 'Amenities',
          tags: kSearchIdleAmenities,
          onTap: onTagTap,
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(LucideIcons.clock, size: 18, color: SearchTokens.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SearchTokens.text(context),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Remove $query from recent searches',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const SizedBox.square(
                  dimension: 21,
                  child: Center(
                    child: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: SearchTokens.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.tags,
    required this.onTap,
  });

  final String title;
  final List<String> tags;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SearchTokens.text(context, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              SearchChip(label: tag, selected: false, onTap: () => onTap(tag)),
          ],
        ),
      ],
    );
  }
}

/// "Search near you": shown before the system location prompt has ever
/// appeared, with the two ways to give search somewhere to measure from.
class SearchLocationPromptCard extends StatelessWidget {
  const SearchLocationPromptCard({
    super.key,
    required this.onUseMyLocation,
    required this.onChoosePlace,
  });

  final VoidCallback onUseMyLocation;
  final VoidCallback onChoosePlace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SearchTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search near you',
            style: SearchTokens.text(context, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Allow location to see the closest cafes first, or pick a '
            'neighbourhood yourself.',
            style: SearchTokens.text(
              context,
              size: 12,
              color: SearchTokens.muted,
            ),
          ),
          // 10 between the blocks, plus the row's own 2 on top.
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Use my location',
                  filled: true,
                  onTap: onUseMyLocation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardButton(
                  label: 'Choose a place',
                  filled: false,
                  onTap: onChoosePlace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 40pt pill inside the location card: Medium 12, filled green or outlined.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? SearchTokens.brand : SearchTokens.surface,
            borderRadius: BorderRadius.circular(100),
            border: filled ? null : Border.all(color: SearchTokens.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SearchTokens.text(
              context,
              size: 12,
              weight: FontWeight.w500,
              color: filled ? SearchTokens.surface : SearchTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
