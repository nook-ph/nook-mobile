import 'package:flutter/material.dart';
import '../../data/onboarding_data.dart';

class OnboardingContentWidget extends StatelessWidget {
    final OnboardingModel model;

    const OnboardingContentWidget({super.key, required this.model});

    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
                children: [
                  const Spacer(),

                    Container(
                        height: 300,
                        width: 300,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.rectangle
                        )
                    ),

                  const Spacer(flex: 5),

                    Text(
                        model.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF344E41),
                            height: 1.3
                        )
                    ),

                    const SizedBox(height: 10),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                            model.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF0A0F0D)
                            )
                        )
                    ),

                  const Spacer(),
                ]
            )
        );
    }
}