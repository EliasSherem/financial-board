import 'package:flutter/material.dart';

import 'lg_card.dart';
import 'lg_tokens.dart';

enum LGMetricCardStyle { solid, glass }

class LGMetricCard extends StatelessWidget {
  const LGMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.trend,
    this.onTap,
    this.style = LGMetricCardStyle.solid,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final Widget? trend;
  final VoidCallback? onTap;
  final LGMetricCardStyle style;

  @override
  Widget build(BuildContext context) {
    final content = _MetricContent(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor ?? LGColors.primaryBlue,
      trend: trend,
    );

    if (style == LGMetricCardStyle.glass) {
      return LGGlassCard(
        variant: LGCardVariant.hero,
        onTap: onTap,
        child: content,
      );
    }

    return LGSolidCard(
      variant: LGCardVariant.elevated,
      tinted: false,
      onTap: onTap,
      child: content,
    );
  }
}

class _MetricContent extends StatelessWidget {
  const _MetricContent({
    required this.title,
    required this.value,
    required this.accentColor,
    this.subtitle,
    this.icon,
    this.trend,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;
  final Widget? trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
                  color: LGColors.textSecondary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: LGSpacing.md),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LGColors.alpha(accentColor, 0.14),
                  borderRadius: BorderRadius.circular(LGRadius.md),
                  border: Border.all(color: LGColors.alpha(accentColor, 0.22)),
                ),
                child: Icon(icon, color: accentColor, size: 21),
              ),
            ],
          ],
        ),
        const SizedBox(height: LGSpacing.md),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: LGColors.textPrimary(context),
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        if (subtitle != null || trend != null) ...[
          const SizedBox(height: LGSpacing.sm),
          Row(
            children: [
              if (trend != null) ...[
                trend!,
                const SizedBox(width: LGSpacing.sm),
              ],
              if (subtitle != null)
                Expanded(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LGColors.textSecondary(context),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
