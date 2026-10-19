import 'package:flutter/material.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class TAppTheme {
  TAppTheme._();

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    textTheme: TTextTheme.lightTextTheme,
    colorScheme: TColorScheme.lightColorScheme,
    // The scheme's surface is transparent (docs/design_system.md), and the
    // date picker dialog draws on it: give it the app's white.
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Color(0xFFFEFEFE),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
