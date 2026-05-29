import 'package:flutter/material.dart';

import 'tokens.dart';

class FSPageHeader extends StatelessWidget {
  const FSPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 2), child: leading!),
            const SizedBox(width: FSSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: FSSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FSColors.mutedText(context),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FSSpacing.md),
            trailing!,
          ],
          if (action != null) ...[const SizedBox(width: FSSpacing.md), action!],
        ],
      ),
    );
  }
}
