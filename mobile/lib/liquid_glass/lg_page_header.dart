import 'package:flutter/material.dart';

import 'lg_tokens.dart';

class LGPageHeader extends StatelessWidget {
  const LGPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = (compact
            ? theme.textTheme.titleLarge
            : theme.textTheme.headlineSmall)
        ?.copyWith(
          color: LGColors.textPrimary(context),
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : LGSpacing.lg,
        vertical: compact ? LGSpacing.sm : LGSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: LGSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: LGSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: LGColors.textSecondary(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null || trailing != null) ...[
            const SizedBox(width: LGSpacing.md),
            action ?? trailing!,
          ],
        ],
      ),
    );
  }
}
