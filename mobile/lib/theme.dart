import 'package:flutter/material.dart';

import 'liquid_glass/liquid_glass.dart';

// Design tokens adapted from src/styles/globals.css
class AppTheme {
  // Brand blue (matches Home button in navbar)
  static const _brandBlue = Color(0xFF2563EB);
  static const _lightPrimary = _brandBlue;
  static const _lightBackground = Color(0xFFFFFFFF);
  static const _lightForeground = Color(0xFF232326); // approx oklch(0.145 0 0)
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightAccent = Color(0xFFE9EBEF);
  static const _lightBorder = Color(0x1A000000); // rgba(0,0,0,0.1)

  // Dark palette tuned for contrast and separation
  static const _darkBackground = Color(0xFF14161B);
  static const _darkForeground = Color(
    0xFFEAECEF,
  ); // near-white for strong contrast
  static const _darkCard = Color(
    0xFF1D2128,
  ); // slightly lighter than bg so cards stand out
  static const _darkMuted = Color(0xFF2A2F37); // separators / containers

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: Colors.white,
      surface: _lightCard,
      onSurface: _lightForeground,
      secondary: _lightAccent,
      onSecondary: _lightForeground,
      outline: _lightBorder,
    );
    final filledButtonStyle = _filledButtonStyle(_brandBlue, Colors.white);
    final elevatedButtonStyle = _elevatedButtonStyle(_brandBlue, Colors.white);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightCard,
      textTheme: base.textTheme.apply(
        bodyColor: _lightForeground,
        displayColor: _lightForeground,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fill: LGColors.surfaceSolidLight,
        text: _lightForeground,
        muted: LGColors.textSecondaryLight,
        border: _lightBorder,
      ),
      dialogTheme: _dialogTheme(scheme, isDark: false),
      bottomSheetTheme: _bottomSheetTheme(scheme, isDark: false),
      chipTheme: _chipTheme(base, scheme, isDark: false),
      listTileTheme: _listTileTheme(scheme, isDark: false),
      dividerTheme: DividerThemeData(color: _lightBorder, thickness: 1),
      snackBarTheme: _snackBarTheme(scheme, isDark: false),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle(scheme)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(scheme, isDark: false),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.lg),
        ),
        elevation: 8,
      ),
      shadowColor: const Color(0x66000000),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LGRadius.xl)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightForeground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LGColors.glassStrongLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LGColors.alpha(_brandBlue, 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.pill),
        ),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _brandBlue : LGColors.textSecondaryLight,
          );
        }),
      ),
      cardTheme: const CardThemeData(
        elevation: 8,
        shadowColor: Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
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
      surface: _darkCard,
      onSurface: _darkForeground,
      secondary: _darkMuted,
      onSecondary: _darkForeground,
      outline: const Color(0xFF3C414A),
    );
    final filledButtonStyle = _filledButtonStyle(_brandBlue, Colors.white);
    final elevatedButtonStyle = _elevatedButtonStyle(_brandBlue, Colors.white);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkCard,
      inputDecorationTheme: _inputDecorationTheme(
        fill: _darkCard,
        text: _darkForeground,
        muted: LGColors.textSecondaryDark,
        border: const Color(0xFF3C414A),
      ),
      dialogTheme: _dialogTheme(scheme, isDark: true),
      bottomSheetTheme: _bottomSheetTheme(scheme, isDark: true),
      chipTheme: _chipTheme(base, scheme, isDark: true),
      listTileTheme: _listTileTheme(scheme, isDark: true),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF333843),
        thickness: 1,
      ),
      snackBarTheme: _snackBarTheme(scheme, isDark: true),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle(scheme)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(scheme, isDark: true),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: _darkForeground, displayColor: _darkForeground)
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              color: _darkForeground.withValues(alpha: 0.85),
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              color: _darkForeground.withValues(alpha: 0.92),
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.lg),
        ),
        elevation: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      shadowColor: const Color(0xF0000000),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LGRadius.xl)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkForeground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LGColors.glassStrongDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _brandBlue.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.pill),
        ),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _brandBlue : LGColors.textSecondaryDark,
          );
        }),
      ),
      cardTheme: const CardThemeData(
        elevation: 10,
        shadowColor: Color(0xF0000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerColor: const Color(0xFF333843),
    );
  }

  static InputDecorationThemeData _inputDecorationTheme({
    required Color fill,
    required Color text,
    required Color muted,
    required Color border,
  }) {
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LGRadius.lg),
      borderSide: BorderSide(color: border),
    );
    return InputDecorationThemeData(
      filled: true,
      fillColor: fill,
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.74)),
      prefixIconColor: muted,
      suffixIconColor: muted,
      isDense: false,
      constraints: const BoxConstraints(minHeight: LGForm.fieldMinHeight),
      contentPadding: LGForm.fieldContentPadding,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: TextStyle(
        color: _brandBlue,
        fontWeight: FontWeight.w800,
        backgroundColor: fill,
      ),
      border: normalBorder,
      enabledBorder: normalBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        borderSide: const BorderSide(color: _brandBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        borderSide: const BorderSide(color: LGColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        borderSide: const BorderSide(color: LGColors.danger, width: 1.4),
      ),
    );
  }

  static DialogThemeData _dialogTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return DialogThemeData(
      backgroundColor:
          isDark ? LGColors.glassStrongDark : LGColors.glassStrongLight,
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 18 : 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.xxl),
        side: BorderSide(
          color: isDark ? LGColors.glassStrokeDark : LGColors.glassStrokeLight,
        ),
      ),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(
        color:
            isDark ? LGColors.textSecondaryDark : LGColors.textSecondaryLight,
        fontSize: 14,
      ),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return BottomSheetThemeData(
      backgroundColor:
          isDark ? LGColors.glassStrongDark : LGColors.glassStrongLight,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor:
          isDark ? LGColors.glassStrongDark : LGColors.glassStrongLight,
      modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.58 : 0.36),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LGRadius.xl),
        ),
        side: BorderSide(
          color: isDark ? LGColors.glassStrokeDark : LGColors.glassStrokeLight,
        ),
      ),
      showDragHandle: true,
      dragHandleColor:
          isDark ? LGColors.textSecondaryDark : LGColors.textSecondaryLight,
    );
  }

  static ChipThemeData _chipTheme(
    ThemeData base,
    ColorScheme scheme, {
    required bool isDark,
  }) {
    final background =
        isDark ? LGColors.surfaceTintedDark : LGColors.surfaceTintedLight;
    return base.chipTheme.copyWith(
      backgroundColor: background,
      selectedColor: LGColors.primaryBlue.withValues(
        alpha: isDark ? 0.24 : 0.14,
      ),
      disabledColor: background.withValues(alpha: 0.48),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: LGColors.primaryBlue,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color:
            isDark
                ? LGColors.glassStrokeDark
                : LGColors.primaryBlue.withValues(alpha: 0.12),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
    );
  }

  static ListTileThemeData _listTileTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return ListTileThemeData(
      iconColor:
          isDark ? LGColors.textSecondaryDark : LGColors.textSecondaryLight,
      textColor: scheme.onSurface,
      selectedColor: LGColors.primaryBlue,
      selectedTileColor: LGColors.primaryBlue.withValues(
        alpha: isDark ? 0.18 : 0.08,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.lg,
        vertical: LGSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return SnackBarThemeData(
      backgroundColor: isDark ? LGColors.surfaceSolidDark : LGColors.deepNavy,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
      ),
      actionTextColor: LGColors.electricBlue,
    );
  }

  static ButtonStyle _textButtonStyle(ColorScheme scheme) {
    return TextButton.styleFrom(
      foregroundColor: scheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  static ButtonStyle _outlinedButtonStyle(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: scheme.primary,
      side: BorderSide(
        color: scheme.primary.withValues(alpha: isDark ? 0.48 : 0.32),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  static ButtonStyle _filledButtonStyle(Color background, Color foreground) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  static ButtonStyle _elevatedButtonStyle(Color background, Color foreground) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.pill),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}
