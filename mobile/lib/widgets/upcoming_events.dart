import 'package:flutter/material.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';
import '../utils/format.dart';

class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key, required this.payments});

  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    var upcoming =
        payments.where((p) => p.isActive && p.nextDate.isNotEmpty).where((p) {
            final d = parseYmdLocal(p.nextDate);
            if (d == null) return false;
            return !d.isBefore(DateTime(now.year, now.month, now.day));
          }).toList()
          ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    upcoming = upcoming.take(3).toList();

    final theme = Theme.of(context);
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.t(context, 'payments.scheduled'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: LGSpacing.sm),
          if (upcoming.isEmpty)
            Text(
              I18n.t(context, 'analytics.noIncomeData'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
              ),
            )
          else
            ...upcoming.map(
              (payment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: LGColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(LGRadius.md),
                      ),
                      child: const Icon(
                        Icons.event_outlined,
                        color: LGColors.warning,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: LGSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${I18n.t(context, 'payments.due')} ${formatYmd(payment.nextDate)}'
                            '${payment.accountName != null ? ' • ${payment.accountName!}' : ''}',
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
                      money(payment.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
