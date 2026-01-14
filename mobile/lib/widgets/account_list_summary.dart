import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../models.dart';

class AccountListSummary extends StatelessWidget {
  const AccountListSummary({super.key, required this.accounts, this.onAdd});
  final List<Account> accounts;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Text(I18n.t(context, 'analytics.accountSummary'), style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    tooltip: I18n.t(context, 'label.addAccount'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...accounts.map((a) => ListTile(
                  title: Text(a.name),
                  subtitle: Text(a.isInvestment ? I18n.t(context, 'accounts.type.investment') : (a.type ?? '')),
                  trailing: Text(
                    money(a.displayBalance),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                )),
          ],
        ),
      ),
    );
  }
}
