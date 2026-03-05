import 'package:flutter/material.dart';

class TColorScheme {
  TColorScheme._();

  static ColorScheme lightColorScheme = ColorScheme.light(
    surface: const Color(0xFFFEFEFE),
    error: const Color(0xFFD11A17),
    outline: const Color(0xFFE0E0E0),
  );
}

extension CustomColor on ColorScheme {
  Color get success => const Color(0xFF0F893E);
  Color get warning => const Color(0xFFE0AB38);

  Color get black => const Color(0xFF0A0F0D);
  Color get gray => const Color(0xFF868584);

  Color get primary100 => const Color(0xFF344E41);
  Color get primary80 => const Color(0xFF3A5A40);
  Color get primary60 => const Color(0xFF588157);
  Color get primary40 => const Color(0xFFA3B18A);
  Color get primary20 => const Color(0xFFDAD7CD);
}
