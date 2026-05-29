import 'package:flutter/material.dart';

import 'tokens.dart';

class FSEmptyState extends StatelessWidget {
  const FSEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.xl,
        vertical: FSSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: FSColors.intentContainer(context, FSIntent.primary),
                borderRadius: BorderRadius.circular(FSRadius.lg),
                border: Border.all(
                  color: FSColors.intentBorder(context, FSIntent.primary),
                ),
              ),
              child: Icon(icon, color: FSColors.primary),
            ),
            const SizedBox(height: FSSpacing.lg),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: FSSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: FSColors.mutedText(context),
                height: 1.35,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: FSSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
