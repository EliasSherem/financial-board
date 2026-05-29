import 'package:flutter/material.dart';
import '../models.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../i18n.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key, required this.items, this.onViewAll});
  final List<TransactionItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();
    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecentHeader(onViewAll: onViewAll),
          const SizedBox(height: FSSpacing.md),
          if (visible.isEmpty)
            FSEmptyState(
              icon: Icons.receipt_long_outlined,
              title: I18n.t(context, 'tx.none'),
            )
          else
            for (final tx in visible) _TransactionRow(tx: tx),
        ],
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TransactionIcon(
          icon: Icons.receipt_long_outlined,
          color: Theme.of(context).colorScheme.primary,
          background: FSColors.intentContainer(context, FSIntent.primary),
        ),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            I18n.t(context, 'home.recentTransactions'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(I18n.t(context, 'home.viewAll')),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final TransactionItem tx;

  @override
  Widget build(BuildContext context) {
    final amountColor =
        tx.isTransfer
            ? FSColors.info
            : (tx.amount >= 0 ? FSColors.success : FSColors.danger);
    final label =
        tx.isTransfer
            ? I18n.t(context, 'tx.transfer')
            : (tx.amount >= 0
                ? I18n.t(context, 'tx.income')
                : I18n.t(context, 'tx.expense'));
    final badgeVariant =
        tx.isTransfer
            ? FSStatusBadgeVariant.info
            : (tx.amount >= 0
                ? FSStatusBadgeVariant.success
                : FSStatusBadgeVariant.danger);
    final meta = [
      formatDate(tx.date),
      if ((tx.accountName ?? '').isNotEmpty) tx.accountName!,
      if ((tx.effectiveCategory ?? '').isNotEmpty) tx.effectiveCategory!,
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(top: FSSpacing.sm),
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          _TransactionIcon(
            icon:
                tx.isTransfer
                    ? Icons.sync_alt_rounded
                    : (tx.amount >= 0
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
            color: amountColor,
            background: FSColors.alpha(amountColor, 0.10),
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: FSSpacing.xs),
                Wrap(
                  spacing: FSSpacing.sm,
                  runSpacing: FSSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FSStatusBadge(label: label, variant: badgeVariant),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FSColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                signedMoney(tx.amount),
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionIcon extends StatelessWidget {
  const _TransactionIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(color: FSColors.alpha(color, 0.16)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
