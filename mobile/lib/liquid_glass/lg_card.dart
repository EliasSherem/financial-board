import 'package:flutter/material.dart';

import 'lg_glass.dart';
import 'lg_tokens.dart';

enum LGCardVariant { standard, elevated, interactive, hero }

class LGGlassCard extends StatelessWidget {
  const LGGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LGSpacing.lg),
    this.margin,
    this.onTap,
    this.variant = LGCardVariant.standard,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final LGCardVariant variant;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return LGGlassSurface(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(_radius),
      blur: _blur,
      intensity: _intensity,
      onTap: onTap,
      shadows: _shadows(context),
      child: child,
    );
  }

  double get _radius {
    return switch (variant) {
      LGCardVariant.hero => LGRadius.xxl,
      LGCardVariant.elevated => LGRadius.xl,
      LGCardVariant.interactive => LGRadius.xl,
      LGCardVariant.standard => LGRadius.lg,
    };
  }

  double get _blur {
    return switch (variant) {
      LGCardVariant.hero => LGBlur.strong,
      LGCardVariant.elevated => LGBlur.medium,
      LGCardVariant.interactive => LGBlur.medium,
      LGCardVariant.standard => LGBlur.subtle,
    };
  }

  LGGlassIntensity get _intensity {
    return switch (variant) {
      LGCardVariant.hero => LGGlassIntensity.strong,
      LGCardVariant.elevated => LGGlassIntensity.medium,
      LGCardVariant.interactive => LGGlassIntensity.medium,
      LGCardVariant.standard => LGGlassIntensity.light,
    };
  }

  List<BoxShadow> _shadows(BuildContext context) {
    return switch (variant) {
      LGCardVariant.hero => LGShadows.lifted(context),
      LGCardVariant.elevated => LGShadows.glass(context),
      LGCardVariant.interactive => LGShadows.glass(context),
      LGCardVariant.standard => LGShadows.none,
    };
  }
}

class LGSolidCard extends StatelessWidget {
  const LGSolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LGSpacing.lg),
    this.margin,
    this.onTap,
    this.variant = LGCardVariant.standard,
    this.tinted = false,
    this.borderRadius,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final LGCardVariant variant;
  final bool tinted;
  final BorderRadius? borderRadius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(_radius);
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color:
            tinted
                ? LGColors.surfaceTinted(context)
                : LGColors.surfaceSolid(context),
        borderRadius: radius,
        border:
            showBorder
                ? Border.all(
                  color: LGColors.alpha(
                    LGColors.textSecondary(context),
                    LGColors.isDark(context) ? 0.18 : 0.12,
                  ),
                )
                : null,
        boxShadow: _shadows(context),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }

  double get _radius {
    return switch (variant) {
      LGCardVariant.hero => LGRadius.xxl,
      LGCardVariant.elevated => LGRadius.xl,
      LGCardVariant.interactive => LGRadius.xl,
      LGCardVariant.standard => LGRadius.lg,
    };
  }

  List<BoxShadow> _shadows(BuildContext context) {
    return switch (variant) {
      LGCardVariant.hero => LGShadows.lifted(context),
      LGCardVariant.elevated => LGShadows.solid(context),
      LGCardVariant.interactive => LGShadows.solid(context),
      LGCardVariant.standard => LGShadows.none,
    };
  }
}
