import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/gallery/presentation/stories/cafe_story_viewer_page.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/community_photo_actions.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Adds a photo of [cafe] to the signed-in person's gallery. True when one
/// was added.
typedef AddCafePhoto =
    Future<bool> Function(BuildContext context, PickedCafe cafe);

/// "Latest cups": the newest photos people posted at this cafe, near the
/// top of its page as a stories tray, one ring per person, newest first,
/// opening a full-screen story viewer (docs/references/cafe-stories:
/// Instagram's tray, Google Maps' header). "See all" opens every photo as
/// a grid ([CafePhotosPage]).
///
/// Draws its own divider, so it can leave the page entirely: on a failed
/// load (the rest of the page is what matters), and on a cafe with no
/// photos unless the person has been there, when it asks for the first.
class CafeCommunityPhotosSection extends StatelessWidget {
  const CafeCommunityPhotosSection({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.cafeArea,
    this.cafeImageUrl,
    this.cubit,
    this.seen,
    this.addPhoto,
    this.reviewOf,
  });

  final String cafeId;
  final String cafeName;
  final String? cafeArea;
  final String? cafeImageUrl;

  /// For tests; the app builds one per page.
  final CafePhotosCubit? cubit;

  /// For tests; the app keeps seen photos in SharedPreferences.
  final StorySeenCubit? seen;

  /// For tests; the app runs the gallery's add flow.
  final AddCafePhoto? addPhoto;

  /// For tests; the app reads the reviews the page already loaded.
  final StoryReview? Function(String reviewId)? reviewOf;

  @override
  Widget build(BuildContext context) {
    final givenCubit = cubit;
    final givenSeen = seen;
    return MultiBlocProvider(
      providers: [
        if (givenCubit != null)
          BlocProvider.value(value: givenCubit)
        else
          BlocProvider(
            create: (_) => sl<CafePhotosCubit>(param1: cafeId)..load(),
          ),
        if (givenSeen != null)
          BlocProvider.value(value: givenSeen)
        else
          BlocProvider(create: (_) => StorySeenCubit()..load()),
      ],
      child: _Body(section: this),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.section});

  final CafeCommunityPhotosSection section;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _loggedView = false;

  String get _cafeId => widget.section.cafeId;

  /// The app's add flow, when the gallery is set up (not in most tests).
  AddCafePhoto? get _addPhoto {
    final given = widget.section.addPhoto;
    if (given != null) return given;
    if (!sl.isRegistered<GalleryCubit>() ||
        !sl.isRegistered<GalleryPhotoPicker>() ||
        !sl.isRegistered<ICafePickerSource>()) {
      return null;
    }
    return (context, cafe) async {
      final deps = GalleryFlowDeps(
        cubit: sl<GalleryCubit>(),
        picker: sl<GalleryPhotoPicker>(),
        cafes: sl<ICafePickerSource>(),
      );
      return await addCafePhoto(context, deps, cafe: cafe) != null;
    };
  }

  Future<void> _add(AddCafePhoto add) async {
    logAppEvent(
      CafePhotoEvents.addTapped,
      properties: {'cafe_id': _cafeId, 'surface': CafePhotoSurface.strip},
    );
    final section = widget.section;
    final cubit = context.read<CafePhotosCubit>();
    final added = await add(
      context,
      PickedCafe(
        id: section.cafeId,
        name: section.cafeName,
        area: section.cafeArea,
        imageUrl: section.cafeImageUrl,
      ),
    );
    if (added && mounted) await cubit.load(refresh: true);
  }

  void _openAll(CafePhotosState state) {
    logAppEvent(
      CafePhotoEvents.seeAllTapped,
      properties: {'cafe_id': _cafeId, 'surface': CafePhotoSurface.strip},
    );
    CafePhotosPage.open(
      context,
      cafeId: _cafeId,
      cafeName: widget.section.cafeName,
      seed: state,
    );
  }

  /// The review a review photo came from, out of the reviews the page has
  /// already loaded: no extra read. Null when it isn't among them.
  StoryReview? _reviewOf(String reviewId) {
    final given = widget.section.reviewOf;
    if (given != null) return given(reviewId);
    final ReviewsBloc bloc;
    try {
      bloc = context.read<ReviewsBloc>();
    } catch (_) {
      return null;
    }
    final state = bloc.state;
    if (state is! ReviewsLoaded) return null;
    for (final review in state.reviews) {
      if (review.id == reviewId) {
        return StoryReview(rating: review.rating, text: review.content);
      }
    }
    return null;
  }

  void _openStories(List<CafeStory> stories, int index) {
    final seen = context.read<StorySeenCubit>();
    logAppEvent(
      CafeStoryEvents.opened,
      properties: {
        'cafe_id': _cafeId,
        'story_position': index,
        'story_count': stories.length,
        'unseen': !stories[index].isSeenIn(seen.state),
      },
    );
    unawaited(
      CafeStoryViewerPage.open(
        context,
        stories: stories,
        initialStory: index,
        cafeId: _cafeId,
        seen: seen,
        reviewOf: _reviewOf,
        onOpenAuthor: (credit) => PublicProfilePage.open(
          context,
          userId: credit.userId,
          nameHint: '@${credit.username}',
          source: ProfileViewSource.cafePhotos,
        ),
        onReport: communityPhotoReportable()
            ? (photo) => reportCommunityPhoto(context, photo)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CafePhotosCubit, CafePhotosState>(
      listenWhen: (_, now) =>
          !_loggedView &&
          now.status == CafePhotosStatus.loaded &&
          now.photos.isNotEmpty,
      listener: (_, state) {
        _loggedView = true;
        logAppEvent(
          CafePhotoEvents.viewed,
          properties: {
            'cafe_id': _cafeId,
            'surface': CafePhotoSurface.strip,
            'count': state.total,
          },
        );
      },
      builder: (context, state) {
        final Widget? content = switch (state.status) {
          CafePhotosStatus.initial ||
          CafePhotosStatus.loading => const _TraySkeleton(),
          // Quietly gone: photos are a bonus, not what the page is for.
          CafePhotosStatus.failed => null,
          // Brings its own divider: it may turn out to be nothing.
          CafePhotosStatus.loaded when state.photos.isEmpty => _emptyPrompt(),
          CafePhotosStatus.loaded => _trayFor(state),
        };
        if (content == null) return const SizedBox.shrink();
        if (state.isEmpty) return content;
        return _withDivider(content);
      },
    );
  }

  Widget _trayFor(CafePhotosState state) {
    final stories = groupCafeStories(state.photos);
    final add = _addPhoto;
    final hasOwn = stories.any((s) => s.credit.isSelf);
    Widget tray({VoidCallback? onAdd}) => _Tray(
      stories: stories,
      total: state.total,
      onOpen: (i) => _openStories(stories, i),
      onSeeAll: state.total > 1 ? () => _openAll(state) : null,
      onAdd: onAdd,
    );
    // Your own slot first, as on Instagram: "Add your cup" for someone who
    // has been and has no cup here yet.
    if (add == null || hasOwn) return tray();
    return BlocBuilder<CafeStatusCubit, CafeStatusState>(
      buildWhen: (a, b) => a.statusFor(_cafeId) != b.statusFor(_cafeId),
      builder: (context, statuses) => tray(
        onAdd: statuses.statusFor(_cafeId) == CafeStatus.been
            ? () => _add(add)
            : null,
      ),
    );
  }

  /// Only for someone who has been: they are the ones with a photo to
  /// add. Everyone else sees nothing rather than an empty box on most
  /// cafes.
  Widget? _emptyPrompt() {
    final add = _addPhoto;
    if (add == null) return null;
    return BlocBuilder<CafeStatusCubit, CafeStatusState>(
      buildWhen: (a, b) => a.statusFor(_cafeId) != b.statusFor(_cafeId),
      builder: (context, statuses) {
        if (statuses.statusFor(_cafeId) != CafeStatus.been) {
          return const SizedBox.shrink();
        }
        return _withDivider(_EmptyPrompt(onAdd: () => _add(add)));
      },
    );
  }
}

Widget _withDivider(Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [const CafeSectionDivider(), child],
);

/// The title row: "Latest cups", the count, and "See all" at the trailing
/// edge (Google Maps' photo header).
class _Header extends StatelessWidget {
  const _Header({required this.total, this.onSeeAll});

  final int total;
  final VoidCallback? onSeeAll;

  static const title = 'Latest cups';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final seeAll = onSeeAll;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The title takes what it needs; "See all" keeps its width.
          Expanded(
            child: Row(
              children: [
                const Flexible(child: CafeSectionTitle(title)),
                if (total > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$total',
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
              label: 'See all $total cups',
              excludeSemantics: true,
              child: AdaptiveTap(
                onTap: seeAll,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
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
              ),
            ),
        ],
      ),
    );
  }
}

/// One ring per person who posted here, newest first, in a row that runs
/// off the right edge (Instagram's tray). The ring holds their newest cup,
/// not their face: the photo is what the page is for, and most people
/// have no profile photo. Their avatar sits on it as a badge.
class _Tray extends StatelessWidget {
  const _Tray({
    required this.stories,
    required this.total,
    required this.onOpen,
    required this.onSeeAll,
    required this.onAdd,
  });

  final List<CafeStory> stories;
  final int total;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final add = onAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(total: total, onSeeAll: onSeeAll),
        const SizedBox(height: 8),
        BlocBuilder<StorySeenCubit, Set<String>>(
          builder: (context, seen) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: CafeDetailsTokens.gutter - _StorySlot.inset,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (add != null) _AddSlot(onTap: add),
                for (var i = 0; i < stories.length; i++)
                  _StorySlot(
                    story: stories[i],
                    seen: stories[i].isSeenIn(seen),
                    onTap: () => onOpen(i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A person in the tray: their newest cup in a ring, split into one arc
/// per cup, brand green while any is new and grey once all are seen; their
/// name and how long ago underneath.
class _StorySlot extends StatelessWidget {
  const _StorySlot({
    required this.story,
    required this.seen,
    required this.onTap,
  });

  final CafeStory story;
  final bool seen;
  final VoidCallback onTap;

  /// The ring's outer size, and the photo inside its gap.
  static const ring = 76.0;
  static const photo = 66.0;
  static const width = 96.0;

  /// Half the space between slots, so the first ring lines up with the
  /// page gutter.
  static const inset = (width - ring) / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final credit = story.credit;
    final count = story.photos.length;
    final age = storyAgeLabel(story.latestAt, DateTime.now());
    final cups = count == 1 ? '1 cup' : '$count cups';
    return Semantics(
      button: true,
      label:
          '${credit.isSelf ? 'Your' : '${credit.label}’s'} $cups, $age'
          '${seen ? '' : ', new'}. Open',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: ring,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: StoryRingPainter(
                            segments: count,
                            color: seen
                                ? StoryRingPainter.seenColor
                                : CafeDetailsTokens.brand,
                            width: seen ? 1.5 : 2.5,
                          ),
                        ),
                      ),
                      Center(
                        child: ClipOval(
                          child: SizedBox.square(
                            dimension: photo,
                            child: GalleryImage(
                              url: story.latest.photo.imageUrl,
                              cacheWidth: math.max(
                                1,
                                (photo * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: ProfileAvatar(
                              name: credit.username,
                              size: 24,
                              imageUrl: credit.avatarUrl,
                              initialSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  credit.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: seen ? FontWeight.w400 : FontWeight.w600,
                    color: CafeDetailsTokens.ink,
                  ),
                ),
                Text(
                  // The cup count says more than a date here; the viewer has
                  // the date on every photo.
                  count == 1 ? age : cups,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: CafeDetailsTokens.muted,
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

/// The ring around a person's cup: one arc per cup with small gaps, like
/// WhatsApp's status ring, so "3 cups" shows before you open it.
class StoryRingPainter extends CustomPainter {
  const StoryRingPainter({
    required this.segments,
    required this.color,
    required this.width,
  });

  /// Seen rings: quiet, but still a ring against the white page.
  static const seenColor = Color(0xFFBDBDBD);

  final int segments;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(width / 2 + 0.5);
    final n = segments.clamp(1, 12);
    if (n == 1) {
      canvas.drawOval(rect, paint);
      return;
    }
    const gap = 0.16; // radians
    final sweep = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StoryRingPainter old) =>
      old.segments != segments || old.color != color || old.width != width;
}

/// "Add your cup", first in the tray, for someone who has been here and
/// has no cup in it yet (Instagram's "Your story" slot).
class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Add your cup',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _StorySlot.width,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: _StorySlot.ring,
                  child: Center(
                    child: Container(
                      width: _StorySlot.photo,
                      height: _StorySlot.photo,
                      decoration: const BoxDecoration(
                        color: CafeDetailsTokens.tint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.plus,
                        size: 24,
                        color: CafeDetailsTokens.brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your cup',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: CafeDetailsTokens.ink,
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

/// One community photo: the photo, then a caption with what it was (or
/// when) and who added it. The photo opens the viewer; the caption opens
/// their profile. Shared by the strip and the "See all" grid.
class CommunityPhotoTile extends StatelessWidget {
  const CommunityPhotoTile({
    super.key,
    required this.photo,
    required this.onOpen,
    required this.onOpenAuthor,
  });

  final CommunityPhoto photo;
  final VoidCallback onOpen;
  final VoidCallback onOpenAuthor;

  static const aspect = 4 / 5;
  static const radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final credit = photo.credit;
    final drink = photo.photo.drinkName?.trim();
    final what = drink == null || drink.isEmpty
        ? galleryMonthLabel(photo.photo.takenAt)
        : drink;
    final label = credit.isSelf ? 'Added by you' : 'Added by ${credit.label}';

    final caption = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            what,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CafeDetailsTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ProfileAvatar(
                name: credit.username,
                size: 20,
                imageUrl: credit.avatarUrl,
                initialSize: 10,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  credit.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: credit.isSelf
                        ? CafeDetailsTokens.brand
                        : CafeDetailsTokens.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          image: true,
          label: '$what, ${label.toLowerCase()}. Open photo',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(
                aspectRatio: aspect,
                child: LayoutBuilder(
                  builder: (context, box) => GalleryImage(
                    url: photo.photo.imageUrl,
                    cacheWidth: math.max(
                      1,
                      (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (credit.isSelf)
          Semantics(label: label, excludeSemantics: true, child: caption)
        else
          Semantics(
            button: true,
            label: 'Open ${credit.label}’s profile',
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: onOpenAuthor,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: caption,
              ),
            ),
          ),
      ],
    );
  }
}

/// No cups yet, for someone who has been: ask for the first one.
class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(total: 0),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: CafeDetailsTokens.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 20,
                  color: CafeDetailsTokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No cups yet',
                      style: theme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CafeDetailsTokens.ink,
                      ),
                    ),
                    Text(
                      'Be the first to add one from your visit.',
                      style: theme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: CafeDetailsTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Add your cup',
                excludeSemantics: true,
                child: AdaptiveTap(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(999),
                  // 32 tall as drawn, 44 to touch, like "Write a review".
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: CafeDetailsTokens.brand),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Add your cup',
                        style: theme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CafeDetailsTokens.brand,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tray's shape while it loads: title, then three rings with their
/// two label lines, so nothing jumps when the cups arrive.
class _TraySkeleton extends StatelessWidget {
  const _TraySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading latest cups',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: CafeDetailsTokens.tint,
          to: Color(0xFFF6F6F6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Bone(width: 120, height: 18, uniRadius: 6),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0)
                      const SizedBox(width: _StorySlot.width - _StorySlot.ring),
                    const Column(
                      children: [
                        Bone.circle(size: _StorySlot.ring),
                        SizedBox(height: 8),
                        Bone(width: 56, height: 10, uniRadius: 5),
                        SizedBox(height: 6),
                        Bone(width: 32, height: 10, uniRadius: 5),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
