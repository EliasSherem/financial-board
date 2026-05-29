import 'package:flutter/material.dart';
import '../models.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../i18n.dart';

class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key, required this.payments});

  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    List<PaymentItem> upcoming =
        payments.where((p) => p.isActive && p.nextDate.isNotEmpty).where((p) {
            final d = parseYmdLocal(p.nextDate);
            if (d == null) return false;
            return !d.isBefore(DateTime(now.year, now.month, now.day));
          }).toList()
          ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    upcoming = upcoming.take(3).toList();

    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UpcomingHeader(title: I18n.t(context, 'payments.scheduled')),
          const SizedBox(height: FSSpacing.md),
          if (upcoming.isEmpty)
            FSEmptyState(
              icon: Icons.event_available_outlined,
              title: I18n.t(context, 'analytics.noIncomeData'),
            )
          else
            ...upcoming.map((p) => _UpcomingPaymentRow(payment: p)),
        ],
      ),
    );
  }
}

class _UpcomingHeader extends StatelessWidget {
  const _UpcomingHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FSColors.intentContainer(context, FSIntent.info),
            borderRadius: BorderRadius.circular(FSRadius.md),
            border: Border.all(
              color: FSColors.intentBorder(context, FSIntent.info),
            ),
          ),
          child: const Icon(
            Icons.event_note_outlined,
            size: 20,
            color: FSColors.info,
          ),
        ),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _UpcomingPaymentRow extends StatelessWidget {
  const _UpcomingPaymentRow({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final dueLabel =
        '${I18n.t(context, 'payments.due')} ${formatYmd(payment.nextDate)}';
    final metadata =
        payment.accountName == null
            ? dueLabel
            : '$dueLabel • ${payment.accountName!}';
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
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, FSIntent.info),
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(
                color: FSColors.intentBorder(context, FSIntent.info),
              ),
            ),
            child: const Icon(
              Icons.event_outlined,
              size: 20,
              color: FSColors.info,
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  metadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FSColors.mutedText(context),
                  ),
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
                money(payment.amount),
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
