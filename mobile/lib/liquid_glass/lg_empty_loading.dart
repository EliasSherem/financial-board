import 'package:flutter/material.dart';

import 'lg_button.dart';
import 'lg_card.dart';
import 'lg_tokens.dart';

class LGEmptyState extends StatelessWidget {
  const LGEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LGSolidCard(
      tinted: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LGColors.intentContainer(context, LGIntent.primary),
              borderRadius: BorderRadius.circular(LGRadius.xl),
              border: Border.all(
                color: LGColors.intentStroke(context, LGIntent.primary),
              ),
            ),
            child: Icon(icon, color: LGColors.primaryBlue, size: 26),
          ),
          const SizedBox(height: LGSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: LGColors.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: LGSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: LGColors.textSecondary(context),
              height: 1.35,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: LGSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class LGLoadingState extends StatelessWidget {
  const LGLoadingState({super.key, this.label, this.compact = false});

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: compact ? 18 : 24,
      height: compact ? 18 : 24,
      child: const CircularProgressIndicator(strokeWidth: 2.4),
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          if (label != null) ...[
            const SizedBox(width: LGSpacing.sm),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
    }

    return LGSolidCard(
      tinted: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          if (label != null) ...[
            const SizedBox(height: LGSpacing.md),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LGEmptyAction extends StatelessWidget {
  const LGEmptyAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return LGButton(label: label, icon: icon, onPressed: onPressed);
  }
}
