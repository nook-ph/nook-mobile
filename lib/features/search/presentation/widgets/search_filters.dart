import 'package:flutter/material.dart';
import 'package:nook/core/utils/debounced_count.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/presentation/widgets/search_idle_view.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// Sort ids `get_cafes` understands, with the labels search shows.
const kSearchSorts = [
  ('nearby', 'Nearest'),
  ('top_rated', 'Top rated'),
  ('trending', 'Trending'),
  ('newest', 'Newest'),
];

String searchSortLabel(String id) => kSearchSorts
    .firstWhere((s) => s.$1 == id, orElse: () => kSearchSorts.first)
    .$2;

/// Quick tag chips in the results row, after sort and "Open now".
const kSearchQuickTags = ['Free WiFi', 'Power Outlets', 'Student Friendly'];

/// The row above results: all filters, sort, "Open now", then tag chips.
/// The tags already chosen come first so they stay in view.
class SearchFiltersRow extends StatelessWidget {
  const SearchFiltersRow({
    super.key,
    required this.sort,
    required this.openNow,
    required this.tags,
    required this.onAllFilters,
    required this.onSort,
    required this.onOpenNow,
    required this.onTag,
    this.showOpenNow = true,
  });

  final String sort;
  final bool openNow;
  final Set<String> tags;
  final VoidCallback onAllFilters;
  final VoidCallback onSort;
  final VoidCallback onOpenNow;
  final ValueChanged<String> onTag;

  /// False while the results carry no opening hours to filter on.
  final bool showOpenNow;

  @override
  Widget build(BuildContext context) {
    final quick = [
      ...tags,
      ...kSearchQuickTags.where((t) => !tags.contains(t)),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        children: [
          SearchChip(
            icon: LucideIcons.slidersHorizontal,
            selected: false,
            semanticLabel: 'All filters',
            onTap: onAllFilters,
          ),
          const SizedBox(width: 8),
          SearchChip(
            label: searchSortLabel(sort),
            trailingIcon: LucideIcons.chevronDown,
            selected: true,
            semanticLabel: 'Sort: ${searchSortLabel(sort)}',
            onTap: onSort,
          ),
          if (showOpenNow) ...[
            const SizedBox(width: 8),
            SearchChip(label: 'Open now', selected: openNow, onTap: onOpenNow),
          ],
          for (final tag in quick) ...[
            const SizedBox(width: 8),
            SearchChip(
              label: tag,
              selected: tags.contains(tag),
              onTap: () => onTag(tag),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom-sheet frame shared by the sort and filter sheets: 24pt corners,
/// grabber, title with a 32pt close, [gap] between the blocks.
class SearchSheetFrame extends StatelessWidget {
  const SearchSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.gap = 18,
  });

  final String title;
  final Widget child;

  /// Between grabber, title and content: 4 in "Sort by", 18 in "Filters".
  final double gap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: SearchTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        // 34 under the content, which is the home-indicator area.
        bottomInset > 26 ? bottomInset + 8 : 34,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SearchTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // The grabber's own 4 below it, then the gap.
          SizedBox(height: 4 + gap),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: SearchTokens.text(
                    context,
                    size: 16,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox.square(
                    dimension: 32,
                    child: Icon(
                      LucideIcons.x,
                      size: 22,
                      color: SearchTokens.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Tick list of sorts; a tap applies and closes.
Future<String?> showSearchSortSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => SearchSheetFrame(
      title: 'Sort by',
      gap: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, label) in kSearchSorts) ...[
            if (id != kSearchSorts.first.$1) const SizedBox(height: 4),
            AdaptiveTap(
              onTap: () => Navigator.of(context).pop(id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: SearchTokens.text(
                          context,
                          weight: id == current
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (id == current)
                      const Icon(
                        LucideIcons.check,
                        size: 18,
                        color: SearchTokens.brand,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// All Best for and Amenities tags as toggle chips. Returns the new set, or
/// null when dismissed.
///
/// [count] says how many cafes a draft set of tags would show; the primary
/// button reads "Show N cafes" once it answers, and "Apply" until then or
/// when it answers null.
Future<Set<String>?> showSearchTagsSheet(
  BuildContext context,
  Set<String> current, {
  Future<int?> Function(Set<String> tags)? count,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => _TagsSheet(initial: current, count: count),
  );
}

const kSearchAllBestFor = [
  ...kSearchIdleBestFor,
  'Date Spot',
  'Book Cafe',
  'Late Night',
  'Quick Coffee',
  'Family Friendly',
  'Nature Cafe',
  'Special Occasion',
  'Aesthetic / IG-worthy',
  'Community Space',
];
const kSearchAllAmenities = [
  ...kSearchIdleAmenities,
  'Outdoor Seating',
  'Reservations Accepted',
  'Private Rooms',
  'Wheelchair Accessible',
  'Takeaway Available',
  'Smoking Area',
  'Open 24 Hours',
  'Pet Friendly',
];

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.initial, this.count});

  final Set<String> initial;
  final Future<int?> Function(Set<String> tags)? count;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final Set<String> _selected = {...widget.initial};
  final _count = DebouncedCount();

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _recount() {
    final count = widget.count;
    if (count == null) return;
    final draft = {..._selected};
    _count.request(() => count(draft));
  }

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<String> tags) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SearchTokens.text(context, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              SearchChip(
                label: tag,
                selected: _selected.contains(tag),
                onTap: () {
                  setState(() {
                    if (!_selected.remove(tag)) _selected.add(tag);
                  });
                  _recount();
                },
              ),
          ],
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SearchSheetFrame(
        title: 'Filters',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section('Best for', kSearchAllBestFor),
                    const SizedBox(height: 18),
                    section('Amenities', kSearchAllAmenities),
                  ],
                ),
              ),
            ),
            // 18 between the sheet's blocks, plus the row's own 4 on top.
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SearchPillButton(
                    label: 'Clear all',
                    outlined: true,
                    onTap: () {
                      setState(_selected.clear);
                      _recount();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _count.value,
                    builder: (context, n, _) => SearchPillButton(
                      label: showCafesLabel(n),
                      onTap: () => Navigator.of(context).pop(_selected),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 48pt pill button: filled green, or outlined.
class SearchPillButton extends StatelessWidget {
  const SearchPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: outlined ? SearchTokens.surface : SearchTokens.brand,
            borderRadius: BorderRadius.circular(100),
            border: outlined ? Border.all(color: SearchTokens.border) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SearchTokens.text(
              context,
              weight: FontWeight.w500,
              color: outlined ? SearchTokens.ink : SearchTokens.surface,
            ),
          ),
        ),
      ),
    );
  }
}
