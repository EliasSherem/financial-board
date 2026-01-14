import 'package:flutter/material.dart';

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
  final double? deltaPercent; // show if not null
  final bool? deltaIsPositive;
  final Widget? footer;
  final int? titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final cardBg = isDark ? surface : Colors.blue.shade50;
    final card = Card(
      color: cardBg,
      elevation: 6,
      shape: border,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                    maxLines: titleMaxLines ?? 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null) Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: footer!,
              )
            else if (deltaPercent != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (deltaIsPositive ?? true) ? Colors.green.withOpacity(0.14) : Colors.red.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(deltaIsPositive ?? true) ? '+' : '-'}${deltaPercent!.abs().toStringAsFixed(1)}% ',
                        style: TextStyle(
                          fontSize: 11,
                          color: (deltaIsPositive ?? true) ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
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
                  style: Theme.of(context).textTheme.bodySmall,
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
