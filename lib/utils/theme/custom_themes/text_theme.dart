import 'package:flutter/material.dart';

class TTextTheme {
  TTextTheme._();

  static TextTheme lightTextTheme = TextTheme(
    titleLarge: const TextStyle(
      fontSize: 24.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    titleMedium: const TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    bodyLarge: const TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
    bodyMedium: const TextStyle(
      fontSize: 15.0,
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
  TextStyle get titleLargeSemi =>
      titleLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get titleMediumSemi =>
      titleMedium!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyLargeMed =>
      bodyLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyLargeSemi =>
      bodyLarge!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyMediumMed =>
      bodyMedium!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodySmallMed =>
      bodySmall!.copyWith(fontWeight: FontWeight.w500);
  TextStyle get bodyExtraSmall => bodySmall!.copyWith(fontSize: 12.0);
  TextStyle get bodyExtraSmallMed =>
      bodyExtraSmall.copyWith(fontWeight: FontWeight.w500);
}
