import 'package:flutter/material.dart';
import '../../data/onboarding_data.dart';

class OnboardingImageWidget extends StatelessWidget {
    final OnboardingModel model;

    const OnboardingImageWidget({super.key, required this.model});

    @override
    Widget build(BuildContext context) {
        // Just the Image Container (No Text)
        return Center(
            child: Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20)
                ),
                // In the future: child: Image.asset(model.image),
                child: const Icon(Icons.image, size: 80, color: Colors.grey)
            )
        );
    }
}