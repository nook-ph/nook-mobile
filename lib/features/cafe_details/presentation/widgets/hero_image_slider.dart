import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_photo_placeholder.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

  /// Picks the no-photo tint; pass the cafe's name.
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

/// The hero of a cafe with no photos: the no-photo surface at full height,
/// a larger cup, "No photos yet", and for an unclaimed cafe a link asking the
/// owner to claim it and add photos. Content sits below the app bar's buttons
/// and above the sheet's lip.
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
    final tint = CafePhotoPlaceholder.tintFor(seed);
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight * 0.5;
    final claim = onClaimTap;
    return ColoredBox(
      color: tint.surface,
      child: Padding(
        padding: EdgeInsets.only(top: top, bottom: bottomInset),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
                size: 44,
                color: tint.ink,
                duotoneSecondaryOpacity: 0.18,
              ),
              const SizedBox(height: 8),
              Text(
                'No photos yet',
                style: text.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tint.ink,
                ),
              ),
              if (claim != null) ...[
                const SizedBox(height: 2),
                Semantics(
                  link: true,
                  child: AdaptiveTap(
                    onTap: claim,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Own this café? '),
                            TextSpan(
                              text: 'Add photos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: tint.ink,
                              ),
                            ),
                          ],
                        ),
                        style: text.bodyMedium?.copyWith(color: tint.ink),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
