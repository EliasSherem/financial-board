import 'package:flutter/material.dart';

import '../ui/finsight_ui.dart';

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
    this.accent = FSIntent.primary,
  });

  final String title;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final double? deltaPercent; // show if not null
  final bool? deltaIsPositive;
  final Widget? footer;
  final int? titleMaxLines;
  final FSIntent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.md,
        vertical: FSSpacing.md,
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: FSColors.mutedText(context),
                    ),
                    maxLines: titleMaxLines ?? 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: FSColors.intentContainer(context, accent),
                      borderRadius: BorderRadius.circular(FSRadius.md),
                      border: Border.all(
                        color: FSColors.intentBorder(context, accent),
                      ),
                    ),
                    child: Icon(icon, size: 18, color: FSColors.intent(accent)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Value scales down if the tile is short
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: footer!)
            else if (deltaPercent != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (deltaIsPositive ?? true)
                                ? FSColors.alpha(FSColors.success, 0.14)
                                : FSColors.alpha(FSColors.danger, 0.14),
                        borderRadius: BorderRadius.circular(FSRadius.pill),
                      ),
                      child: Text(
                        '${(deltaIsPositive ?? true) ? '+' : '-'}${deltaPercent!.abs().toStringAsFixed(1)}% ',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              (deltaIsPositive ?? true)
                                  ? FSColors.success
                                  : FSColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
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
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
    return card;
  }
}
