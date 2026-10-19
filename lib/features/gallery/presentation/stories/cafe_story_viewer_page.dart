import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/presentation/stories/story_position.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

/// The story viewer's dark ground and text, the gallery viewer's green-black
/// rather than pure black.
abstract final class StoryViewerTokens {
  static const ground = Color(0xFF0E1110);
  static const text = Color(0xFFF4F5F3);
  static const muted = Color(0xFFB4B8B5);
  static const chip = Color(0x29FFFFFF);
  static const track = Color(0x4DFFFFFF);
}

/// A cafe's latest cups, full screen, one person at a time (TikTok's story
/// layout: bars, then who and when, the photo, the words under it;
/// docs/references/cafe-stories).
///
/// Each photo shows for [photoDuration], then the next; holding pauses.
/// Tap the right two thirds for the next photo, the left third for the
/// previous; swipe sideways between people and down to close. With Reduce
/// Motion on nothing advances by itself: every move is a tap.
class CafeStoryViewerPage extends StatefulWidget {
  const CafeStoryViewerPage({
    super.key,
    required this.stories,
    required this.initialStory,
    required this.cafeId,
    required this.seen,
    this.reviewOf,
    this.onOpenAuthor,
    this.onReport,
    this.onShare,
    this.photoDuration = defaultPhotoDuration,
    this.autoAdvance,
  });

  static const defaultPhotoDuration = Duration(seconds: 5);

  final List<CafeStory> stories;
  final int initialStory;
  final String cafeId;
  final StorySeenCubit seen;

  /// The review a review photo came from, by review id, when the page has
  /// it. Null, or a null result, shows the photo's own note instead.
  final StoryReview? Function(String reviewId)? reviewOf;

  /// The poster tapped: their profile. Never called for your own.
  final Future<void> Function(PhotoCredit credit)? onOpenAuthor;

  /// "…" → Report on someone else's photo. Null hides it (signed out).
  final Future<void> Function(CommunityPhoto photo)? onReport;

  /// Share on your own photo (docs/features/share_cup_story.md §3.3).
  /// Null hides it.
  final Future<void> Function(CommunityPhoto photo)? onShare;

  final Duration photoDuration;

  /// Overrides Reduce Motion, for tests. Null follows the system setting.
  final bool? autoAdvance;

  /// Pushes the viewer over [context], opening [stories] at [initialStory].
  static Future<void> open(
    BuildContext context, {
    required List<CafeStory> stories,
    required int initialStory,
    required String cafeId,
    required StorySeenCubit seen,
    StoryReview? Function(String reviewId)? reviewOf,
    Future<void> Function(PhotoCredit credit)? onOpenAuthor,
    Future<void> Function(CommunityPhoto photo)? onReport,
    Future<void> Function(CommunityPhoto photo)? onShare,
  }) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: ScreenNames.storyViewer),
        opaque: true,
        transitionDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 200),
        reverseTransitionDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => CafeStoryViewerPage(
          stories: stories,
          initialStory: initialStory,
          cafeId: cafeId,
          seen: seen,
          reviewOf: reviewOf,
          onOpenAuthor: onOpenAuthor,
          onReport: onReport,
          onShare: onShare,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<CafeStoryViewerPage> createState() => _CafeStoryViewerPageState();
}

class _CafeStoryViewerPageState extends State<CafeStoryViewerPage>
    with SingleTickerProviderStateMixin {
  late StoryPosition _position;
  late final PageController _pages;
  late final AnimationController _clock;

  /// Held down, or a sheet or profile is open over the viewer.
  bool _held = false;
  int _blockers = 0;

  /// A finger is swiping between people: the clock waits for it to let
  /// go, so the next photo can't advance (or close the viewer) mid-swipe.
  bool _swiping = false;

  /// The current photo's image has arrived (or failed): the clock may run.
  bool _ready = false;

  /// Bumped on every move, so a late image load can't start the clock for
  /// a photo already left.
  int _shown = 0;
  double _dragDown = 0;
  bool _closing = false;

  List<CafeStory> get _stories => widget.stories;
  CafeStory get _story => _stories[_position.story];
  CommunityPhoto get _photo => _story.photos[_position.photo];

  bool get _autoAdvance =>
      widget.autoAdvance ?? !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _position = StoryPosition.startOf(
      _stories,
      widget.initialStory,
      widget.seen.state,
    );
    _pages = PageController(initialPage: widget.initialStory);
    _clock = AnimationController(vsync: this, duration: widget.photoDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  @override
  void dispose() {
    _clock.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// The photo at [_position] is on screen: count it, mark it seen, and
  /// start its clock once the image is in.
  void _show() {
    if (!mounted) return;
    final shown = ++_shown;
    final photo = _photo;
    _clock.stop();
    _clock.value = 0;
    _ready = false;
    widget.seen.markSeen(photo.id);
    logAppEvent(
      CafeStoryEvents.viewed,
      properties: {
        'cafe_id': widget.cafeId,
        'photo_id': photo.id,
        'story_position': _position.story,
        'photo_position': _position.photo,
      },
    );
    unawaited(
      _precache(photo).then((_) {
        if (!mounted || shown != _shown) return;
        setState(() => _ready = true);
        _run();
        _preloadNext();
      }),
    );
  }

  Future<void> _precache(CommunityPhoto photo) {
    final url = photo.photo.imageUrl;
    if (!url.startsWith('http')) return Future.value();
    // Completes on failure too: a photo that won't load still gets its
    // turn, showing that it didn't.
    return precacheImage(
      CachedNetworkImageProvider(url),
      context,
      onError: (_, _) {},
    );
  }

  void _preloadNext() {
    final next = _position.next(_stories, widget.seen.state);
    if (next.done) return;
    unawaited(_precache(_stories[next.story].photos[next.photo]));
  }

  /// Runs the clock when nothing holds it.
  void _run() {
    if (!mounted ||
        !_ready ||
        _held ||
        _swiping ||
        _blockers > 0 ||
        !_autoAdvance) {
      return;
    }
    _clock.forward();
  }

  void _moveTo(StoryPosition to) {
    if (_closing) return;
    if (to.done) {
      logAppEvent(
        CafeStoryEvents.completed,
        properties: {'cafe_id': widget.cafeId, 'story_count': _stories.length},
      );
      _close();
      return;
    }
    final changesPerson = to.story != _position.story;
    setState(() => _position = to);
    if (changesPerson && _pages.hasClients) {
      // The page change lands in onPageChanged, which shows the photo.
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(to.story);
      } else {
        _pages.animateToPage(
          to.story,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
    _show();
  }

  void _next() => _moveTo(_position.next(_stories, widget.seen.state));

  void _previous() => _moveTo(_position.previous(_stories));

  void _onPageChanged(int index) {
    if (index == _position.story) return;
    setState(
      () =>
          _position = StoryPosition.startOf(_stories, index, widget.seen.state),
    );
    _show();
  }

  /// Pauses the clock while the person drags the pages (not when a page
  /// change animates on its own) and starts it again once they let go.
  bool _onPagesScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _swiping = true;
      _clock.stop();
    } else if (n is ScrollEndNotification && _swiping) {
      _swiping = false;
      _run();
    }
    return false;
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _clock.stop();
    Navigator.of(context).maybePop();
  }

  void _hold(bool held) {
    setState(() => _held = held);
    if (held) {
      _clock.stop();
    } else {
      _run();
    }
  }

  /// Pauses while [task] has something over the viewer.
  Future<void> _paused(Future<void> Function() task) async {
    _blockers++;
    _clock.stop();
    try {
      await task();
    } finally {
      _blockers--;
      if (mounted) _run();
    }
  }

  void _openAuthor(PhotoCredit credit) {
    final open = widget.onOpenAuthor;
    if (credit.isSelf || open == null) return;
    logAppEvent(
      CafeStoryEvents.authorTapped,
      properties: {'cafe_id': widget.cafeId, 'photo_id': _photo.id},
    );
    unawaited(_paused(() => open(credit)));
  }

  void _report() {
    final report = widget.onReport;
    if (report == null) return;
    final photo = _photo;
    unawaited(_paused(() => report(photo)));
  }

  void _share() {
    final share = widget.onShare;
    if (share == null) return;
    final photo = _photo;
    unawaited(_paused(() => share(photo)));
  }

  void _onTapUp(TapUpDetails details, double width) {
    if (details.localPosition.dx < width / 3) {
      _previous();
    } else {
      _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: StoryViewerTokens.ground,
        body: GestureDetector(
          // Down to close: the page follows the finger, then goes or
          // springs back.
          onVerticalDragUpdate: (d) => setState(
            () => _dragDown = (_dragDown + d.delta.dy).clamp(0, height),
          ),
          onVerticalDragStart: (_) => _clock.stop(),
          onVerticalDragEnd: (d) {
            if (_dragDown > 120 || (d.primaryVelocity ?? 0) > 700) {
              _close();
            } else {
              setState(() => _dragDown = 0);
              _run();
            }
          },
          child: Transform.translate(
            offset: Offset(0, _dragDown),
            child: Opacity(
              opacity: (1 - _dragDown / height).clamp(0.4, 1.0),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onPagesScroll,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _stories.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final active = i == _position.story;
                    final photoIndex = active
                        ? _position.photo
                        : _stories[i].startIndexFor(widget.seen.state);
                    return _StoryFrame(
                      story: _stories[i],
                      photoIndex: photoIndex,
                      clock: active ? _clock : null,
                      showClock: _autoAdvance,
                      chromeHidden: active && _held,
                      reviewOf: widget.reviewOf,
                      onTapUp: _onTapUp,
                      onHold: _hold,
                      onClose: _close,
                      onNext: _next,
                      onPrevious: _previous,
                      onOpenAuthor: widget.onOpenAuthor == null
                          ? null
                          : _openAuthor,
                      onReport: widget.onReport == null ? null : _report,
                      onShare: widget.onShare == null ? null : _share,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One person's story at one photo: bars, header, photo, words.
class _StoryFrame extends StatelessWidget {
  const _StoryFrame({
    required this.story,
    required this.photoIndex,
    required this.clock,
    required this.showClock,
    required this.chromeHidden,
    required this.reviewOf,
    required this.onTapUp,
    required this.onHold,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
    required this.onOpenAuthor,
    required this.onReport,
    required this.onShare,
  });

  final CafeStory story;
  final int photoIndex;

  /// The running clock on the active person; null on a neighbour.
  final Animation<double>? clock;
  final bool showClock;
  final bool chromeHidden;
  final StoryReview? Function(String reviewId)? reviewOf;
  final void Function(TapUpDetails details, double width) onTapUp;
  final ValueChanged<bool> onHold;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<PhotoCredit>? onOpenAuthor;
  final VoidCallback? onReport;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final photo = story.photos[photoIndex];
    final credit = story.credit;
    final sourceId = photo.photo.sourceId;
    final review =
        photo.cup ??
        (photo.photo.isFromReview && sourceId != null
            ? reviewOf?.call(sourceId)
            : null);
    final still = MediaQuery.disableAnimationsOf(context);
    final chrome = Duration(milliseconds: still ? 0 : 150);

    final drink = photo.photo.drinkName?.trim();
    final what = drink == null || drink.isEmpty
        ? 'Photo at ${photo.photo.cafeName}'
        : '$drink at ${photo.photo.cafeName}';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: chromeHidden ? 0 : 1,
            duration: chrome,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: _Segments(
                    count: story.photos.length,
                    current: photoIndex,
                    clock: clock,
                    showClock: showClock,
                  ),
                ),
                _Header(
                  credit: credit,
                  age: storyAgeLabel(photo.photo.takenAt, DateTime.now()),
                  onOpenAuthor: onOpenAuthor,
                  onClose: onClose,
                  onReport: credit.isSelf ? null : onReport,
                  onShare: credit.isSelf ? onShare : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Semantics(
                container: true,
                image: true,
                label:
                    '$what, by ${credit.isSelf ? 'you' : credit.label}. '
                    'Photo ${photoIndex + 1} of ${story.photos.length}',
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Next photo'): onNext,
                  const CustomSemanticsAction(label: 'Previous photo'):
                      onPrevious,
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => onTapUp(d, box.maxWidth),
                  onLongPressStart: (_) => onHold(true),
                  onLongPressEnd: (_) => onHold(false),
                  onLongPressCancel: () => onHold(false),
                  child: GalleryImage(
                    key: ValueKey(photo.id),
                    url: photo.photo.imageUrl,
                    fit: BoxFit.contain,
                    dark: true,
                  ),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: chromeHidden ? 0 : 1,
            duration: chrome,
            child: _Words(
              key: ValueKey('words-${photo.id}'),
              drink: drink == null || drink.isEmpty ? null : drink,
              review: review,
              note: photo.photo.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// One bar per photo: done ones full, the current one filling with the
/// clock, the rest empty. Without the clock (Reduce Motion) the current
/// one is simply full.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.count,
    required this.current,
    required this.clock,
    required this.showClock,
  });

  final int count;
  final int current;
  final Animation<double>? clock;
  final bool showClock;

  @override
  Widget build(BuildContext context) {
    Widget bar(double fill) => ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 2.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: StoryViewerTokens.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill.clamp(0.0, 1.0),
              child: const ColoredBox(color: StoryViewerTokens.text),
            ),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: i < current
                  ? bar(1)
                  : i > current
                  ? bar(0)
                  : clock == null || !showClock
                  ? bar(showClock ? 0 : 1)
                  : AnimatedBuilder(
                      animation: clock!,
                      builder: (_, _) => bar(clock!.value),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Who posted it and when, with "…" and close at the trailing edge.
class _Header extends StatelessWidget {
  const _Header({
    required this.credit,
    required this.age,
    required this.onOpenAuthor,
    required this.onClose,
    required this.onReport,
    required this.onShare,
  });

  final PhotoCredit credit;
  final String age;
  final ValueChanged<PhotoCredit>? onOpenAuthor;
  final VoidCallback onClose;
  final VoidCallback? onReport;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final linked = !credit.isSelf && onOpenAuthor != null;
    final who = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatar(
          name: credit.username,
          size: 32,
          imageUrl: credit.avatarUrl,
          initialSize: 13,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            credit.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: StoryViewerTokens.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          age,
          maxLines: 1,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: StoryViewerTokens.muted,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: linked
                  ? Semantics(
                      button: true,
                      label: 'Open ${credit.label}’s profile, posted $age',
                      excludeSemantics: true,
                      child: AdaptiveTap(
                        onTap: () => onOpenAuthor!(credit),
                        borderRadius: BorderRadius.circular(22),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: who,
                          ),
                        ),
                      ),
                    )
                  : Semantics(
                      label:
                          'Added by ${credit.isSelf ? 'you' : credit.label}'
                          ', $age',
                      excludeSemantics: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: who,
                      ),
                    ),
            ),
          ),
          if (onShare != null)
            _IconButton(
              icon: LucideIcons.send,
              label: 'Share your cup',
              onTap: onShare!,
            ),
          if (onReport != null)
            _IconButton(
              icon: LucideIcons.ellipsis,
              label: 'Photo options',
              onTap: onReport!,
            ),
          _IconButton(icon: LucideIcons.x, label: 'Close', onTap: onClose),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
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
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, size: 22, color: StoryViewerTokens.text),
        ),
      ),
    );
  }
}

/// Under the photo, at the bottom-left: the drink, then the review's
/// stars and words when it came from one, else the poster's own note. A
/// long text shows three lines; a tap opens the rest in place.
class _Words extends StatefulWidget {
  const _Words({super.key, this.drink, this.review, this.note});

  final String? drink;
  final StoryReview? review;
  final String? note;

  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> {
  bool _open = false;

  static const _textStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    height: 1.45,
    color: StoryViewerTokens.text,
  );

  @override
  Widget build(BuildContext context) {
    final drink = widget.drink;
    final review = widget.review;
    final reviewText = review?.text.trim();
    final note = widget.note?.trim();
    final text = reviewText != null && reviewText.isNotEmpty
        ? reviewText
        : (note == null || note.isEmpty ? null : note);
    if (drink == null && review?.rating == null && text == null) {
      return const SizedBox(height: 20);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (drink != null)
            Text(
              drink,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: StoryViewerTokens.text,
              ),
            ),
          if (review?.rating case final stars?) ...[
            if (drink != null) const SizedBox(height: 6),
            _Stars(rating: stars),
          ],
          if (text != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.3,
              ),
              child: SingleChildScrollView(
                child: Semantics(
                  button: !_open,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _open = !_open),
                    child: Text(
                      text,
                      maxLines: _open ? null : 3,
                      overflow: _open ? null : TextOverflow.ellipsis,
                      style: _textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final stars = rating.clamp(0, 5);
    return Semantics(
      container: true,
      label: 'Rated $stars out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.star_rounded,
                size: 18,
                color: i < stars
                    ? StoryViewerTokens.text
                    : StoryViewerTokens.track,
              ),
            ),
        ],
      ),
    );
  }
}
