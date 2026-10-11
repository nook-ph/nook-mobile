import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/widgets/cup_card_view.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// "Cups" on a cafe's page, where Reviews was: the numbers (stars from
/// rated cups only), the kind filter, two cups, and "Add your cup"
/// (docs/references/cups: Klarna's cards, Google Maps' photos, Fable's
/// add pill at the end of the list). The "Latest cups" stories tray at the
/// top of the page is the highlight; this is the record.
///
/// Reads the [CafeCupsCubit] above it.
class CafeCupsSection extends StatelessWidget {
  const CafeCupsSection({
    super.key,
    required this.onSeeAll,
    required this.onAdd,
    required this.onOpenPhoto,
    required this.onHelpful,
    required this.onMore,
  });

  final VoidCallback onSeeAll;
  final VoidCallback onAdd;
  final void Function(CupCard card, int index) onOpenPhoto;
  final ValueChanged<CupCard> onHelpful;
  final ValueChanged<CupCard> onMore;

  static const shown = 2;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CafeCupsCubit, CafeCupsState>(
      builder: (context, state) {
        switch (state.status) {
          case CafeCupsStatus.initial:
          case CafeCupsStatus.loading:
            return const _Shell(child: _Skeleton());
          case CafeCupsStatus.failed:
            final info = CafeLoadFailure.from(state.error ?? '').info;
            return _Shell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cups could not load. ${info.subtitle}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CafeDetailsTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CafeWideButton(
                    label: 'Try again',
                    onTap: () => context.read<CafeCupsCubit>().load(),
                  ),
                ],
              ),
            );
          case CafeCupsStatus.loaded:
            break;
        }

        final blocked = context.watch<BlockCubit>().state;
        final cards = [
          for (final c in state.cards)
            if (!blocked.contains(c.userId)) c,
        ];
        if (cards.isEmpty && !state.isFiltered) {
          return _Shell(child: _Empty(onAdd: onAdd));
        }
        final stats = state.stats;
        return _Shell(
          count: stats.cupCount,
          onSeeAll: onSeeAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupStatsLine(stats: stats),
              if (stats.kindCounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                CupKindFilter(
                  stats: stats,
                  value: state.kind,
                  onChanged: context.read<CafeCupsCubit>().setKind,
                ),
              ],
              const SizedBox(height: 8),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No cups with ${state.kind?.label.toLowerCase() ?? 'that'} '
                    'yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CafeDetailsTokens.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
              for (var i = 0; i < cards.length && i < shown; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: CafeDetailsTokens.border,
                  ),
                CupCardView(
                  key: ValueKey(cards[i].id),
                  card: cards[i],
                  noteLines: 3,
                  onOpenPhoto: (index) => onOpenPhoto(cards[i], index),
                  onHelpful: cards[i].isMine || !cards[i].canVote
                      ? null
                      : () => onHelpful(cards[i]),
                  onMore: () => onMore(cards[i]),
                ),
              ],
              const SizedBox(height: 12),
              // The header's See all is the one way to every cup; the
              // footer keeps only the add (UX review 1.3).
              Align(
                alignment: Alignment.centerLeft,
                child: AddCupPill(onTap: onAdd),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The section heading row and gutter, shared by every state.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.count, this.onSeeAll});

  final Widget child;
  final int? count;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final seeAll = onSeeAll;
    final n = count;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Flexible(child: CafeSectionTitle('Cups')),
                    if (n != null && n > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$n',
                        style: theme.bodyLarge?.copyWith(
                          fontSize: 16,
                          color: CafeDetailsTokens.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (seeAll != null)
                Semantics(
                  button: true,
                  label: 'See all cups',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: seeAll,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See all',
                            style: theme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CafeDetailsTokens.brand,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: CafeDetailsTokens.brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 44),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// "★ 4.8 · 9 ratings · 14 cups · 23 photos": stars only from people who
/// rated, each person once; no stars at all when nobody rated.
class CupStatsLine extends StatelessWidget {
  const CupStatsLine({super.key, required this.stats});

  final CupStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(
      fontSize: 13,
      color: CafeDetailsTokens.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final rating = stats.rating;
    final parts = cupStatsParts(stats);
    return Semantics(
      label: [
        if (stats.hasRatings) 'Rated ${rating!.toStringAsFixed(1)} out of 5',
        ...parts,
      ].join(', '),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          if (stats.hasRatings) ...[
            const Icon(
              Icons.star_rounded,
              size: 18,
              color: CafeDetailsTokens.star,
            ),
            Text(
              rating!.toStringAsFixed(1),
              style: theme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
          ],
          Text(
            [if (stats.hasRatings) '', ...parts].join(' · ').trimLeft(),
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// "9 ratings", "14 cups", "23 photos", leaving out zeros past the cups.
List<String> cupStatsParts(CupStats stats) {
  String n(int count, String one, String many) =>
      '$count ${count == 1 ? one : many}';
  return [
    if (stats.hasRatings) n(stats.ratedCount, 'rating', 'ratings'),
    n(stats.cupCount, 'cup', 'cups'),
    if (stats.photoCount > 0) n(stats.photoCount, 'photo', 'photos'),
  ];
}

/// All · Coffee · Drink · Food · Space, each kind only when some cup has
/// it. Tapping the active one goes back to All.
class CupKindFilter extends StatelessWidget {
  const CupKindFilter({
    super.key,
    required this.stats,
    required this.value,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final CupStats stats;
  final CupItemKind? value;
  final ValueChanged<CupItemKind?> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kinds = [
      for (final kind in CupItemKind.values)
        if ((stats.kindCounts[kind] ?? 0) > 0 || kind == value) kind,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: value == null,
            onTap: () => onChanged(null),
          ),
          for (final kind in kinds) ...[
            const SizedBox(width: 8),
            _Chip(
              label: kind.label,
              icon: cupKindIcon(kind),
              count: stats.kindCounts[kind],
              selected: value == kind,
              onTap: () => onChanged(kind),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : CafeDetailsTokens.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? CafeDetailsTokens.brand : null,
              border: Border.all(
                color: selected
                    ? CafeDetailsTokens.brand
                    : CafeDetailsTokens.border,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  count == null ? label : '$label $count',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The add action closing the section: Fable's outlined pill.
class AddCupPill extends StatelessWidget {
  const AddCupPill({super.key, required this.onTap, this.filled = false});

  final VoidCallback onTap;

  /// Filled for the empty state, where it is the only action.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add your cup',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: filled ? CafeDetailsTokens.brand : null,
            border: Border.all(color: CafeDetailsTokens.brand),
            borderRadius: BorderRadius.circular(999),
          ),
          // Centred without growing: in a bottom bar the height is loose,
          // and a plain alignment would fill the screen.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.plus,
                  size: 16,
                  color: filled ? Colors.white : CafeDetailsTokens.brand,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Add your cup',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: filled ? Colors.white : CafeDetailsTokens.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: CafeDetailsTokens.tint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            LucideIcons.coffee,
            size: 24,
            color: CafeDetailsTokens.muted,
          ),
          const SizedBox(height: 8),
          Text(
            'No cups yet',
            style: theme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Been here? Add the first one: a photo or a note.',
            textAlign: TextAlign.center,
            style: theme.bodySmall?.copyWith(color: CafeDetailsTokens.muted),
          ),
          const SizedBox(height: 16),
          AddCupPill(onTap: onAdd, filled: true),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading cups',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: CafeDetailsTokens.tint,
          to: Color(0xFFF6F6F6),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bone(width: 200, height: 14, uniRadius: 6),
            SizedBox(height: 16),
            Row(
              children: [
                Bone.circle(size: 36),
                SizedBox(width: 10),
                Bone(width: 120, height: 12, uniRadius: 6),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Bone(height: 130, uniRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: Bone(height: 130, uniRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: Bone(height: 130, uniRadius: 10)),
              ],
            ),
            SizedBox(height: 12),
            Bone(width: 260, height: 12, uniRadius: 6),
          ],
        ),
      ),
    );
  }
}
