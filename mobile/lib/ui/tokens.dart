import 'package:flutter/material.dart';

enum FSIntent { primary, success, warning, danger, info, neutral }

class FSColors {
  const FSColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF0F2A52);
  static const accent = Color(0xFF38BDF8);

  static const backgroundLight = Color(0xFFF8FAFC);
  static const backgroundDark = Color(0xFF020617);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF0F172A);
  static const surfaceElevatedLight = Color(0xFFFFFFFF);
  static const surfaceElevatedDark = Color(0xFF111C31);
  static const borderLight = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFF243047);
  static const mutedTextLight = Color(0xFF64748B);
  static const mutedTextDark = Color(0xFF94A3B8);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);
  static const neutral = Color(0xFF64748B);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color background(BuildContext context) {
    return isDark(context) ? backgroundDark : backgroundLight;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? surfaceDark : surfaceLight;
  }

  static Color surfaceElevated(BuildContext context) {
    return isDark(context) ? surfaceElevatedDark : surfaceElevatedLight;
  }

  static Color border(BuildContext context) {
    return isDark(context) ? borderDark : borderLight;
  }

  static Color mutedText(BuildContext context) {
    return isDark(context) ? mutedTextDark : mutedTextLight;
  }

  static Color alpha(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static Color intent(FSIntent intent) {
    switch (intent) {
      case FSIntent.primary:
        return primary;
      case FSIntent.success:
        return success;
      case FSIntent.warning:
        return warning;
      case FSIntent.danger:
        return danger;
      case FSIntent.info:
        return info;
      case FSIntent.neutral:
        return neutral;
    }
  }

  static Color intentContainer(BuildContext context, FSIntent intent) {
    final color = FSColors.intent(intent);
    return alpha(color, isDark(context) ? 0.18 : 0.10);
  }

  static Color intentBorder(BuildContext context, FSIntent intent) {
    final color = FSColors.intent(intent);
    return alpha(color, isDark(context) ? 0.32 : 0.20);
  }
}

class FSSpacing {
  const FSSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class FSRadius {
  const FSRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;

  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(radius);
  }
}

class FSShadows {
  const FSShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> soft(BuildContext context) {
    if (FSColors.isDark(context)) {
      return [
        BoxShadow(
          color: FSColors.alpha(Colors.black, 0.26),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ];
    }
    return [
      BoxShadow(
        color: FSColors.alpha(const Color(0xFF0F172A), 0.07),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> elevated(BuildContext context) {
    if (FSColors.isDark(context)) {
      return [
        BoxShadow(
          color: FSColors.alpha(Colors.black, 0.36),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
      ];
    }
    return [
      BoxShadow(
        color: FSColors.alpha(const Color(0xFF0F172A), 0.10),
        blurRadius: 32,
        offset: const Offset(0, 18),
      ),
    ];
  }

  static List<BoxShadow> interactive(BuildContext context) {
    if (FSColors.isDark(context)) {
      return [
        BoxShadow(
          color: FSColors.alpha(Colors.black, 0.32),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ];
    }
    return [
      BoxShadow(
        color: FSColors.alpha(const Color(0xFF2563EB), 0.10),
        blurRadius: 28,
        offset: const Offset(0, 16),
      ),
    ];
  }
}
