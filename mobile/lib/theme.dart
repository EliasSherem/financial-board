import 'package:flutter/material.dart';

// Design tokens adapted from src/styles/globals.css
class AppTheme {
  // Brand blue (matches Home button in navbar)
  static const _brandBlue = Color(0xFF2563EB);
  static const _lightPrimary = _brandBlue;
  static const _lightBackground = Color(0xFFFFFFFF);
  static const _lightForeground = Color(0xFF232326); // approx oklch(0.145 0 0)
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightMuted = Color(0xFFECECF0);
  static const _lightAccent = Color(0xFFE9EBEF);
  static const _lightBorder = Color(0x1A000000); // rgba(0,0,0,0.1)

  // Dark palette tuned for contrast and separation
  static const _darkBackground = Color(0xFF14161B);
  static const _darkForeground = Color(0xFFEAECEF); // near-white for strong contrast
  static const _darkCard = Color(0xFF1D2128);       // slightly lighter than bg so cards stand out
  static const _darkMuted = Color(0xFF2A2F37);      // separators / containers

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: Colors.white,
      background: _lightBackground,
      onBackground: _lightForeground,
      surface: _lightCard,
      onSurface: _lightForeground,
      secondary: _lightAccent,
      onSecondary: _lightForeground,
      outline: _lightBorder,
    );
    final filledButtonStyle = FilledButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
    );
    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightCard,
      textTheme: base.textTheme.apply(bodyColor: _lightForeground, displayColor: _lightForeground),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      shadowColor: const Color(0x66000000),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightForeground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightBackground,
        indicatorColor: _lightMuted,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w500)),
      ),
      cardTheme: const CardThemeData(
        elevation: 8,
        shadowColor: Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dividerColor: _lightBorder,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.dark,
      primary: _brandBlue,
      onPrimary: Colors.white,
      background: _darkBackground,
      onBackground: _darkForeground,
      surface: _darkCard,
      onSurface: _darkForeground,
      secondary: _darkMuted,
      onSecondary: _darkForeground,
      outline: const Color(0xFF3C414A),
    );
    final filledButtonStyle = FilledButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
    );
    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkCard,
      textTheme: base.textTheme.apply(
        bodyColor: _darkForeground,
        displayColor: _darkForeground,
      ).copyWith(
        bodySmall: base.textTheme.bodySmall?.copyWith(color: _darkForeground.withOpacity(0.85)),
        labelLarge: base.textTheme.labelLarge?.copyWith(color: _darkForeground.withOpacity(0.92)),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      shadowColor: const Color(0xF0000000),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkForeground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkBackground,
        indicatorColor: _brandBlue.withOpacity(0.18),
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600)),
      ),
      cardTheme: const CardThemeData(
        elevation: 10,
        shadowColor: Color(0xF0000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dividerColor: const Color(0xFF333843),
    );
  }
}
