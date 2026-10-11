import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_photo_placeholder.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

class HeroImageSlider extends StatefulWidget {
  const HeroImageSlider({
    super.key,
    required this.images,
    required this.isLoading,
    this.bottomInset = 0,
    this.onImageTap,
    this.placeholderSeed,
    this.onClaimTap,
  });

  /// Picks the sample photo; pass the cafe's name.
  final String? placeholderSeed;

  /// Set for an unclaimed cafe: the empty state then invites the owner to
  /// claim it and add photos.
  final VoidCallback? onClaimTap;

  /// Opens the full-screen viewer at the tapped photo.
  final void Function(int index)? onImageTap;

  final List<String> images;
  final bool isLoading;

  /// How much of the photo's bottom edge the sheet covers; the counter is
  /// lifted by this much so it stays visible above the sheet's lip.
  final double bottomInset;

  @override
  State<HeroImageSlider> createState() => _HeroImageSliderState();
}

class _HeroImageSliderState extends State<HeroImageSlider> {
  static const double _height = 298;

  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        height: _height,
        width: double.infinity,
        color: const Color(0xFFDCDCDC),
      );
    }

    final displayImages = widget.images;
    final hasImages = displayImages.isNotEmpty;
    final total = hasImages ? displayImages.length : 1;

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: Stack(
        children: [
          if (hasImages)
            PageView.builder(
              controller: _pageController,
              itemCount: displayImages.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = CafeCardImage(
                  imageUrl: displayImages[index],
                  placeholderSeed: widget.placeholderSeed,
                );
                final onTap = widget.onImageTap;
                if (onTap == null) return image;
                return Semantics(
                  button: true,
                  label:
                      'Photo ${index + 1} of ${displayImages.length}. '
                      'Opens full screen.',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: image,
                  ),
                );
              },
            )
          else
            _NoPhotosHero(
              seed: widget.placeholderSeed,
              bottomInset: widget.bottomInset,
              onClaimTap: widget.onClaimTap,
            ),

          // No counter without photos: "1 / 1" over a placeholder says nothing.
          if (hasImages)
            Positioned(
              bottom: 16 + widget.bottomInset,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentIndex + 1} / $total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The hero of a cafe with no photos: the cafe's sample photo at full height,
/// marked "Sample photo", and for an unclaimed cafe a link asking the owner to
/// claim it and add real ones. Both sit where the photo counter would, above
/// the sheet's lip.
class _NoPhotosHero extends StatelessWidget {
  const _NoPhotosHero({
    required this.seed,
    required this.bottomInset,
    required this.onClaimTap,
  });

  final String? seed;
  final double bottomInset;
  final VoidCallback? onClaimTap;

  @override
  Widget build(BuildContext context) {
    final claim = onClaimTap;
    return Stack(
      fit: StackFit.expand,
      children: [
        CafePhotoPlaceholder(seed: seed, showLabel: false),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottomInset,
          // Side by side when they fit; at large text sizes the link wraps
          // under the label rather than being cut off.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const SamplePhotoPill(),
              if (claim != null) _AddPhotosLink(onTap: claim),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Own this café? Add photos", in the same quiet pill as the label beside it.
class _AddPhotosLink extends StatelessWidget {
  const _AddPhotosLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: Colors.white,
      height: 1.3,
    );
    return Semantics(
      link: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Own this café? '),
                  TextSpan(
                    text: 'Add photos',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}
