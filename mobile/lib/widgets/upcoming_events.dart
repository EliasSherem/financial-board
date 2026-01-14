import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/format.dart';
import '../i18n.dart';

class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key, required this.payments});

  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    List<PaymentItem> upcoming = payments
        .where((p) => p.isActive && p.nextDate.isNotEmpty)
        .where((p) {
          final d = parseYmdLocal(p.nextDate);
          if (d == null) return false;
          return !d.isBefore(DateTime(now.year, now.month, now.day));
        })
        .toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    upcoming = upcoming.take(3).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(context, 'payments.scheduled'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              Text(I18n.t(context, 'analytics.noIncomeData'))
            else
              ...upcoming.map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(p.name),
                subtitle: Text(I18n.t(context, 'payments.due') + ' ' + formatYmd(p.nextDate) + (p.accountName != null ? ' • ' + p.accountName! : '')),
                trailing: Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
          ],
        ),
      ),
    );
  }
}
