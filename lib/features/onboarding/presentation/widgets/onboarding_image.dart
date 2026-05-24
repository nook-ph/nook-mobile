import 'package:flutter/material.dart';
import '../../data/onboarding_data.dart';

class OnboardingImageWidget extends StatelessWidget {
  final OnboardingModel model;

  const OnboardingImageWidget({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          model.imagePath,
          height: 300,
          width: 300,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
