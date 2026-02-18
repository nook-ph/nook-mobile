import 'package:flutter/material.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nook',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.green,
        fontFamily: 'Poppins',
      ),
      home: const OnboardingPage(),
    );
  }
}