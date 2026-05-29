import 'package:flutter/material.dart';

import 'ui/finsight_ui.dart';

// Design tokens adapted from the current FinSight web aesthetic.
class AppTheme {
  static const _brandBlue = FSColors.primary;
  static const _lightForeground = Color(0xFF0F172A);
  static const _darkForeground = Color(0xFFE2E8F0);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandBlue,
      brightness: Brightness.light,
      primary: _brandBlue,
      onPrimary: Colors.white,
      surface: FSColors.surfaceLight,
      onSurface: _lightForeground,
      secondary: FSColors.accent,
      onSecondary: _lightForeground,
      outline: FSColors.borderLight,
      error: FSColors.danger,
    );
    return _buildTheme(
      base: base,
      scheme: scheme,
      foreground: _lightForeground,
      background: FSColors.backgroundLight,
      surface: FSColors.surfaceLight,
      surfaceElevated: FSColors.surfaceElevatedLight,
      border: FSColors.borderLight,
      muted: FSColors.mutedTextLight,
      shadow: const Color(0x220F172A),
      isDark: false,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandBlue,
      brightness: Brightness.dark,
      primary: _brandBlue,
      onPrimary: Colors.white,
      surface: FSColors.surfaceDark,
      onSurface: _darkForeground,
      secondary: FSColors.accent,
      onSecondary: _darkForeground,
      outline: FSColors.borderDark,
      error: FSColors.danger,
    );
    return _buildTheme(
      base: base,
      scheme: scheme,
      foreground: _darkForeground,
      background: FSColors.backgroundDark,
      surface: FSColors.surfaceDark,
      surfaceElevated: FSColors.surfaceElevatedDark,
      border: FSColors.borderDark,
      muted: FSColors.mutedTextDark,
      shadow: const Color(0xCC000000),
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required ThemeData base,
    required ColorScheme scheme,
    required Color foreground,
    required Color background,
    required Color surface,
    required Color surfaceElevated,
    required Color border,
    required Color muted,
    required Color shadow,
    required bool isDark,
  }) {
    final radius = BorderRadius.circular(FSRadius.md);
    final fieldBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    );
    final focusedFieldBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: _brandBlue, width: 1.4),
    );
    final errorFieldBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: FSColors.danger),
    );
    final filledButtonStyle = FilledButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
      disabledBackgroundColor: FSColors.alpha(_brandBlue, 0.42),
      disabledForegroundColor: FSColors.alpha(Colors.white, 0.70),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.lg,
        vertical: FSSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: _brandBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.lg,
        vertical: FSSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: surfaceElevated,
      shadowColor: shadow,
      dividerColor: border,
      iconTheme: IconThemeData(color: FSColors.alpha(foreground, 0.82)),
      textTheme: base.textTheme
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              color: muted,
              height: 1.35,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              color: FSColors.alpha(foreground, isDark ? 0.92 : 0.78),
              fontWeight: FontWeight.w600,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? FSColors.alpha(surface, 0.86) : Colors.white,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(
          color: _brandBlue,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FSSpacing.lg,
          vertical: FSSpacing.md,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusedFieldBorder,
        errorBorder: errorFieldBorder,
        focusedErrorBorder: errorFieldBorder,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandBlue,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: FSSpacing.lg,
            vertical: FSSpacing.md,
          ),
          side: BorderSide(color: isDark ? FSColors.borderDark : border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _brandBlue,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: FSSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.lg),
        ),
        elevation: isDark ? 12 : 8,
        shadowColor: shadow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        elevation: isDark ? 8 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.lg),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: FSColors.alpha(foreground, 0.84)),
        actionsIconTheme: IconThemeData(
          color: FSColors.alpha(foreground, 0.84),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: FSColors.alpha(_brandBlue, isDark ? 0.18 : 0.10),
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 8 : 6,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.lg),
          side: BorderSide(color: FSColors.alpha(border, isDark ? 0.78 : 1)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.xl),
          side: BorderSide(color: border),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: foreground,
          height: 1.35,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: FSColors.alpha(muted, 0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FSRadius.xl),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            isDark ? const Color(0xFF17223A) : const Color(0xFFF1F5F9),
        selectedColor: FSColors.alpha(_brandBlue, isDark ? 0.24 : 0.12),
        disabledColor:
            isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
        labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: FSSpacing.sm,
          vertical: FSSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.pill),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _brandBlue,
        textColor: foreground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FSSpacing.lg,
          vertical: FSSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: base.textTheme.bodyLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: base.textTheme.bodySmall?.copyWith(color: muted),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}
