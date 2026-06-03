import 'package:flutter/material.dart';

import 'lg_tokens.dart';

enum LGStatusBadgeVariant {
  active,
  paid,
  partial,
  overdue,
  paused,
  completed,
  success,
  warning,
  danger,
  neutral,
  info,
}

class LGStatusBadge extends StatelessWidget {
  const LGStatusBadge({
    super.key,
    required this.label,
    this.variant = LGStatusBadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final LGStatusBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = _foreground;
    final background = LGColors.alpha(
      foreground,
      LGColors.isDark(context) ? 0.20 : 0.12,
    );
    final border = LGColors.alpha(
      foreground,
      LGColors.isDark(context) ? 0.34 : 0.20,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(LGRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: LGSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _foreground {
    switch (variant) {
      case LGStatusBadgeVariant.active:
      case LGStatusBadgeVariant.paid:
      case LGStatusBadgeVariant.completed:
      case LGStatusBadgeVariant.success:
        return LGColors.success;
      case LGStatusBadgeVariant.partial:
      case LGStatusBadgeVariant.paused:
      case LGStatusBadgeVariant.warning:
        return LGColors.warning;
      case LGStatusBadgeVariant.overdue:
      case LGStatusBadgeVariant.danger:
        return LGColors.danger;
      case LGStatusBadgeVariant.info:
        return LGColors.info;
      case LGStatusBadgeVariant.neutral:
        return LGColors.neutral;
    }
  }
}
