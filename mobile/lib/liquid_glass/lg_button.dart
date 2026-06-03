import 'package:flutter/material.dart';

import 'lg_glass.dart';
import 'lg_tokens.dart';

enum LGButtonVariant {
  primary,
  glass,
  secondary,
  outline,
  ghost,
  danger,
  success,
  warning,
}

enum LGButtonSize { sm, md, lg }

class LGButton extends StatelessWidget {
  const LGButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LGButtonVariant.primary,
    this.size = LGButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final LGButtonVariant variant;
  final LGButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = _content(context);
    if (variant == LGButtonVariant.glass) {
      final button = Opacity(
        opacity: enabled ? 1 : 0.55,
        child: LGGlassSurface(
          blur: LGBlur.subtle,
          intensity: LGGlassIntensity.light,
          borderRadius: BorderRadius.circular(LGRadius.pill),
          padding: EdgeInsets.zero,
          shadows: LGShadows.none,
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _height),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Center(child: child),
            ),
          ),
        ),
      );
      return fullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button;
    }

    final style = _style(context);
    final button = _buildMaterialButton(
      enabled ? onPressed : null,
      child,
      style,
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildMaterialButton(
    VoidCallback? handler,
    Widget child,
    ButtonStyle style,
  ) {
    switch (variant) {
      case LGButtonVariant.outline:
        return OutlinedButton(onPressed: handler, style: style, child: child);
      case LGButtonVariant.ghost:
        return TextButton(onPressed: handler, style: style, child: child);
      case LGButtonVariant.primary:
      case LGButtonVariant.secondary:
      case LGButtonVariant.danger:
      case LGButtonVariant.success:
      case LGButtonVariant.warning:
      case LGButtonVariant.glass:
        return FilledButton(onPressed: handler, style: style, child: child);
    }
  }

  Widget _content(BuildContext context) {
    final spinnerColor = _foreground(context);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (loading || icon != null) const SizedBox(width: LGSpacing.sm),
        if (fullWidth) Expanded(child: text) else text,
      ],
    );
  }

  ButtonStyle _style(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LGRadius.pill),
    );
    switch (variant) {
      case LGButtonVariant.outline:
        return OutlinedButton.styleFrom(
          minimumSize: Size(0, _height),
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          foregroundColor: LGColors.primaryBlue,
          side: BorderSide(color: LGColors.alpha(LGColors.primaryBlue, 0.38)),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        );
      case LGButtonVariant.ghost:
        return TextButton.styleFrom(
          minimumSize: Size(0, _height),
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          foregroundColor: LGColors.textPrimary(context),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        );
      case LGButtonVariant.primary:
      case LGButtonVariant.secondary:
      case LGButtonVariant.danger:
      case LGButtonVariant.success:
      case LGButtonVariant.warning:
      case LGButtonVariant.glass:
        final background = _background(context);
        final foreground = _foreground(context);
        return FilledButton.styleFrom(
          minimumSize: Size(0, _height),
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: LGColors.alpha(background, 0.42),
          disabledForegroundColor: LGColors.alpha(foreground, 0.70),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        );
    }
  }

  double get _height {
    return switch (size) {
      LGButtonSize.sm => 38,
      LGButtonSize.md => 46,
      LGButtonSize.lg => 52,
    };
  }

  double get _horizontalPadding {
    return switch (size) {
      LGButtonSize.sm => LGSpacing.md,
      LGButtonSize.md => LGSpacing.lg,
      LGButtonSize.lg => LGSpacing.xl,
    };
  }

  Color _background(BuildContext context) {
    switch (variant) {
      case LGButtonVariant.primary:
        return LGColors.primaryBlue;
      case LGButtonVariant.secondary:
        return LGColors.isDark(context) ? Colors.white : LGColors.deepNavy;
      case LGButtonVariant.danger:
        return LGColors.danger;
      case LGButtonVariant.success:
        return LGColors.success;
      case LGButtonVariant.warning:
        return LGColors.warning;
      case LGButtonVariant.outline:
      case LGButtonVariant.ghost:
      case LGButtonVariant.glass:
        return Colors.transparent;
    }
  }

  Color _foreground(BuildContext context) {
    switch (variant) {
      case LGButtonVariant.secondary:
      case LGButtonVariant.warning:
        return LGColors.isDark(context) ? LGColors.deepNavy : Colors.white;
      case LGButtonVariant.outline:
        return LGColors.primaryBlue;
      case LGButtonVariant.ghost:
      case LGButtonVariant.glass:
        return LGColors.textPrimary(context);
      case LGButtonVariant.primary:
      case LGButtonVariant.danger:
      case LGButtonVariant.success:
        return Colors.white;
    }
  }
}
