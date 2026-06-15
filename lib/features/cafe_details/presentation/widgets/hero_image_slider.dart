import 'package:flutter/material.dart';

class HeroImageSlider extends StatefulWidget {
  const HeroImageSlider({
    super.key,
    required this.images,
    required this.isLoading,
  });

  final List<String> images;
  final bool isLoading;

  @override
  State<HeroImageSlider> createState() => _HeroImageSliderState();
}

class _HeroImageSliderState extends State<HeroImageSlider> {
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
        height: 350,
        width: double.infinity,
        color: Colors.grey[300],
      );
    }

    final displayImages = widget.images;
    final hasImages = displayImages.isNotEmpty;
    final total = hasImages ? displayImages.length : 1;

    return SizedBox(
      height: 350,
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
                return Image.network(
                  displayImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF9E9E9E),
                      ),
                    );
                  },
                );
              },
            )
          else
            Container(
              height: 350,
              width: double.infinity,
              color: Colors.grey[300],
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, color: Color(0xFF9E9E9E)),
            ),

          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_currentIndex + 1}/$total',
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
