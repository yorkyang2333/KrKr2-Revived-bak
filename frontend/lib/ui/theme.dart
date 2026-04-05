import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color defaultSeedColor = Color(0xFF0F6C78);

  static ThemeData lightTheme(ColorScheme? dynamicLight) {
    final ColorScheme scheme =
        dynamicLight ??
        ColorScheme.fromSeed(
          seedColor: defaultSeedColor,
          brightness: Brightness.light,
        );

    return _themeFromScheme(
      scheme,
      baseTextTheme: GoogleFonts.ibmPlexSansTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme? dynamicDark) {
    final ColorScheme scheme =
        dynamicDark ??
        ColorScheme.fromSeed(
          seedColor: defaultSeedColor,
          brightness: Brightness.dark,
        );

    return _themeFromScheme(
      scheme,
      baseTextTheme: GoogleFonts.ibmPlexSansTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }

  static TextStyle mono(
    BuildContext context, {
    Color? color,
    double? fontSize,
  }) {
    return GoogleFonts.jetBrainsMono(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      color: color,
      fontSize: fontSize,
    );
  }

  static ThemeData _themeFromScheme(
    ColorScheme scheme, {
    required TextTheme baseTextTheme,
  }) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: baseTextTheme,
    );
  }
}
