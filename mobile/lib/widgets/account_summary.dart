import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../i18n.dart';

class AccountSummary extends StatelessWidget {
  const AccountSummary({super.key, required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(context, 'kpi.totalBalance'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(money(total),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
