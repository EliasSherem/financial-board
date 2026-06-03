import 'dart:ui';

import 'package:flutter/material.dart';

import 'lg_tokens.dart';

enum LGGlassIntensity { light, medium, strong }

class LGGlassBlur extends StatelessWidget {
  const LGGlassBlur({
    super.key,
    required this.child,
    this.blur = LGBlur.medium,
    this.enabled = true,
  });

  final Widget child;
  final double blur;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || blur <= LGBlur.none) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

class LGGlassSurface extends StatelessWidget {
  const LGGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = const EdgeInsets.all(LGSpacing.lg),
    this.margin,
    this.blur = LGBlur.medium,
    this.intensity = LGGlassIntensity.medium,
    this.opacity = 1,
    this.showBorder = true,
    this.gradient,
    this.onTap,
    this.shadows,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final LGGlassIntensity intensity;
  final double opacity;
  final bool showBorder;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(LGRadius.xl);
    final decoration = BoxDecoration(
      color: gradient == null ? _glassColor(context) : null,
      gradient: gradient,
      borderRadius: radius,
      border:
          showBorder
              ? Border.all(color: LGColors.glassStroke(context), width: 1)
              : null,
      boxShadow: shadows ?? LGShadows.glass(context),
    );

    final content = ClipRRect(
      borderRadius: radius,
      child: LGGlassBlur(
        blur: blur,
        child: Stack(
          children: [
            Positioned.fill(child: DecoratedBox(decoration: decoration)),
            if (showBorder) ...[
              Positioned(
                left: 1,
                right: 1,
                top: 0,
                child: ColoredBox(
                  color:
                      LGColors.isDark(context)
                          ? LGColors.alpha(Colors.white, 0.08)
                          : LGColors.alpha(Colors.white, 0.86),
                  child: const SizedBox(height: 1),
                ),
              ),
              Positioned(
                left: 1,
                right: 1,
                bottom: 0,
                child: ColoredBox(
                  color:
                      LGColors.isDark(context)
                          ? LGColors.alpha(Colors.black, 0.20)
                          : LGColors.alpha(const Color(0xFF64748B), 0.10),
                  child: const SizedBox(height: 1),
                ),
              ),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    final wrapped =
        onTap == null
            ? content
            : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: content,
              ),
            );

    if (margin == null) return wrapped;
    return Padding(padding: margin!, child: wrapped);
  }

  Color _glassColor(BuildContext context) {
    final base = switch (intensity) {
      LGGlassIntensity.light => LGColors.glassLight(context),
      LGGlassIntensity.medium => LGColors.glassMedium(context),
      LGGlassIntensity.strong => LGColors.glassStrong(context),
    };
    return LGColors.alpha(base, opacity.clamp(0, 1).toDouble());
  }
}

class LGGlassContainer extends StatelessWidget {
  const LGGlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = const EdgeInsets.all(LGSpacing.lg),
    this.margin,
    this.blur = LGBlur.subtle,
    this.intensity = LGGlassIntensity.light,
    this.onTap,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final LGGlassIntensity intensity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LGGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      blur: blur,
      intensity: intensity,
      onTap: onTap,
      shadows: LGShadows.none,
      child: child,
    );
  }
}
