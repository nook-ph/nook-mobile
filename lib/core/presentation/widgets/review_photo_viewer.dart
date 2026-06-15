import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

Future<void> showReviewPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? heroTagPrefix,
}) {
  if (imageUrls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ReviewPhotoViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
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
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTagPrefix;

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
        _dragY > _dismissDistanceThreshold || velocity > _dismissVelocityThreshold;
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
                  color: Colors.black.withValues(alpha: 0.87 * backdropOpacity),
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
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildTopBar(),
                          Expanded(
                            child: _buildGallery(),
                          ),
                        ],
                      ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (total > 1)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / $total',
                    style: context.textTheme.bodySmallMed.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              child: _CircleIconButton(
                icon: Icons.close,
                onTap: () => Navigator.of(context).pop(),
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
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      builder: (context, index) {
        final url = widget.imageUrls[index];
        return PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(url),
          heroAttributes: index == widget.initialIndex
              ? PhotoViewHeroAttributes(tag: _tagFor(index))
              : null,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          controller: _controllerFor(index),
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9E9E9E),
              size: 48,
            ),
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
