import 'package:flutter/material.dart';
import '../../data/onboarding_data.dart';

class OnboardingImageWidget extends StatelessWidget {
    final OnboardingModel model;

    const OnboardingImageWidget({super.key, required this.model});

    @override
    Widget build(BuildContext context) {
     
        return Center(
          child: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20)
            ),

            child: const Icon(Icons.image, size: 60, color: Colors.grey)
          )
        );
    }
}