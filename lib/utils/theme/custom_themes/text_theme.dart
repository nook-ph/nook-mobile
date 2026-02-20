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
  TextStyle get headlineLargeEmp =>
      headlineLarge!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get headlineMediumEmp =>
      headlineMedium!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get headlineSmallEmp =>
      headlineSmall!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get titleLargeEmp =>
      titleLarge!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get titleMediumEmp =>
      titleMedium!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get titleSmallEmp =>
      titleSmall!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get bodyLargeEmp =>
      bodyLarge!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get bodyMediumEmp =>
      bodyMedium!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get bodySmallEmp =>
      bodySmall!.copyWith(fontWeight: FontWeight.w500);

  TextStyle get bodyExtraSmall => bodySmall!.copyWith(fontSize: 12.0);

  TextStyle get bodyExtraSmallEmp =>
      bodyExtraSmall.copyWith(fontWeight: FontWeight.w500);
}
