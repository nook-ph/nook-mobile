import 'package:flutter/material.dart';

class TTextTheme {
  TTextTheme._();

  static TextTheme lightTextTheme = TextTheme(
    headlineLarge: const TextStyle(
      fontSize: 48.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    headlineMedium: const TextStyle(
      fontSize: 40.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    headlineSmall: const TextStyle(
      fontSize: 32.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    titleLarge: const TextStyle(
      fontSize: 24.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    titleMedium: const TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    titleSmall: const TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    bodySmall: const TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
  );
}

extension CustomText on TextTheme {
  // Medium (w500)
  TextStyle get headlineLargeMed =>
      headlineLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get headlineMediumMed =>
      headlineMedium!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get headlineSmallMed =>
      headlineSmall!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get titleLargeMed =>
      titleLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get titleMediumMed =>
      titleMedium!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get titleSmallMed =>
      titleSmall!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyLargeMed =>
      bodyLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyMediumMed =>
      bodyMedium!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodySmallMed =>
      bodySmall!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyExtraSmall => bodySmall!.copyWith(fontSize: 12.0);
  TextStyle get bodyExtraSmallMed =>
      bodyExtraSmall.copyWith(fontWeight: FontWeight.w500);

  TextStyle get headlineLargeSemi =>
      headlineLarge!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get headlineMediumSemi =>
      headlineMedium!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get headlineSmallSemi =>
      headlineSmall!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get titleLargeSemi =>
      titleLarge!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get titleMediumSemi =>
      titleMedium!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get titleSmallSemi =>
      titleSmall!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get bodyLargeSemi =>
      bodyLarge!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get bodyMediumSemi =>
      bodyMedium!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get bodySmallSemi =>
      bodySmall!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get bodyExtraSmallSemi =>
      bodyExtraSmall.copyWith(fontWeight: FontWeight.w600);
}
