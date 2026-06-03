import 'package:flutter/material.dart';

import '../liquid_glass/liquid_glass.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.subtitle,
    this.deltaPercent,
    this.deltaIsPositive,
    this.footer,
    this.titleMaxLines,
  });

  final String title;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final double? deltaPercent;
  final bool? deltaIsPositive;
  final Widget? footer;
  final int? titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.md),
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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: titleMaxLines ?? 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: LGSpacing.sm),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(LGRadius.md),
                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Icon(icon, size: 18, color: accent),
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
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: LGSpacing.xs),
              child: footer!,
            )
          else if (deltaPercent != null)
            Padding(
              padding: const EdgeInsets.only(top: LGSpacing.xs),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LGSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (deltaIsPositive ?? true)
                              ? LGColors.success.withValues(alpha: 0.12)
                              : LGColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(LGRadius.pill),
                    ),
                    child: Text(
                      '${(deltaIsPositive ?? true) ? '+' : '-'}${deltaPercent!.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            (deltaIsPositive ?? true)
                                ? LGColors.success
                                : LGColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: LGSpacing.sm),
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: LGColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: LGSpacing.xs),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: LGColors.textSecondary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
