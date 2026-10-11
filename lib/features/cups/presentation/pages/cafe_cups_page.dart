import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/cup_actions.dart';
import 'package:nook/features/cups/presentation/widgets/cafe_cups_section.dart';
import 'package:nook/features/cups/presentation/widgets/cup_card_view.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';

enum CafeCupsTab { posts, photos }

/// Every cup of a cafe: Posts (the cups, sorted and filtered by kind and
/// stars) and Photos (every photo from them, two to a row), with "Add
/// your cup" pinned underneath. "See all" from the Cups section opens
/// Posts; the stories tray's opens Photos.
class CafeCupsPage extends StatefulWidget {
  const CafeCupsPage({
    super.key,
    required this.cafe,
    this.initialTab = CafeCupsTab.posts,
    this.menu = const [],
    this.photosSeed,
    this.onChanged,
    this.cupsCubit,
    this.photosCubit,
  });

  final PickedCafe cafe;
  final CafeCupsTab initialTab;
  final List<CupMenuOption> menu;

  /// What the stories tray already loaded, shown at once.
  final CafePhotosState? photosSeed;

  /// A cup was added, edited or deleted here: the page under it reloads.
  final VoidCallback? onChanged;

  /// For tests.
  final CafeCupsCubit? cupsCubit;
  final CafePhotosCubit? photosCubit;

  static Future<void> open(
    BuildContext context, {
    required PickedCafe cafe,
    CafeCupsTab initialTab = CafeCupsTab.posts,
    List<CupMenuOption> menu = const [],
    CafePhotosState? photosSeed,
    VoidCallback? onChanged,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CafeCupsPage(
          cafe: cafe,
          initialTab: initialTab,
          menu: menu,
          photosSeed: photosSeed,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  State<CafeCupsPage> createState() => _CafeCupsPageState();
}

class _CafeCupsPageState extends State<CafeCupsPage> {
  late CafeCupsTab _tab = widget.initialTab;
  late final CafeCupsCubit _cups =
      widget.cupsCubit ??
      (CafeCupsCubit(
        repository: sl<ICupsRepository>(),
        cafeId: widget.cafe.id,
        pageSize: CafeCupsCubit.pagePageSize,
      )..load());
  late final CafePhotosCubit _photos = widget.photosCubit ?? _makePhotos();

  CafePhotosCubit _makePhotos() {
    final seed = widget.photosSeed?.status == CafePhotosStatus.loaded
        ? widget.photosSeed
        : null;
    final cubit = CafePhotosCubit(
      repository: sl<ICommunityPhotosRepository>(),
      cafeId: widget.cafe.id,
      pageSize: CafePhotosCubit.gridPageSize,
      seed: seed,
    );
    seed == null ? cubit.load() : cubit.loadMore();
    return cubit;
  }

  @override
  void dispose() {
    if (widget.cupsCubit == null) _cups.close();
    if (widget.photosCubit == null) _photos.close();
    super.dispose();
  }

  double _barHeight() {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return 61 + (inset > 8 ? inset : 8);
  }

  void _changed() {
    _cups.load(refresh: true);
    _photos.load(refresh: true);
    widget.onChanged?.call();
  }

  Future<void> _add({CupCard? editing}) async {
    final outcome = await startCup(
      context,
      cafe: widget.cafe,
      source: CupSource.cupsPage,
      editing: editing,
      menu: widget.menu,
      myCups: _cups.state.isLoaded ? _cups.state.myCups : null,
      toastOffset: _barHeight(),
    );
    if (outcome != null && mounted) _changed();
  }

  Future<void> _pickSort() async {
    final current = _cups.state.sort;
    final chosen = await ListsSheet.show<CupSort>(
      context,
      builder: (sheet) => ListsSheet(
        title: 'Sort cups',
        gap: 4,
        children: [
          for (final sort in CupSort.values)
            ListsSheetAction(
              title: sort == current ? '${sort.label} ✓' : sort.label,
              onTap: () => Navigator.pop(sheet, sort),
            ),
        ],
      ),
    );
    if (chosen != null) _cups.setSort(chosen);
  }

  Future<void> _pickStars() async {
    final current = _cups.state.ratingFilter;
    final chosen = await ListsSheet.show<int>(
      context,
      builder: (sheet) => ListsSheet(
        title: 'Show cups rated',
        gap: 4,
        children: [
          ListsSheetAction(
            title: current == null ? 'Any rating ✓' : 'Any rating',
            subtitle: 'Cups without stars too',
            onTap: () => Navigator.pop(sheet, 0),
          ),
          for (var star = 5; star >= 1; star--)
            ListsSheetAction(
              title:
                  '${'★' * star}${current == star ? ' ✓' : ''}'
                  ' ${star == 1 ? '1 star' : '$star stars'}',
              onTap: () => Navigator.pop(sheet, star),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    _cups.setRatingFilter(chosen == 0 ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cups),
        BlocProvider.value(value: _photos),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: Semantics(
            button: true,
            label: 'Back',
            child: AdaptiveTap(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: CafeDetailsTokens.ink),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cups',
                style: theme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CafeDetailsTokens.ink,
                ),
              ),
              Text(
                widget.cafe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(
                  color: CafeDetailsTokens.muted,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            // 4 + 8 padding, 4 + 4 around the 40px segments. Declaring less
            // squeezes the toolbar holding the two-line title.
            preferredSize: const Size.fromHeight(60),
            child: BlocBuilder<CafeCupsCubit, CafeCupsState>(
              buildWhen: (a, b) => a.stats != b.stats,
              builder: (context, state) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  CafeDetailsTokens.gutter,
                  4,
                  CafeDetailsTokens.gutter,
                  8,
                ),
                child: _Toggle(
                  tab: _tab,
                  cups: state.isLoaded ? state.stats.cupCount : null,
                  photos: state.isLoaded ? state.stats.photoCount : null,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
            ),
          ),
        ),
        body: _tab == CafeCupsTab.photos
            ? CafePhotosBody(cafeId: widget.cafe.id, cafeName: widget.cafe.name)
            : _Posts(
                cafe: widget.cafe,
                onSort: _pickSort,
                onStars: _pickStars,
                onEdit: (card) => _add(editing: card),
                onChanged: _changed,
                toastOffset: _barHeight,
              ),
        bottomNavigationBar: _AddBar(onTap: () => _add()),
      ),
    );
  }
}

/// Posts | Photos, with their counts.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.tab,
    required this.cups,
    required this.photos,
    required this.onChanged,
  });

  final CafeCupsTab tab;
  final int? cups;
  final int? photos;
  final ValueChanged<CafeCupsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(CafeCupsTab value, String label, int? count) {
      final selected = tab == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: count == null ? label : '$label, $count',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                count == null ? label : '$label · $count',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? CafeDetailsTokens.ink
                      : CafeDetailsTokens.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CafeDetailsTokens.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment(CafeCupsTab.posts, 'Cups', cups),
          segment(CafeCupsTab.photos, 'Photos', photos),
        ],
      ),
    );
  }
}

class _Posts extends StatelessWidget {
  const _Posts({
    required this.cafe,
    required this.onSort,
    required this.onStars,
    required this.onEdit,
    required this.onChanged,
    required this.toastOffset,
  });

  final PickedCafe cafe;
  final VoidCallback onSort;
  final VoidCallback onStars;
  final ValueChanged<CupCard> onEdit;
  final VoidCallback onChanged;
  final double Function() toastOffset;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CafeCupsCubit>();
    return BlocBuilder<CafeCupsCubit, CafeCupsState>(
      builder: (context, state) {
        if (state.status == CafeCupsStatus.failed) {
          final info = AppErrorCopy.fromException(state.error ?? '');
          return _Message(
            icon: LucideIcons.wifiOff,
            title: info.title,
            subtitle: info.subtitle,
            action: 'Try again',
            onAction: cubit.load,
          );
        }
        if (!state.isLoaded) {
          return const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: CafeDetailsTokens.brand,
                semanticsLabel: 'Loading cups',
              ),
            ),
          );
        }
        final blocked = context.watch<BlockCubit>().state;
        final cards = [
          for (final c in state.cards)
            if (!blocked.contains(c.userId)) c,
        ];
        if (state.stats.cupCount == 0 && !state.isFiltered) {
          return const _Message(
            icon: LucideIcons.coffee,
            title: 'No cups yet',
            subtitle: 'Been here? Add the first one below.',
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 600) cubit.loadMore();
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: 2 + (cards.isEmpty ? 1 : cards.length) + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CafeDetailsTokens.gutter,
                    8,
                    CafeDetailsTokens.gutter,
                    0,
                  ),
                  child: _Summary(stats: state.stats),
                );
              }
              if (index == 1) {
                return _Controls(
                  state: state,
                  onKind: cubit.setKind,
                  onSort: onSort,
                  onStars: onStars,
                );
              }
              final i = index - 2;
              if (cards.isEmpty && i == 0) {
                return _Message(
                  icon: LucideIcons.searchX,
                  title: 'No cups match',
                  subtitle: 'Try another kind or rating.',
                  action: 'Show all cups',
                  onAction: () {
                    cubit.setKind(null);
                    cubit.setRatingFilter(null);
                  },
                  compact: true,
                );
              }
              if (i >= cards.length) {
                return _Footer(
                  state: state,
                  onRetry: () => cubit.loadMore(retry: true),
                );
              }
              final card = cards[i];
              return Padding(
                key: ValueKey(card.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: CafeDetailsTokens.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i > 0)
                      const Divider(
                        height: 24,
                        thickness: 1,
                        color: CafeDetailsTokens.border,
                      ),
                    CupCardView(
                      card: card,
                      onOpenPhoto: (photo) => openCupPhotos(
                        context,
                        card: card,
                        index: photo,
                        cafeId: cafe.id,
                        cafeName: cafe.name,
                      ),
                      onHelpful: card.isMine || !card.canVote
                          ? null
                          : () => toggleCupHelpful(
                              context,
                              cubit: cubit,
                              card: card,
                              toastOffset: toastOffset(),
                            ),
                      onMore: () => showCupOptions(
                        context,
                        card: card,
                        cafeId: cafe.id,
                        cafeName: cafe.name,
                        cafeArea: cafe.area,
                        onEdit: () => onEdit(card),
                        onChanged: onChanged,
                        toastOffset: toastOffset(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The big number: the average from people who rated (each once), its
/// stars, and the counts. Without ratings, only the counts.
class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final CupStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final rating = stats.rating;
    if (!stats.hasRatings) return CupStatsLine(stats: stats);
    return Semantics(
      label:
          'Rated ${rating!.toStringAsFixed(1)} out of 5. '
          '${cupStatsParts(stats).join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: theme.titleLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupStars(rating: rating.round(), size: 16),
                const SizedBox(height: 2),
                Text(
                  cupStatsParts(stats).join(' · '),
                  style: theme.bodySmall?.copyWith(
                    color: CafeDetailsTokens.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onKind,
    required this.onSort,
    required this.onStars,
  });

  final CafeCupsState state;
  final ValueChanged<CupItemKind?> onKind;
  final VoidCallback onSort;
  final VoidCallback onStars;

  @override
  Widget build(BuildContext context) {
    final stars = state.ratingFilter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (state.stats.kindCounts.isNotEmpty || state.kind != null)
          CupKindFilter(
            stats: state.stats,
            value: state.kind,
            onChanged: onKind,
            padding: const EdgeInsets.symmetric(
              horizontal: CafeDetailsTokens.gutter,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter - 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _MenuButton(
                  label: stars == null
                      ? 'Any rating'
                      : (stars == 1 ? '1 star' : '$stars stars'),
                  active: stars != null,
                  onTap: state.stats.hasRatings || stars != null
                      ? onStars
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _MenuButton(label: state.sort.label, onTap: onSort),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: CafeDetailsTokens.border),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled
        ? CafeDetailsTokens.muted
        : (active ? CafeDetailsTokens.brand : CafeDetailsTokens.ink);
    return Semantics(
      button: true,
      enabled: enabled,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronDown, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final CafeCupsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget child = const SizedBox.shrink();
    if (state.loadingMore) {
      child = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CafeDetailsTokens.brand,
          semanticsLabel: 'Loading more cups',
        ),
      );
    } else if (state.loadMoreFailed) {
      child = AdaptiveTap(
        onTap: onRetry,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              'Couldn’t load more. Try again',
              style: theme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.brand,
              ),
            ),
          ),
        ),
      );
    } else if (!state.hasMore && state.cards.length > 3) {
      child = Text(
        'That’s every cup so far.',
        style: theme.bodySmall?.copyWith(
          fontSize: 12,
          color: CafeDetailsTokens.muted,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CafeDetailsTokens.gutter,
        20,
        CafeDetailsTokens.gutter,
        8,
      ),
      child: Center(child: child),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final run = onAction;
    final column = Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 32 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: CafeDetailsTokens.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              fontSize: 14,
              color: CafeDetailsTokens.muted,
            ),
          ),
          if (action != null && run != null)
            AdaptiveTap(
              onTap: run,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
                child: Center(
                  child: Text(
                    action!,
                    style: theme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CafeDetailsTokens.brand,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return compact ? column : Center(child: column);
  }
}

/// "Add your cup", pinned under the list: a cup is a visit, so there is
/// always another one to add.
class _AddBar extends StatelessWidget {
  const _AddBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CafeDetailsTokens.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CafeDetailsTokens.gutter,
          12,
          CafeDetailsTokens.gutter,
          inset > 8 ? inset : 8,
        ),
        child: SizedBox(
          width: double.infinity,
          child: AddCupPill(onTap: onTap, filled: true),
        ),
      ),
    );
  }
}
