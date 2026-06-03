import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';
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
                  I18n.t(context, 'dashboard.subcategoryBudgets'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isPro) const ProMiniChip(),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          if (items.isEmpty)
            Text(
              I18n.t(context, 'categories.noSubcategories'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
              ),
            )
          else
            ...items.map((item) => _BudgetRow(item: item)),
        ],
      ),
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
    final progressColor = isOver ? LGColors.danger : LGColors.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
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
                  color: progressColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(LGRadius.md),
                ),
                child: Icon(
                  iconDataFromKey(item.iconKey),
                  size: 18,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                percentLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.xs),
          Text(
            item.categoryName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: LGColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: LGSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(LGRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: progressColor,
              backgroundColor:
                  LGColors.isDark(context)
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: LGSpacing.xs),
          Text(
            '${I18n.t(context, 'home.spent')} ${money(spent)} / ${money(budget)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: LGColors.textSecondary(context),
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
