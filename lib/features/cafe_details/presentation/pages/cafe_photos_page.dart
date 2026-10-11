import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/community_photo_actions.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Every community photo of a cafe, two to a row, a page at a time as it
/// scrolls (Luma's grid with the credit under each tile, Givingli's
/// skeleton; docs/references/cafe-community-photos).
class CafePhotosPage extends StatelessWidget {
  const CafePhotosPage({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.seed,
    this.cubit,
  });

  final String cafeId;
  final String cafeName;

  /// What the strip already loaded, shown at once and paged on from.
  final CafePhotosState? seed;

  /// For tests.
  final CafePhotosCubit? cubit;

  static Future<void> open(
    BuildContext context, {
    required String cafeId,
    required String cafeName,
    CafePhotosState? seed,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CafePhotosPage(cafeId: cafeId, cafeName: cafeName, seed: seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final given = cubit;
    final view = _CafePhotosView(cafeId: cafeId, cafeName: cafeName);
    if (given != null) return BlocProvider.value(value: given, child: view);
    return BlocProvider(
      create: (_) {
        final from = seed?.status == CafePhotosStatus.loaded ? seed : null;
        final created = CafePhotosCubit(
          repository: sl<ICommunityPhotosRepository>(),
          cafeId: cafeId,
          pageSize: CafePhotosCubit.gridPageSize,
          seed: from,
        );
        // Seeded: fill the first screen past the strip's few.
        from == null ? created.load() : created.loadMore();
        return created;
      },
      child: view,
    );
  }
}

class _CafePhotosView extends StatefulWidget {
  const _CafePhotosView({required this.cafeId, required this.cafeName});

  final String cafeId;
  final String cafeName;

  @override
  State<_CafePhotosView> createState() => _CafePhotosViewState();
}

class _CafePhotosViewState extends State<_CafePhotosView> {
  bool _loggedView = false;

  void _logView(CafePhotosState state) {
    if (_loggedView || state.status != CafePhotosStatus.loaded) return;
    if (state.photos.isEmpty) return;
    _loggedView = true;
    logAppEvent(
      CafePhotoEvents.viewed,
      properties: {
        'cafe_id': widget.cafeId,
        'surface': CafePhotoSurface.grid,
        'count': state.total,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // A seeded grid is loaded before the first listener could hear it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _logView(context.read<CafePhotosCubit>().state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
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
              'Photos',
              style: theme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
            if (widget.cafeName.isNotEmpty)
              Text(
                widget.cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(
                  color: CafeDetailsTokens.muted,
                ),
              ),
          ],
        ),
      ),
      body: CafePhotosBody(
        cafeId: widget.cafeId,
        cafeName: widget.cafeName,
        onLoaded: _logView,
      ),
    );
  }
}

/// The photo grid with its loading, failed and empty states, for the
/// [CafePhotosCubit] above it. The Cups page's Photos tab shows it too.
class CafePhotosBody extends StatelessWidget {
  const CafePhotosBody({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.onLoaded,
  });

  final String cafeId;
  final String cafeName;
  final ValueChanged<CafePhotosState>? onLoaded;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CafePhotosCubit, CafePhotosState>(
      listener: (_, state) => onLoaded?.call(state),
      builder: (context, state) => switch (state.status) {
        CafePhotosStatus.initial ||
        CafePhotosStatus.loading => const _GridSkeleton(),
        CafePhotosStatus.failed => _Message.error(
          error: state.error,
          onRetry: () => context.read<CafePhotosCubit>().load(),
        ),
        CafePhotosStatus.loaded when state.photos.isEmpty =>
          const _Message.empty(),
        CafePhotosStatus.loaded => _Grid(
          state: state,
          cafeId: cafeId,
          cafeName: cafeName,
        ),
      },
    );
  }
}

/// Two columns of tiles; how tall a tile is depends on its width and the
/// text size, so the extent is worked out rather than fixed.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.state,
    required this.cafeId,
    required this.cafeName,
  });

  final CafePhotosState state;
  final String cafeId;
  final String cafeName;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final photos = state.photos;
    final cubit = context.read<CafePhotosCubit>();
    final scaler = MediaQuery.textScalerOf(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // About a screen ahead, so the next page is in before it is needed.
        if (n.metrics.extentAfter < 600) cubit.loadMore();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final tileWidth =
              (box.maxWidth - CafeDetailsTokens.gutter * 2 - _gap) / 2;
          // The caption: 8 above, a 13px line, 4, the 20px credit row (or
          // its text, when larger), 4 below; at least the 44 tap target.
          final caption =
              (8 +
                      scaler.scale(13) * 1.5 +
                      4 +
                      [
                        20.0,
                        scaler.scale(12) * 1.5,
                      ].reduce((a, b) => a > b ? a : b) +
                      4)
                  .clamp(44.0, double.infinity);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CafeDetailsTokens.gutter,
                  8,
                  CafeDetailsTokens.gutter,
                  0,
                ),
                sliver: SliverGrid.builder(
                  itemCount: photos.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: _gap,
                    mainAxisSpacing: 16,
                    mainAxisExtent:
                        tileWidth / CommunityPhotoTile.aspect + caption,
                  ),
                  itemBuilder: (context, i) => CommunityPhotoTile(
                    key: ValueKey(photos[i].id),
                    photo: photos[i],
                    onOpen: () => openCommunityPhotoViewer(
                      context,
                      photos: photos,
                      index: i,
                      cafeId: cafeId,
                      surface: CafePhotoSurface.grid,
                    ),
                    onOpenAuthor: () => openPhotoAuthor(
                      context,
                      photos[i].credit,
                      cafeId: cafeId,
                      surface: CafePhotoSurface.grid,
                    ),
                  ),
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverToBoxAdapter(
                  child: _Footer(state: state, onRetry: cubit.loadMore),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Under the grid: loading the next page, a failed page with Retry, or the
/// end.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final CafePhotosState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final Widget child;
    if (state.loadingMore) {
      child = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CafeDetailsTokens.brand,
          semanticsLabel: 'Loading more photos',
        ),
      );
    } else if (state.loadMoreFailed) {
      child = Column(
        children: [
          Text(
            'Couldn’t load more photos.',
            style: theme.bodyMedium?.copyWith(
              fontSize: 14,
              color: CafeDetailsTokens.muted,
            ),
          ),
          const SizedBox(height: 4),
          _TextAction(label: 'Try again', onTap: onRetry),
        ],
      );
    } else if (!state.hasMore && state.photos.length > 4) {
      child = Text(
        'That’s every photo so far.',
        style: theme.bodySmall?.copyWith(
          fontSize: 12,
          color: CafeDetailsTokens.muted,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CafeDetailsTokens.gutter,
        20,
        CafeDetailsTokens.gutter,
        28,
      ),
      child: Center(child: child),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A whole-screen message: the first load failed, or there is nothing
/// (every photo was removed since the strip loaded).
class _Message extends StatelessWidget {
  const _Message.empty() : error = null, onRetry = null, _failed = false;

  const _Message.error({required this.error, required this.onRetry})
    : _failed = true;

  final Object? error;
  final VoidCallback? onRetry;
  final bool _failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final info = _failed ? AppErrorCopy.fromException(error ?? '') : null;
    final retry = onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _failed ? LucideIcons.wifiOff : LucideIcons.camera,
              size: 28,
              color: CafeDetailsTokens.muted,
            ),
            const SizedBox(height: 12),
            Text(
              info?.title ?? 'No photos yet',
              textAlign: TextAlign.center,
              style: theme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CafeDetailsTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              info?.subtitle ?? 'Photos from people’s cups show up here.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(
                fontSize: 14,
                color: CafeDetailsTokens.muted,
              ),
            ),
            if (retry != null) ...[
              const SizedBox(height: 8),
              _TextAction(label: 'Try again', onTap: retry),
            ],
          ],
        ),
      ),
    );
  }
}

/// The grid's shape while the first page loads.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading photos',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: CafeDetailsTokens.tint,
          to: Color(0xFFF6F6F6),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final w =
                (box.maxWidth - CafeDetailsTokens.gutter * 2 - _Grid._gap) / 2;
            Widget tile() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(
                  width: w,
                  height: w / CommunityPhotoTile.aspect,
                  uniRadius: CommunityPhotoTile.radius,
                ),
                const SizedBox(height: 10),
                const Bone(width: 96, height: 12, uniRadius: 6),
                const SizedBox(height: 8),
                const Bone(width: 72, height: 12, uniRadius: 6),
              ],
            );
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                CafeDetailsTokens.gutter,
                8,
                CafeDetailsTokens.gutter,
                0,
              ),
              child: Column(
                children: [
                  for (var r = 0; r < 3; r++) ...[
                    if (r > 0) const SizedBox(height: 16),
                    Row(
                      children: [
                        tile(),
                        const SizedBox(width: _Grid._gap),
                        tile(),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
