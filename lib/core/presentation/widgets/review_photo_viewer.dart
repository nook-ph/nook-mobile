import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// The second caption line: "May 23, 2026 · Tadaima", or whichever half is
/// known. Null when neither is.
String? reviewPhotoCaptionDetail({String? date, String? cafeName}) {
  final parts = [
    date?.trim() ?? '',
    cafeName?.trim() ?? '',
  ].where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Full-screen photos. For a review's photos pass [author], [date] and
/// [cafeName] to caption them with who posted and where; leave all three
/// out (cafe hero photos, profile) for no caption.
Future<void> showReviewPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? heroTagPrefix,
  String? author,
  String? date,
  String? cafeName,
}) {
  if (imageUrls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      // The viewer paints its own black backdrop so a swipe down can fade
      // it with the photo.
      barrierColor: Colors.transparent,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ReviewPhotoViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
          author: author,
          captionDetail: reviewPhotoCaptionDetail(
            date: date,
            cafeName: cafeName,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class ReviewPhotoViewer extends StatefulWidget {
  const ReviewPhotoViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    this.heroTagPrefix,
    this.author,
    this.captionDetail,
    this.imageProvider,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTagPrefix;

  /// Who posted the photo. With [captionDetail], shown bottom-left.
  final String? author;
  final String? captionDetail;

  /// Where a photo comes from. Defaults to the app's disk-cached provider;
  /// tests pass their own, as the cache needs platform plugins.
  final ImageProvider Function(String url)? imageProvider;

  @override
  State<ReviewPhotoViewer> createState() => _ReviewPhotoViewerState();
}

class _ReviewPhotoViewerState extends State<ReviewPhotoViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _dismissAnim;
  final Map<int, PhotoViewController> _controllers = {};
  final Map<int, StreamSubscription<PhotoViewControllerValue>> _subs = {};
  final Map<int, double> _initialScales = {};
  int _currentIndex = 0;
  PhotoViewControllerValue? _activePhotoValue;
  double _dragY = 0;
  double _dismissFrom = 0;
  double _dismissTo = 0;
  bool _dismissing = false;

  static const double _dismissDistanceThreshold = 120;
  static const double _dismissVelocityThreshold = 700;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _dismissAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_onDismissTick);
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    _dismissAnim.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _tagFor(int index) {
    if (widget.heroTagPrefix != null) {
      return '${widget.heroTagPrefix}-$index';
    }
    return 'photo-${widget.imageUrls[index].hashCode}';
  }

  PhotoViewController _controllerFor(int index) {
    final existing = _controllers[index];
    if (existing != null) return existing;
    final c = PhotoViewController();
    _controllers[index] = c;
    _subs[index] = c.outputStateStream.listen((value) {
      if (!mounted) return;
      if (index == _currentIndex) {
        setState(() => _activePhotoValue = value);
      }
      final scale = value.scale;
      if (scale != null && !_initialScales.containsKey(index)) {
        _initialScales[index] = scale;
      }
    });
    return c;
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _activePhotoValue = null;
    });
  }

  bool get _isAtMinScale {
    final v = _activePhotoValue;
    if (v == null) return true;
    final scale = v.scale;
    if (scale == null) return true;
    final initial = _initialScales[_currentIndex];
    if (initial == null) return true;
    return scale <= initial + 0.02;
  }

  void _onDismissTick() {
    if (!mounted) return;
    setState(() {
      _dragY = _dismissFrom + (_dismissTo - _dismissFrom) * _dismissAnim.value;
    });
  }

  void _onDragStart(DragStartDetails details) {
    if (_dismissing) return;
    if (!_isAtMinScale) return;
    _dismissAnim.stop();
    setState(() => _dragY = 0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    if (!_isAtMinScale) return;
    final next = (_dragY + details.delta.dy).clamp(0.0, double.infinity);
    if (next == _dragY) return;
    setState(() => _dragY = next);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    if (!_isAtMinScale) {
      if (_dragY != 0) {
        setState(() => _dragY = 0);
      }
      return;
    }
    final velocity = details.primaryVelocity ?? 0.0;
    final shouldDismiss =
        _dragY > _dismissDistanceThreshold ||
        velocity > _dismissVelocityThreshold;
    final size = MediaQuery.of(context).size;
    final target = shouldDismiss ? size.height : 0.0;
    _runDismissAnimation(target, dismiss: shouldDismiss);
  }

  void _runDismissAnimation(double target, {bool dismiss = false}) {
    _dismissing = true;
    _dismissFrom = _dragY;
    _dismissTo = target;
    _dismissAnim
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (dismiss) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dismissing = false;
            _dragY = 0;
          });
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final progress = (_dragY / size.height).clamp(0.0, 1.0);
    final backdropOpacity = 1.0 - progress;
    final scale = 1.0 - progress * 0.15;
    final author = widget.author?.trim() ?? '';
    final detail = widget.captionDetail?.trim() ?? '';
    final hasCaption = author.isNotEmpty || detail.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.black.withValues(alpha: backdropOpacity),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: backdropOpacity,
                    // The photo centres on the whole screen; the counter,
                    // close button and pager dots sit over it.
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildGallery()),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(bottom: false, child: _buildTopBar()),
                        ),
                        if (widget.imageUrls.length > 1 || hasCaption)
                          Positioned(
                            left: hasCaption ? 20 : 16,
                            right: hasCaption ? 20 : 16,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                // The caption sits 25 above the home
                                // indicator area; bare dots keep their 34.
                                padding: EdgeInsets.only(
                                  bottom: hasCaption ? 25 : 34,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.imageUrls.length > 1)
                                      _PagerDots(
                                        count: widget.imageUrls.length,
                                        index: _currentIndex,
                                      ),
                                    if (hasCaption) ...[
                                      if (widget.imageUrls.length > 1)
                                        const SizedBox(height: 16),
                                      _Caption(author: author, detail: detail),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final total = widget.imageUrls.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // No counter for a single photo: "1 / 1" says nothing.
            if (total > 1)
              Text(
                '${_currentIndex + 1} / $total',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _viewerInk,
                ),
              ),
            Positioned(
              left: 0,
              child: Semantics(
                button: true,
                label: 'Close',
                child: _CircleIconButton(
                  icon: LucideIcons.x,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return PhotoViewGallery.builder(
      itemCount: widget.imageUrls.length,
      pageController: _pageController,
      onPageChanged: _onPageChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      scrollPhysics: const BouncingScrollPhysics(),
      loadingBuilder: (context, event) => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      builder: (context, index) {
        final url = widget.imageUrls[index];
        return PhotoViewGalleryPageOptions(
          // Full size, for zooming, but from the same disk cache as the
          // thumbnail that opened it.
          imageProvider:
              widget.imageProvider?.call(url) ??
              CachedNetworkImageProvider(
                url,
                cacheManager: CustomCacheManager.instance,
              ),
          heroAttributes: index == widget.initialIndex
              ? PhotoViewHeroAttributes(tag: _tagFor(index))
              : null,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          controller: _controllerFor(index),
          errorBuilder: (context, error, stack) => const _PhotoUnavailable(),
        );
      },
    );
  }
}

const _viewerInk = Color(0xFFFEFEFE);
const _unavailableGrey = Color(0xFF9A9A9A);

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: _viewerInk, size: 24),
        ),
      ),
    );
  }
}

/// Who posted the photo, then "date · cafe". Either line is left out when
/// it is empty.
class _Caption extends StatelessWidget {
  const _Caption({required this.author, required this.detail});

  final String author;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (author.isNotEmpty)
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _viewerInk,
            ),
          ),
        if (author.isNotEmpty && detail.isNotEmpty) const SizedBox(height: 2),
        if (detail.isNotEmpty)
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: const Color(0xFFC4C4C4),
            ),
          ),
      ],
    );
  }
}

/// One dot per photo; the current one is solid.
class _PagerDots extends StatelessWidget {
  const _PagerDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown in place of a photo that failed to load, in words rather than a
/// broken-image glyph.
class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _unavailableGrey, width: 1.5),
            ),
            child: const CustomPaint(painter: _SlashPainter()),
          ),
          const SizedBox(height: 10),
          Text(
            'Photo could not be loaded',
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: _unavailableGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _unavailableGrey
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) => false;
}
