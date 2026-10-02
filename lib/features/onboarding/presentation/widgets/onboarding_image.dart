import 'package:flutter/material.dart';
import '../../data/onboarding_data.dart';

/// One slide's illustration: the app's artwork at up to 340 square, centred
/// in the slide.
class OnboardingImageWidget extends StatelessWidget {
  final OnboardingModel model;

  const OnboardingImageWidget({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(model.imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
