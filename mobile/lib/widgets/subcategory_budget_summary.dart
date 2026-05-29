import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n.dart';
import '../models.dart';
import '../ui/finsight_ui.dart';
import '../utils/category_icons.dart';
import '../utils/format.dart';
import 'pro_widgets.dart';

class SubcategoryBudgetSummary extends StatelessWidget {
  const SubcategoryBudgetSummary({
    super.key,
    required this.categories,
    required this.transactions,
    required this.isPro,
  });

  final List<ExpenseCategory> categories;
  final List<TransactionItem> transactions;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(categories, transactions);
    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BudgetHeader(isPro: isPro),
          const SizedBox(height: FSSpacing.md),
          if (items.isEmpty)
            FSEmptyState(
              icon: Icons.pie_chart_outline,
              title: I18n.t(context, 'categories.noSubcategories'),
            )
          else
            ...items.map((item) => _BudgetRow(item: item)),
        ],
      ),
    );
  }
}

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FSColors.intentContainer(context, FSIntent.warning),
            borderRadius: BorderRadius.circular(FSRadius.md),
            border: Border.all(
              color: FSColors.intentBorder(context, FSIntent.warning),
            ),
          ),
          child: const Icon(
            Icons.pie_chart_outline,
            size: 20,
            color: FSColors.warning,
          ),
        ),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            I18n.t(context, 'dashboard.subcategoryBudgets'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (!isPro) ...[
          const SizedBox(width: FSSpacing.sm),
          const ProMiniChip(),
        ],
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.item});
  final _SubcategoryBudgetItem item;

  @override
  Widget build(BuildContext context) {
    final budget = item.budget;
    final spent = item.spent;
    final percent = budget > 0 ? (spent / budget) : 0.0;
    final percentLabel = '${(percent * 100).toStringAsFixed(0)}%';
    final progress = budget > 0 ? percent.clamp(0.0, 1.0).toDouble() : 0.0;
    final isOver = budget > 0 && spent > budget;
    final progressColor =
        isOver
            ? FSColors.danger
            : (percent >= 0.8 ? FSColors.warning : FSColors.success);

    return Container(
      margin: const EdgeInsets.only(top: FSSpacing.sm),
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FSColors.alpha(progressColor, 0.10),
                  borderRadius: BorderRadius.circular(FSRadius.md),
                  border: Border.all(
                    color: FSColors.alpha(progressColor, 0.16),
                  ),
                ),
                child: Icon(
                  iconDataFromKey(item.iconKey),
                  size: 18,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: FSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FSColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FSSpacing.sm),
              FSStatusBadge(
                label: percentLabel,
                variant:
                    isOver
                        ? FSStatusBadgeVariant.danger
                        : (percent >= 0.8
                            ? FSStatusBadgeVariant.warning
                            : FSStatusBadgeVariant.success),
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(FSRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: progressColor,
              backgroundColor: FSColors.alpha(progressColor, 0.12),
            ),
          ),
          const SizedBox(height: FSSpacing.sm),
          Text(
            '${I18n.t(context, 'home.spent')} ${money(spent)} / ${money(budget)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FSColors.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryBudgetItem {
  const _SubcategoryBudgetItem({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.iconKey,
    required this.budget,
    required this.spent,
  });

  final int id;
  final String name;
  final String categoryName;
  final String iconKey;
  final double budget;
  final double spent;
}

List<_SubcategoryBudgetItem> _buildItems(
  List<ExpenseCategory> categories,
  List<TransactionItem> transactions,
) {
  if (categories.isEmpty) return [];
  final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
  final Map<int, double> spentBySub = {};
  for (final t in transactions) {
    if (!t.isExpense) continue;
    final subId = t.subcategoryId;
    if (subId == null) continue;
    final key = t.date.toIso8601String().substring(0, 7);
    if (key != monthKey) continue;
    spentBySub.update(
      subId,
      (v) => v + t.amount.abs(),
      ifAbsent: () => t.amount.abs(),
    );
  }

  final items = <_SubcategoryBudgetItem>[];
  for (final cat in categories) {
    for (final sub in cat.subcategories) {
      items.add(
        _SubcategoryBudgetItem(
          id: sub.id,
          name: sub.name,
          categoryName: cat.name,
          iconKey: sub.icon,
          budget: sub.budget,
          spent: spentBySub[sub.id] ?? 0,
        ),
      );
    }
  }

  if (items.isEmpty) return [];
  final hasExpenses = items.any((item) => item.spent > 0);
  if (!hasExpenses) {
    return items.take(3).toList();
  }
  items.sort((a, b) => b.spent.compareTo(a.spent));
  return items.take(3).toList();
}
