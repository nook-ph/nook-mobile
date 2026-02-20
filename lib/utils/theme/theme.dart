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
  );
}
