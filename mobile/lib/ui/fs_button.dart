import 'package:flutter/material.dart';

import 'tokens.dart';

enum FSButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
  success,
  warning,
}

enum FSButtonSize { sm, md, lg }

class FSButton extends StatelessWidget {
  const FSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FSButtonVariant.primary,
    this.size = FSButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final FSButtonVariant variant;
  final FSButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = _content(context);
    final style = _style(context);
    final button = _buildButton(enabled ? onPressed : null, child, style);
    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildButton(VoidCallback? handler, Widget child, ButtonStyle style) {
    switch (variant) {
      case FSButtonVariant.outline:
        return OutlinedButton(onPressed: handler, style: style, child: child);
      case FSButtonVariant.ghost:
        return TextButton(onPressed: handler, style: style, child: child);
      case FSButtonVariant.primary:
      case FSButtonVariant.secondary:
      case FSButtonVariant.danger:
      case FSButtonVariant.success:
      case FSButtonVariant.warning:
        return FilledButton(onPressed: handler, style: style, child: child);
    }
  }

  Widget _content(BuildContext context) {
    final spinnerColor = _foreground(context);
    final labelText = Text(
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
        if (loading || icon != null) const SizedBox(width: FSSpacing.sm),
        if (fullWidth) Expanded(child: labelText) else labelText,
      ],
    );
  }

  ButtonStyle _style(BuildContext context) {
    final minHeight = switch (size) {
      FSButtonSize.sm => 38.0,
      FSButtonSize.md => 44.0,
      FSButtonSize.lg => 50.0,
    };
    final horizontal = switch (size) {
      FSButtonSize.sm => FSSpacing.md,
      FSButtonSize.md => FSSpacing.lg,
      FSButtonSize.lg => FSSpacing.xl,
    };
    final background = _background(context);
    final foreground = _foreground(context);
    final border = _border(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FSRadius.md),
    );

    switch (variant) {
      case FSButtonVariant.outline:
        return OutlinedButton.styleFrom(
          minimumSize: Size(0, minHeight),
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        );
      case FSButtonVariant.ghost:
        return TextButton.styleFrom(
          minimumSize: Size(0, minHeight),
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          foregroundColor: foreground,
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        );
      case FSButtonVariant.primary:
      case FSButtonVariant.secondary:
      case FSButtonVariant.danger:
      case FSButtonVariant.success:
      case FSButtonVariant.warning:
        return FilledButton.styleFrom(
          minimumSize: Size(0, minHeight),
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: FSColors.alpha(background, 0.45),
          disabledForegroundColor: FSColors.alpha(foreground, 0.70),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        );
    }
  }

  Color _background(BuildContext context) {
    switch (variant) {
      case FSButtonVariant.primary:
        return FSColors.primary;
      case FSButtonVariant.secondary:
        return FSColors.isDark(context) ? Colors.white : FSColors.primaryDark;
      case FSButtonVariant.danger:
        return FSColors.danger;
      case FSButtonVariant.success:
        return FSColors.success;
      case FSButtonVariant.warning:
        return FSColors.warning;
      case FSButtonVariant.outline:
      case FSButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _foreground(BuildContext context) {
    switch (variant) {
      case FSButtonVariant.secondary:
        return FSColors.isDark(context) ? FSColors.primaryDark : Colors.white;
      case FSButtonVariant.warning:
        return FSColors.isDark(context) ? FSColors.primaryDark : Colors.white;
      case FSButtonVariant.outline:
      case FSButtonVariant.ghost:
        return variant == FSButtonVariant.ghost
            ? Theme.of(context).colorScheme.onSurface
            : FSColors.primary;
      case FSButtonVariant.primary:
      case FSButtonVariant.danger:
      case FSButtonVariant.success:
        return Colors.white;
    }
  }

  Color _border(BuildContext context) {
    return FSColors.isDark(context)
        ? FSColors.borderDark
        : FSColors.borderLight;
  }
}
