import 'package:flutter/material.dart';

enum LGIntent { primary, success, warning, danger, info, neutral }

class LGColors {
  const LGColors._();

  static const primaryBlue = Color(0xFF2563EB);
  static const deepNavy = Color(0xFF071327);
  static const electricBlue = Color(0xFF38BDF8);

  static const backgroundLight = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF07101D);

  static const surfaceSolidLight = Color(0xFFFFFFFF);
  static const surfaceSolidDark = Color(0xFF111827);
  static const surfaceTintedLight = Color(0xFFF6F9FC);
  static const surfaceTintedDark = Color(0xFF141C2A);

  static const glassLightLight = Color(0xB8FFFFFF);
  static const glassLightDark = Color(0x7A172033);
  static const glassMediumLight = Color(0xD9FFFFFF);
  static const glassMediumDark = Color(0x99172033);
  static const glassStrongLight = Color(0xF2FFFFFF);
  static const glassStrongDark = Color(0xDD111827);

  static const glassStrokeLight = Color(0x99B8C4D8);
  static const glassStrokeDark = Color(0x406EA8FF);

  static const textPrimaryLight = Color(0xFF111827);
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryLight = Color(0xFF64748B);
  static const textSecondaryDark = Color(0xFFB6C2D2);

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

  static Color backgroundStart(BuildContext context) {
    return background(context);
  }

  static Color backgroundEnd(BuildContext context) {
    return background(context);
  }

  static Color surfaceSolid(BuildContext context) {
    return isDark(context) ? surfaceSolidDark : surfaceSolidLight;
  }

  static Color surfaceTinted(BuildContext context) {
    return isDark(context) ? surfaceTintedDark : surfaceTintedLight;
  }

  static Color glassLight(BuildContext context) {
    return isDark(context) ? glassLightDark : glassLightLight;
  }

  static Color glassMedium(BuildContext context) {
    return isDark(context) ? glassMediumDark : glassMediumLight;
  }

  static Color glassStrong(BuildContext context) {
    return isDark(context) ? glassStrongDark : glassStrongLight;
  }

  static Color glassStroke(BuildContext context) {
    return isDark(context) ? glassStrokeDark : glassStrokeLight;
  }

  static Color textPrimary(BuildContext context) {
    return isDark(context) ? textPrimaryDark : textPrimaryLight;
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? textSecondaryDark : textSecondaryLight;
  }

  static Color alpha(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static Color intentColor(LGIntent intent) {
    switch (intent) {
      case LGIntent.primary:
        return primaryBlue;
      case LGIntent.success:
        return success;
      case LGIntent.warning:
        return warning;
      case LGIntent.danger:
        return danger;
      case LGIntent.info:
        return info;
      case LGIntent.neutral:
        return neutral;
    }
  }

  static Color intentContainer(BuildContext context, LGIntent intent) {
    return alpha(intentColor(intent), isDark(context) ? 0.18 : 0.10);
  }

  static Color intentStroke(BuildContext context, LGIntent intent) {
    return alpha(intentColor(intent), isDark(context) ? 0.34 : 0.18);
  }
}

class LGSpacing {
  const LGSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class LGRadius {
  const LGRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(radius);
  }
}

class LGBlur {
  const LGBlur._();

  static const double none = 0;
  static const double subtle = 8;
  static const double medium = 14;
  static const double strong = 20;
}

class LGShadows {
  const LGShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> glass(BuildContext context) {
    if (LGColors.isDark(context)) {
      return [
        BoxShadow(
          color: LGColors.alpha(Colors.black, 0.34),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ];
    }
    return [
      BoxShadow(
        color: LGColors.alpha(const Color(0xFF0F172A), 0.12),
        blurRadius: 30,
        offset: const Offset(0, 16),
      ),
    ];
  }

  static List<BoxShadow> floating(BuildContext context) {
    if (LGColors.isDark(context)) {
      return [
        BoxShadow(
          color: LGColors.alpha(Colors.black, 0.42),
          blurRadius: 34,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: LGColors.alpha(LGColors.primaryBlue, 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return [
      BoxShadow(
        color: LGColors.alpha(const Color(0xFF0F172A), 0.13),
        blurRadius: 34,
        offset: const Offset(0, 18),
      ),
      BoxShadow(
        color: LGColors.alpha(Colors.white, 0.80),
        blurRadius: 8,
        offset: const Offset(0, -1),
      ),
    ];
  }

  static List<BoxShadow> solid(BuildContext context) {
    if (LGColors.isDark(context)) {
      return [
        BoxShadow(
          color: LGColors.alpha(Colors.black, 0.24),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ];
    }
    return [
      BoxShadow(
        color: LGColors.alpha(const Color(0xFF0F172A), 0.07),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> lifted(BuildContext context) {
    if (LGColors.isDark(context)) {
      return [
        BoxShadow(
          color: LGColors.alpha(Colors.black, 0.34),
          blurRadius: 34,
          offset: const Offset(0, 20),
        ),
      ];
    }
    return [
      BoxShadow(
        color: LGColors.alpha(LGColors.primaryBlue, 0.07),
        blurRadius: 36,
        offset: const Offset(0, 20),
      ),
    ];
  }
}
