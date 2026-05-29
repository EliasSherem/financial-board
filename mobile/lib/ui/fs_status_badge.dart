import 'package:flutter/material.dart';

import 'tokens.dart';

enum FSStatusBadgeVariant {
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

class FSStatusBadge extends StatelessWidget {
  const FSStatusBadge({
    super.key,
    required this.label,
    this.variant = FSStatusBadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final FSStatusBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = _foreground();
    final bg = FSColors.alpha(fg, FSColors.isDark(context) ? 0.16 : 0.10);
    final border = FSColors.alpha(fg, FSColors.isDark(context) ? 0.28 : 0.16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FSRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _foreground() {
    switch (variant) {
      case FSStatusBadgeVariant.active:
      case FSStatusBadgeVariant.paid:
      case FSStatusBadgeVariant.completed:
      case FSStatusBadgeVariant.success:
        return FSColors.success;
      case FSStatusBadgeVariant.partial:
      case FSStatusBadgeVariant.paused:
      case FSStatusBadgeVariant.warning:
        return FSColors.warning;
      case FSStatusBadgeVariant.overdue:
      case FSStatusBadgeVariant.danger:
        return FSColors.danger;
      case FSStatusBadgeVariant.info:
        return FSColors.info;
      case FSStatusBadgeVariant.neutral:
        return FSColors.neutral;
    }
  }
}
