import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/format.dart';
import '../i18n.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key, required this.items, this.onViewAll});
  final List<TransactionItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color:
          isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  I18n.t(context, 'home.recentTransactions'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: Text(I18n.t(context, 'home.viewAll')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final tx in visible)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    formatDate(tx.date),
                    if ((tx.accountName ?? '').isNotEmpty) tx.accountName!,
                    if ((tx.effectiveCategory ?? '').isNotEmpty)
                      tx.effectiveCategory!,
                  ].join(' • '),
                ),
                trailing: Text(
                  signedMoney(tx.amount),
                  style: TextStyle(
                    color:
                        tx.isTransfer
                            ? Colors.blue
                            : (tx.amount >= 0 ? Colors.green : Colors.red),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
