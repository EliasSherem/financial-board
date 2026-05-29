import 'package:flutter/material.dart';

import 'tokens.dart';

enum FSCardVariant { standard, elevated, interactive, subtle }

class FSCard extends StatelessWidget {
  const FSCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FSSpacing.lg),
    this.margin,
    this.onTap,
    this.variant = FSCardVariant.standard,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final FSCardVariant variant;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final color = _background(context);
    final radius = BorderRadius.circular(FSRadius.lg);
    final borderColor = _borderColor(context);
    final shadows = _shadows(context);

    final content = Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }

  Color _background(BuildContext context) {
    switch (variant) {
      case FSCardVariant.subtle:
        return FSColors.isDark(context)
            ? FSColors.alpha(FSColors.surfaceDark, 0.72)
            : const Color(0xFFF8FAFC);
      case FSCardVariant.elevated:
      case FSCardVariant.interactive:
      case FSCardVariant.standard:
        return FSColors.surfaceElevated(context);
    }
  }

  Color _borderColor(BuildContext context) {
    switch (variant) {
      case FSCardVariant.interactive:
        return FSColors.alpha(
          FSColors.primary,
          FSColors.isDark(context) ? 0.30 : 0.14,
        );
      case FSCardVariant.subtle:
        return FSColors.alpha(FSColors.border(context), 0.70);
      case FSCardVariant.elevated:
      case FSCardVariant.standard:
        return FSColors.border(context);
    }
  }

  List<BoxShadow> _shadows(BuildContext context) {
    switch (variant) {
      case FSCardVariant.elevated:
        return FSShadows.elevated(context);
      case FSCardVariant.interactive:
        return FSShadows.interactive(context);
      case FSCardVariant.subtle:
        return FSShadows.none;
      case FSCardVariant.standard:
        return FSShadows.soft(context);
    }
  }
}
