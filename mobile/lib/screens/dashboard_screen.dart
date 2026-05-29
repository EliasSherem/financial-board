import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/project_summaries.dart';
import '../widgets/recent_transactions.dart';
import '../widgets/upcoming_events.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../services/widget_service.dart';
import '../state/auth_store.dart';
import '../models.dart';
import '../widgets/kpi_card.dart';
import '../widgets/account_list_summary.dart';
import '../widgets/subcategory_budget_summary.dart';
import '../utils/format.dart';
import '../utils/savings_goal.dart';
import 'accounts_screen_new.dart';
import 'transactions_v2_screen.dart';
import '../widgets/pro_widgets.dart';
import '../state/refresh_bus.dart';
import '../i18n.dart';
import '../ui/finsight_ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<Object>>? _future;
  String? _token;
  static const int _insightVariantCount = 4;
  static int _insightSeed = 0;
  int _insightIndex = 0;
  double? _savingsGoal;
  int? _goalUserId;
  late final RefreshBus _refreshBus;
  int _accountsTick = 0;
  int _transactionsTick = 0;
  int _paymentsTick = 0;
  int _projectsTick = 0;
  int _investmentsTick = 0;

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _accountsTick = _refreshBus.accounts;
    _transactionsTick = _refreshBus.transactions;
    _paymentsTick = _refreshBus.payments;
    _projectsTick = _refreshBus.projects;
    _investmentsTick = _refreshBus.investments;
    _refreshBus.addListener(_handleRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthStore>().userId;
    if (_goalUserId != userId) {
      _goalUserId = userId;
      _loadSavingsGoal(_goalUserId);
    }
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _loadSavingsGoal(int? userId) async {
    final goal = await SavingsGoalStore.load(userId);
    if (!mounted) return;
    setState(() {
      _goalUserId = userId;
      _savingsGoal = goal;
    });
  }

  Future<List<Object>> _loadData(String? token) async {
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    // Load datasets in parallel; keep graceful fallbacks for trial accounts (403 on some endpoints).
    final accountsFuture = data.getAccounts();
    final txsFuture = data.getTransactions();
    final projectsFuture = data.getProjects().catchError((_) => <Project>[]);
    final paymentsFuture = data.getPayments().catchError(
      (_) => <PaymentItem>[],
    );
    final bhFuture = data.getBalanceHistory().catchError(
      (_) => <BalanceHistoryItem>[],
    );
    final investmentsFuture = data.getInvestments().catchError(
      (_) => <Map<String, dynamic>>[],
    );
    final categoriesFuture = data.getExpenseCategories().catchError(
      (_) => <ExpenseCategory>[],
    );

    return await Future.wait<Object>([
      accountsFuture,
      txsFuture,
      projectsFuture,
      paymentsFuture,
      bhFuture,
      investmentsFuture,
      categoriesFuture,
    ]);
  }

  Future<void> _refresh() async {
    final token = _token ?? context.read<AuthStore>().token;
    _token = token;
    final future = _loadData(token);
    setState(() {
      _future = future;
      _insightIndex = _nextInsightIndex();
    });
    final userId = _goalUserId ?? context.read<AuthStore>().userId;
    await Future.wait([future, _loadSavingsGoal(userId)]);
  }

  void _handleRefresh() {
    if (!mounted) return;
    var shouldRefresh = false;
    if (_refreshBus.accounts != _accountsTick) {
      _accountsTick = _refreshBus.accounts;
      shouldRefresh = true;
    }
    if (_refreshBus.transactions != _transactionsTick) {
      _transactionsTick = _refreshBus.transactions;
      shouldRefresh = true;
    }
    if (_refreshBus.payments != _paymentsTick) {
      _paymentsTick = _refreshBus.payments;
      shouldRefresh = true;
    }
    if (_refreshBus.projects != _projectsTick) {
      _projectsTick = _refreshBus.projects;
      shouldRefresh = true;
    }
    if (_refreshBus.investments != _investmentsTick) {
      _investmentsTick = _refreshBus.investments;
      shouldRefresh = true;
    }
    if (shouldRefresh) {
      _refresh();
    }
  }

  int _nextInsightIndex() {
    _insightSeed = (_insightSeed + 1) % _insightVariantCount;
    return _insightSeed;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final token = auth.token;
    if (_future == null || _token != token) {
      _token = token;
      _future = _loadData(token);
      _insightIndex = _nextInsightIndex();
    }
    return FutureBuilder<List<Object>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final auth = context.read<AuthStore>();
              if (auth.isAuthenticated) {
                auth.logout(force: true);
              }
            });
            return const FSLoadingState();
          }
          return const FSLoadingState();
        }
        final accounts = (snap.data![0] as List<Account>);
        final txs = (snap.data![1] as List<TransactionItem>);
        final projects = (snap.data![2] as List<Project>);
        final payments = (snap.data![3] as List<PaymentItem>);
        final bh = (snap.data![4] as List<BalanceHistoryItem>);
        final categories = (snap.data![6] as List<ExpenseCategory>);

        // Sum account balances (investment accounts already include estimated value)
        final totalBalance = accounts.fold<double>(
          0,
          (sum, a) => sum + a.displayBalance,
        );
        // KPIs
        double monthExpense(List<TransactionItem> list, DateTime d) {
          final key =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
          final filtered = list.where(
            (t) => t.date.toIso8601String().startsWith(key),
          );
          double sum = 0;
          for (final t in filtered) {
            if (t.isExpense) sum += t.amount.abs();
          }
          return sum;
        }

        double monthIncome(List<TransactionItem> list, DateTime d) {
          final key =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
          final filtered = list.where(
            (t) => t.date.toIso8601String().startsWith(key),
          );
          double sum = 0;
          for (final t in filtered) {
            if (t.isIncome) sum += t.amount;
          }
          return sum;
        }

        final now = DateTime.now();
        final currInc = monthIncome(txs, now);
        final currExp = monthExpense(txs, now);
        final currNet = currInc - currExp;
        final prev = DateTime(now.year, now.month - 1, 1);
        final prevExp = monthExpense(txs, prev);
        final double expDelta =
            prevExp == 0 ? 0.0 : ((currExp - prevExp) / prevExp) * 100.0;
        String monthLabel;
        try {
          final locale = Localizations.localeOf(context);
          monthLabel = DateFormat.yMMMM(locale.toLanguageTag()).format(now);
        } catch (_) {
          monthLabel =
              '${now.year.toString()}-${now.month.toString().padLeft(2, '0')}';
        }
        NativeWidgetBridge.updateMonthlySpend(
          displayValue: money(currExp),
          monthLabel: monthLabel,
          rawAmount: currExp,
        );
        final budgetBySub = <int, double>{};
        double totalBudget = 0;
        for (final cat in categories) {
          for (final sub in cat.subcategories) {
            if (sub.budget > 0) {
              budgetBySub[sub.id] = sub.budget;
              totalBudget += sub.budget;
            }
          }
        }
        double spentBudget = 0;
        if (totalBudget > 0) {
          final monthKey =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
          for (final t in txs) {
            if (!t.isExpense) continue;
            if (!t.date.toIso8601String().startsWith(monthKey)) continue;
            final subId = t.subcategoryId;
            if (subId == null) continue;
            if (!budgetBySub.containsKey(subId)) continue;
            spentBudget += t.amount.abs();
          }
        }
        final budgetPercent =
            totalBudget == 0 ? 0 : (spentBudget / totalBudget) * 100;
        final budgetPercentText = '${budgetPercent.toStringAsFixed(0)}%';
        final Color budgetColor;
        if (budgetPercent >= 100) {
          budgetColor = FSColors.danger;
        } else if (budgetPercent >= 80) {
          budgetColor = FSColors.warning;
        } else {
          budgetColor = FSColors.success;
        }
        final budgetFooter = Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FSColors.alpha(budgetColor, 0.14),
                borderRadius: BorderRadius.circular(FSRadius.pill),
              ),
              child: Text(
                budgetPercentText,
                style: TextStyle(
                  fontSize: 11,
                  color: budgetColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                I18n.t(context, 'kpi.used'),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        final netUp = currNet >= 0;
        final netAmount = money(currNet.abs());
        final budgetPercentLabel = budgetPercent.toStringAsFixed(0);
        final savingsGoal = _savingsGoal;
        final hasSavingsGoal = savingsGoal != null && savingsGoal > 0;
        final savedThisMonth = currNet > 0 ? currNet : 0;
        final savingsRatio =
            hasSavingsGoal ? (savedThisMonth / savingsGoal) : 0.0;
        final savingsProgress = savingsRatio.clamp(0.0, 1.0).toDouble();
        final savingsPercentLabel =
            '${(savingsRatio * 100).clamp(0.0, 999.0).toStringAsFixed(0)}%';

        const riskWindowDays = 7;
        final today = DateTime(now.year, now.month, now.day);
        int dueCount = 0;
        for (final p in payments) {
          if (!p.isActive || p.nextDate.isEmpty) continue;
          final due = DateTime.tryParse(p.nextDate);
          if (due == null) continue;
          final daysUntil = due.difference(today).inDays;
          if (daysUntil >= 0 && daysUntil <= riskWindowDays) {
            dueCount += 1;
          }
        }
        final overBudget = totalBudget > 0 && spentBudget > totalBudget;
        final nearBudget =
            totalBudget > 0 && !overBudget && budgetPercent >= 80;
        final hasRisk = overBudget || nearBudget || dueCount > 0;
        final hasBudget = totalBudget > 0;
        final List<String> ctas;
        if (!hasBudget) {
          ctas = [
            'Set a monthly budget to track spending.',
            'Add budgets to stay on top of expenses.',
            'Create a budget to keep categories in check.',
          ];
        } else if (hasRisk) {
          ctas = [
            'Review upcoming payments to stay ahead.',
            'Check expenses today to stay on track.',
            'Adjust budgets now to reduce risk.',
          ];
        } else if (!netUp) {
          ctas = [
            'Look for one quick win to improve net.',
            'Trim one expense today to lift your net.',
            'Review recent spending for quick wins.',
          ];
        } else {
          ctas = [
            'You are on track. Keep it up.',
            'Everything looks steady today.',
            'Nice work, stay consistent.',
          ];
        }
        final cta = ctas[_insightIndex % ctas.length];
        final insightType = _insightIndex % _insightVariantCount;
        late IconData insightIcon;
        late Color insightColor;
        late List<InlineSpan> insightSpans;

        if (insightType == 0) {
          insightIcon = netUp ? Icons.trending_up : Icons.trending_down;
          insightColor = netUp ? FSColors.success : FSColors.danger;
          insightSpans = [
            const TextSpan(text: 'Net '),
            TextSpan(
              text: netUp ? 'up ' : 'down ',
              style: TextStyle(
                color: insightColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: netAmount,
              style: TextStyle(
                color: insightColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: ' this month'),
          ];
        } else if (insightType == 1) {
          insightIcon = Icons.pie_chart_outline;
          insightColor = budgetColor;
          if (hasBudget) {
            insightSpans = [
              const TextSpan(text: 'Budget used '),
              TextSpan(
                text: '$budgetPercentLabel%',
                style: TextStyle(
                  color: insightColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' of ${money(totalBudget)}'),
            ];
          } else {
            insightSpans = const [
              TextSpan(text: 'Set a monthly budget to track usage'),
            ];
          }
        } else if (insightType == 2) {
          if (!hasRisk) {
            insightIcon = Icons.check_circle_outline;
            insightColor = FSColors.success;
            insightSpans = [
              const TextSpan(text: 'No upcoming risks in the next '),
              TextSpan(
                text: '$riskWindowDays days',
                style: TextStyle(
                  color: insightColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ];
          } else {
            insightIcon = Icons.warning_amber_rounded;
            insightColor = overBudget ? FSColors.danger : FSColors.warning;
            if (overBudget && dueCount > 0) {
              insightSpans = [
                const TextSpan(text: 'Over budget by '),
                TextSpan(
                  text: money(spentBudget - totalBudget),
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: '$dueCount',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text:
                      dueCount == 1
                          ? ' payment due in the next '
                          : ' payments due in the next ',
                ),
                TextSpan(
                  text: '$riskWindowDays days',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ];
            } else if (nearBudget && dueCount > 0) {
              insightSpans = [
                const TextSpan(text: 'Budget at '),
                TextSpan(
                  text: '$budgetPercentLabel%',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: '$dueCount',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text:
                      dueCount == 1
                          ? ' payment due in the next '
                          : ' payments due in the next ',
                ),
                TextSpan(
                  text: '$riskWindowDays days',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ];
            } else if (dueCount > 0) {
              insightSpans = [
                TextSpan(
                  text: '$dueCount',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text:
                      dueCount == 1
                          ? ' payment due in the next '
                          : ' payments due in the next ',
                ),
                TextSpan(
                  text: '$riskWindowDays days',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ];
            } else if (overBudget) {
              insightSpans = [
                const TextSpan(text: 'Over budget by '),
                TextSpan(
                  text: money(spentBudget - totalBudget),
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' this month'),
              ];
            } else {
              insightSpans = [
                const TextSpan(text: 'Budget at '),
                TextSpan(
                  text: '$budgetPercentLabel%',
                  style: TextStyle(
                    color: insightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' this month'),
              ];
            }
          }
        } else {
          insightIcon = Icons.lightbulb_outline;
          insightColor = Theme.of(context).colorScheme.primary;
          insightSpans = [TextSpan(text: cta)];
        }

        // Compute balance growth using balance history (same logic as Analytics)
        String ym(int y, int m) =>
            '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
        final Map<String, double> totalByMonth = {};
        for (final row in bh) {
          final key = ym(row.year, row.month);
          totalByMonth.update(
            key,
            (v) => v + row.balance,
            ifAbsent: () => row.balance,
          );
        }
        final months = totalByMonth.keys.toList()..sort();
        final double growth =
            months.length > 1
                ? ((totalByMonth[months.last]! - totalByMonth[months.first]!) /
                        (totalByMonth[months.first]! == 0
                            ? 1
                            : totalByMonth[months.first]!)) *
                    100
                : 0;

        // Build friendly greeting based on time and user name
        final hour = DateTime.now().hour;
        String partOfDay =
            hour < 12
                ? I18n.t(context, 'greet.morning')
                : (hour < 18
                    ? I18n.t(context, 'greet.afternoon')
                    : I18n.t(context, 'greet.night'));
        final Widget? savingsGoalCard =
            hasSavingsGoal
                ? _SavingsGoalSummaryCard(
                  progress: savingsProgress,
                  percentLabel: savingsPercentLabel,
                  savedLabel:
                      '${I18n.t(context, 'savingsGoal.saved')} ${money(savedThisMonth)} / ${money(savingsGoal)}',
                )
                : null;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FSSpacing.lg,
                  FSSpacing.lg,
                  FSSpacing.lg,
                  FSSpacing.xxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardInsightHeader(
                        partOfDay: partOfDay,
                        userName: auth.userName,
                        insightIcon: insightIcon,
                        insightColor: insightColor,
                        insightSpans: insightSpans,
                      ),
                      const SizedBox(height: FSSpacing.md),
                      if (savingsGoalCard != null) savingsGoalCard,
                      if (savingsGoalCard != null)
                        const SizedBox(height: FSSpacing.md),
                      // Upgrade banner for non-Pro
                      if (!auth.isProOrExempt) const UpgradeBanner(),
                      const SizedBox(height: FSSpacing.md),
                      // KPI Grid
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final kpis = [
                            KpiCard(
                              title: I18n.t(context, 'kpi.totalBalance'),
                              value: money(totalBalance),
                              icon: Icons.attach_money,
                              accent: FSIntent.primary,
                              deltaPercent: growth.abs(),
                              deltaIsPositive: growth >= 0,
                              subtitle: I18n.t(context, 'kpi.balanceGrowth'),
                            ),
                            KpiCard(
                              title: I18n.t(context, 'kpi.netThisMonth'),
                              value: money(currNet),
                              icon: Icons.account_balance_wallet_outlined,
                              accent:
                                  currNet >= 0
                                      ? FSIntent.success
                                      : FSIntent.danger,
                            ),
                            KpiCard(
                              title: I18n.t(context, 'kpi.thisMonthExpenses'),
                              value: money(currExp),
                              icon: Icons.trending_down,
                              accent: FSIntent.danger,
                              deltaPercent: expDelta.abs().toDouble(),
                              deltaIsPositive: currExp <= prevExp,
                              titleMaxLines: 2,
                              subtitle: I18n.t(context, 'kpi.vsLastMonth'),
                            ),
                            KpiCard(
                              title: I18n.t(context, 'kpi.budgetOverview'),
                              value: money(totalBudget),
                              icon: Icons.pie_chart_outline,
                              accent: FSIntent.warning,
                              titleMaxLines: 2,
                              footer: budgetFooter,
                            ),
                          ];
                          // Two uniform-height tiles per row; last odd spans full width
                          final cols = w < 360 ? 1 : 2;
                          const spacing = FSSpacing.md;
                          final itemWidth = (w - (cols - 1) * spacing) / cols;
                          final double itemHeight = cols == 1 ? 112 : 126;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (int i = 0; i < kpis.length; i++)
                                SizedBox(
                                  width:
                                      (cols == 2 &&
                                              i == kpis.length - 1 &&
                                              kpis.length % 2 == 1)
                                          ? w
                                          : itemWidth,
                                  height: itemHeight,
                                  child: kpis[i],
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: FSSpacing.md),
                      UpcomingEvents(payments: payments),
                      const SizedBox(height: FSSpacing.md),
                      AccountListSummary(
                        accounts: accounts.take(3).toList(),
                        onAdd:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AccountsScreenNew(),
                              ),
                            ),
                      ),
                      const SizedBox(height: FSSpacing.md),
                      RecentTransactions(
                        items: txs,
                        onViewAll:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TransactionsScreen(),
                              ),
                            ),
                      ),
                      const SizedBox(height: FSSpacing.md),
                      SubcategoryBudgetSummary(
                        categories: categories,
                        transactions: txs,
                        isPro: auth.isProOrExempt,
                      ),
                      const SizedBox(height: FSSpacing.md),
                      ProjectSummaries(projects: projects),
                      const SizedBox(height: FSSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardInsightHeader extends StatelessWidget {
  const _DashboardInsightHeader({
    required this.partOfDay,
    required this.userName,
    required this.insightIcon,
    required this.insightColor,
    required this.insightSpans,
  });

  final String partOfDay;
  final String userName;
  final IconData insightIcon;
  final Color insightColor;
  final List<InlineSpan> insightSpans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    final insightStyle = theme.textTheme.bodyMedium?.copyWith(
      color: FSColors.mutedText(context),
      height: 1.35,
      fontWeight: FontWeight.w600,
    );

    return FSCard(
      variant: FSCardVariant.interactive,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: titleStyle,
              children: [
                TextSpan(text: '$partOfDay, '),
                TextSpan(
                  text: userName,
                  style: titleStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: FSSpacing.md),
          Container(
            padding: const EdgeInsets.all(FSSpacing.md),
            decoration: BoxDecoration(
              color: FSColors.alpha(insightColor, 0.10),
              borderRadius: BorderRadius.circular(FSRadius.lg),
              border: Border.all(color: FSColors.alpha(insightColor, 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FSColors.alpha(insightColor, 0.14),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                  ),
                  child: Icon(insightIcon, size: 19, color: insightColor),
                ),
                const SizedBox(width: FSSpacing.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(style: insightStyle, children: insightSpans),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsGoalSummaryCard extends StatelessWidget {
  const _SavingsGoalSummaryCard({
    required this.progress,
    required this.percentLabel,
    required this.savedLabel,
  });

  final double progress;
  final String percentLabel;
  final String savedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FSCard(
      variant: FSCardVariant.subtle,
      padding: const EdgeInsets.all(FSSpacing.lg),
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
                  color: FSColors.intentContainer(context, FSIntent.success),
                  borderRadius: BorderRadius.circular(FSRadius.md),
                  border: Border.all(
                    color: FSColors.intentBorder(context, FSIntent.success),
                  ),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  size: 18,
                  color: FSColors.success,
                ),
              ),
              const SizedBox(width: FSSpacing.md),
              Expanded(
                child: Text(
                  I18n.t(context, 'savingsGoal.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FSStatusBadge(
                label: percentLabel,
                variant: FSStatusBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(FSRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: FSColors.success,
              backgroundColor: FSColors.intentContainer(
                context,
                FSIntent.success,
              ),
            ),
          ),
          const SizedBox(height: FSSpacing.sm),
          Text(
            savedLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: FSColors.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
