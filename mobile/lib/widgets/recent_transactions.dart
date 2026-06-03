import 'package:flutter/material.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';
import '../utils/format.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key, required this.items, this.onViewAll});

  final List<TransactionItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();
    final theme = Theme.of(context);
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  I18n.t(context, 'home.recentTransactions'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(I18n.t(context, 'home.viewAll')),
                ),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          for (final tx in visible)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _amountColor(tx).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(LGRadius.md),
                    ),
                    child: Icon(
                      tx.isTransfer
                          ? Icons.swap_horiz_rounded
                          : (tx.amount >= 0
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded),
                      color: _amountColor(tx),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            formatDate(tx.date),
                            if ((tx.accountName ?? '').isNotEmpty)
                              tx.accountName!,
                            if ((tx.effectiveCategory ?? '').isNotEmpty)
                              tx.effectiveCategory!,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LGColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Text(
                    signedMoney(tx.amount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _amountColor(tx),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _amountColor(TransactionItem tx) {
    if (tx.isTransfer) return LGColors.info;
    return tx.amount >= 0 ? LGColors.success : LGColors.danger;
  }
}
