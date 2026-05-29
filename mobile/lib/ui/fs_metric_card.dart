import 'package:flutter/material.dart';

import 'fs_card.dart';
import 'fs_status_badge.dart';
import 'tokens.dart';

class FSMetricCard extends StatelessWidget {
  const FSMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accent = FSIntent.primary,
    this.accentColor,
    this.trend,
    this.trendVariant = FSStatusBadgeVariant.neutral,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final FSIntent accent;
  final Color? accentColor;
  final String? trend;
  final FSStatusBadgeVariant trendVariant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? FSColors.intent(accent);
    return FSCard(
      variant:
          onTap == null ? FSCardVariant.elevated : FSCardVariant.interactive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: FSColors.mutedText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: FSSpacing.md),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: FSColors.alpha(
                      color,
                      FSColors.isDark(context) ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                    border: Border.all(color: FSColors.alpha(color, 0.14)),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
              ],
            ],
          ),
          const SizedBox(height: FSSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          if (subtitle != null || trend != null) ...[
            const SizedBox(height: FSSpacing.sm),
            Wrap(
              spacing: FSSpacing.sm,
              runSpacing: FSSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (trend != null)
                  FSStatusBadge(label: trend!, variant: trendVariant),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FSColors.mutedText(context),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
