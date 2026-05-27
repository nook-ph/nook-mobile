import 'package:flutter/material.dart';
export 'package:nook/utils/theme/custom_themes/color_scheme.dart';
export 'package:nook/utils/theme/custom_themes/text_theme.dart';

extension ContextTheme on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
