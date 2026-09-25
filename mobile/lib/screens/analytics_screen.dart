import '../momentum/widgets.dart';
import '../services/analytics_service.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../liquid_glass/liquid_glass.dart';
import '../widgets/pro_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<List<Object>>? _future;
  String? _token;
  DateTime? _selectedMonth;
  late final RefreshBus _refreshBus;
  int _accountsTick = 0;
  int _transactionsTick = 0;
  int _investmentsTick = 0;

  Future<List<Object>> _loadData(String? token) {
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    return Future.wait<Object>([
      data.getAccounts(),
      data.getTransactions(),
      data.getBalanceHistory(),
      data.getInvestments().catchError((_) => <Map<String, dynamic>>[]),
    ]);
  }

  Future<void> _refresh() async {
    final token = _token ?? context.read<AuthStore>().token;
    _token = token;
    final future = _loadData(token);
    setState(() => _future = future);
    await future;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AnalyticsService.instance.screen('analytics');
    });
    _refreshBus = context.read<RefreshBus>();
    _accountsTick = _refreshBus.accounts;
    _transactionsTick = _refreshBus.transactions;
    _investmentsTick = _refreshBus.investments;
    _refreshBus.addListener(_handleRefresh);
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
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
    if (_refreshBus.investments != _investmentsTick) {
      _investmentsTick = _refreshBus.investments;
      shouldRefresh = true;
    }
    if (shouldRefresh) {
      _refresh();
    }
  }

  DateTime _monthStart(DateTime value) => DateTime(value.year, value.month, 1);

  String _monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<DateTime> _availableMonths(
    List<TransactionItem> transactions,
    List<BalanceHistoryItem> history,
  ) {
    final months = <String, DateTime>{};
    for (final transaction in transactions) {
      final month = _monthStart(transaction.date);
      months[_monthKey(month)] = month;
    }
    for (final row in history) {
      final month = DateTime(row.year, row.month, 1);
      months[_monthKey(month)] = month;
    }
    if (months.isEmpty) {
      final now = _monthStart(DateTime.now());
      months[_monthKey(now)] = now;
    }
    final result = months.values.toList()..sort((a, b) => a.compareTo(b));
    return result;
  }

  DateTime _resolveSelectedMonth(List<DateTime> months) {
    if (months.isEmpty) return _monthStart(DateTime.now());
    final selected = _selectedMonth;
    if (selected != null) {
      for (final month in months) {
        if (_sameMonth(month, selected)) return month;
      }
    }
    return months.last;
  }

  Future<void> _pickAnalyticsMonth(
    List<DateTime> months,
    DateTime selectedMonth,
  ) async {
    if (months.isEmpty) return;
    if (months.length == 1) {
      setState(() => _selectedMonth = months.first);
      return;
    }
    final locale = Localizations.localeOf(context).toString();
    final monthFmt = DateFormat('MMMM yyyy', locale);
    final displayMonths = months.reversed.toList();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => LGBottomSheetShell(
            title: I18n.tr(context, 'tx.reportPickMonth'),
            scrollable: false,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: displayMonths.length,
              separatorBuilder:
                  (context, index) => const SizedBox(height: LGSpacing.sm),
              itemBuilder: (ctx, index) {
                final month = displayMonths[index];
                final isSelected = _sameMonth(month, selectedMonth);
                return _MonthOptionTile(
                  label: monthFmt.format(month),
                  selected: isSelected,
                  onTap: () => Navigator.pop(ctx, month),
                );
              },
            ),
          ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = _monthStart(picked));
    }
  }

  Widget _buildProBlock(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      children: [
        LGPageHeader(
          title: I18n.t(context, 'title.analytics'),
          leading: const _HeaderIcon(icon: Icons.analytics_outlined),
        ),
        const ProBlock(feature: 'Analytics'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isProOrExempt) {
      return _buildProBlock(context);
    }

    final token = auth.token;
    if (_future == null || _token != token) {
      _token = token;
      _future = _loadData(token);
    }

    return FutureBuilder<List<Object>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(LGSpacing.lg),
                child: LGSolidCard(
                  variant: LGCardVariant.elevated,
                  child: Text('Error: ${snap.error}'),
                ),
              ),
            );
          }
          return const Center(child: LGLoadingState());
        }

        final accounts = snap.data![0] as List<Account>;
        final transactions = snap.data![1] as List<TransactionItem>;
        final balanceHistory = snap.data![2] as List<BalanceHistoryItem>;
        final totalBalance = accounts.fold<double>(
          0,
          (sum, a) => sum + a.displayBalance,
        );
        final highestAccount = _highestAccount(accounts);

        final balanceDatasets = _buildBalanceDatasets(accounts, balanceHistory);
        final availableMonths = _availableMonths(transactions, balanceHistory);
        final selectedMonth = _resolveSelectedMonth(availableMonths);
        final selectedMonthLabel = DateFormat(
          'MMMM yyyy',
          Localizations.localeOf(context).toLanguageTag(),
        ).format(selectedMonth);
        final expenseByCategory = _bucketByCategory(
          transactions,
          month: selectedMonth,
          expense: true,
        );
        final incomeByCategory = _bucketByCategory(
          transactions,
          month: selectedMonth,
          expense: false,
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            children: [
              const MomentumContextStrip(feature: 'analytics'),
              LGPageHeader(
                title: I18n.t(context, 'title.analytics'),
                leading: const _HeaderIcon(icon: Icons.analytics_outlined),
              ),
              const SizedBox(height: LGSpacing.sm),
              _AnalyticsFilterSurface(
                selectedMonthLabel: selectedMonthLabel,
                growthPercent: balanceDatasets.growthPercent,
                onPickMonth:
                    () => _pickAnalyticsMonth(availableMonths, selectedMonth),
              ),
              const SizedBox(height: LGSpacing.md),
              _SummaryGrid(
                totalBalance: totalBalance,
                highestAccount: highestAccount,
                growthPercent: balanceDatasets.growthPercent,
              ),
              const SizedBox(height: LGSpacing.md),
              _BalanceCharts(
                totalSeries: balanceDatasets.totalSeries,
                perAccountSeries: balanceDatasets.accountSeries,
                accounts: accounts,
              ),
              const SizedBox(height: LGSpacing.md),
              _CategoryCharts(
                expenseData: expenseByCategory,
                incomeData: incomeByCategory,
                selectedMonth: selectedMonth,
              ),
              const SizedBox(height: LGSpacing.md),
              _AccountSummary(accounts: accounts),
            ],
          ),
        );
      },
    );
  }

  static Account? _highestAccount(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    return accounts.reduce(
      (prev, curr) => prev.displayBalance >= curr.displayBalance ? prev : curr,
    );
  }

  static _BalanceDatasets _buildBalanceDatasets(
    List<Account> accounts,
    List<BalanceHistoryItem> history,
  ) {
    if (history.isEmpty) {
      final now = DateTime.now();
      final label = DateFormat('MMM yyyy').format(now);
      final total = accounts.fold<double>(
        0,
        (sum, a) => sum + a.displayBalance,
      );
      final accountValues = <String, double>{};
      for (final account in accounts) {
        accountValues[_slug(account.name)] = _round(account.displayBalance);
      }
      return _BalanceDatasets(
        totalSeries: [_Point(label: label, value: _round(total))],
        accountSeries: [_AccountSeriesRow(label: label, values: accountValues)],
        growthPercent: 0,
      );
    }

    final monthly = <String, Map<int, double>>{};
    for (final row in history) {
      final key =
          '${row.year.toString().padLeft(4, '0')}-${row.month.toString().padLeft(2, '0')}';
      monthly.putIfAbsent(key, () => {});
      monthly[key]![row.accountId] = row.balance;
    }

    final keys = monthly.keys.toList()..sort();

    final totalSeries = <_Point>[];
    final perAccountSeries = <_AccountSeriesRow>[];

    for (final key in keys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final label = DateFormat('MMM yyyy').format(DateTime(year, month));

      final accountBalances = monthly[key] ?? {};
      double total = 0;
      final rowValues = <String, double>{};
      for (final account in accounts) {
        final value = accountBalances[account.id] ?? 0;
        rowValues[_slug(account.name)] = _round(value);
        total += value;
      }

      totalSeries.add(_Point(label: label, value: _round(total)));
      perAccountSeries.add(_AccountSeriesRow(label: label, values: rowValues));
    }

    double growth = 0;
    if (totalSeries.length > 1) {
      final first = totalSeries.first.value;
      final last = totalSeries.last.value;
      if (first != 0) {
        growth = ((last - first) / first) * 100;
      }
    }

    return _BalanceDatasets(
      totalSeries: totalSeries,
      accountSeries: perAccountSeries,
      growthPercent: growth,
    );
  }

  static Map<String, double> _bucketByCategory(
    List<TransactionItem> txs, {
    required DateTime month,
    required bool expense,
  }) {
    final monthPrefix = DateFormat('yyyy-MM').format(month);
    final map = <String, double>{};
    for (final t in txs) {
      final key = t.date.toIso8601String().substring(0, 7);
      if (key != monthPrefix) continue;
      if (expense && !t.isExpense) continue;
      if (!expense && !t.isIncome) continue;
      final category = t.effectiveCategory ?? 'Other';
      final value = expense ? t.amount.abs() : t.amount;
      map.update(category, (v) => v + value, ifAbsent: () => value);
    }
    return map.map((k, v) => MapEntry(k, _round(v)));
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _AnalyticsFilterSurface extends StatelessWidget {
  const _AnalyticsFilterSurface({
    required this.selectedMonthLabel,
    required this.growthPercent,
    required this.onPickMonth,
  });

  final String selectedMonthLabel;
  final double growthPercent;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final trendColor = growthPercent >= 0 ? LGColors.success : LGColors.danger;
    final trendLabel =
        '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%';

    return LGGlassCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  I18n.t(context, 'analytics.balanceGrowth'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LGSpacing.xs),
                Text(
                  trendLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: LGSpacing.md),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(LGRadius.pill),
              onTap: onPickMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LGSpacing.md,
                  vertical: LGSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: LGColors.glassLight(context),
                  borderRadius: BorderRadius.circular(LGRadius.pill),
                  border: Border.all(color: LGColors.glassStroke(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: LGSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        selectedMonthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: LGColors.textPrimary(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthOptionTile extends StatelessWidget {
  const _MonthOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LGSpacing.md,
            vertical: LGSpacing.md,
          ),
          decoration: BoxDecoration(
            color:
                selected
                    ? primary.withValues(
                      alpha: LGColors.isDark(context) ? 0.20 : 0.10,
                    )
                    : LGColors.surfaceSolid(context),
            borderRadius: BorderRadius.circular(LGRadius.lg),
            border: Border.all(
              color:
                  selected
                      ? primary.withValues(alpha: 0.28)
                      : LGColors.textSecondary(context).withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalBalance,
    required this.highestAccount,
    required this.growthPercent,
  });

  final double totalBalance;
  final Account? highestAccount;
  final double growthPercent;

  @override
  Widget build(BuildContext context) {
    final cards = [
      LGMetricCard(
        title: I18n.t(context, 'analytics.currentTotalBalance'),
        value: money(totalBalance),
        icon: Icons.account_balance_wallet_outlined,
        accentColor: LGColors.success,
      ),
      LGMetricCard(
        title: I18n.t(context, 'analytics.highestBalanceAccount'),
        value: money(highestAccount?.balance ?? 0),
        subtitle: highestAccount?.name ?? '-',
        icon: Icons.trending_up_rounded,
        accentColor: Theme.of(context).colorScheme.primary,
      ),
      LGMetricCard(
        title: I18n.t(context, 'analytics.balanceGrowth'),
        value:
            '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
        icon:
            growthPercent >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
        accentColor: growthPercent >= 0 ? LGColors.success : LGColors.danger,
      ),
    ];

    return LGMetricGrid(
      gap: 12,
      minChildHeight: 132,
      twoColumnBreakpoint: 300,
      children: cards,
    );
  }
}

class _BalanceCharts extends StatelessWidget {
  const _BalanceCharts({
    required this.totalSeries,
    required this.perAccountSeries,
    required this.accounts,
  });

  final List<_Point> totalSeries;
  final List<_AccountSeriesRow> perAccountSeries;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final compactFormatter = NumberFormat.compact(locale: localeTag);
    final axisLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: LGColors.textSecondary(context),
      fontWeight: FontWeight.w500,
    );
    final bottomLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: LGColors.textSecondary(context),
      fontWeight: FontWeight.w600,
    );
    final gridColor = LGColors.textSecondary(context).withValues(alpha: 0.16);
    final borderColor = LGColors.textSecondary(context).withValues(alpha: 0.12);

    final totalMax = _maxValue(totalSeries.map((point) => point.value));
    final perAccountMax = _maxValue(
      perAccountSeries.expand((row) => row.values.values),
    );
    final totalInterval = _gridInterval(totalMax);
    final perAccountInterval = _gridInterval(perAccountMax);

    Widget buildYAxisTitle(double value, double maxValue, double interval) {
      if (value < 0 || value > maxValue + (interval * 0.5)) {
        return const SizedBox.shrink();
      }
      return Text(
        _formatCompactNumber(value, compactFormatter),
        style: axisLabelStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: I18n.t(context, 'analytics.totalOverTime'),
          child: SizedBox(
            height: 260,
            child:
                totalSeries.isEmpty
                    ? _InlineEmptyState(
                      icon: Icons.show_chart_rounded,
                      label: I18n.t(context, 'analytics.noBalanceData'),
                    )
                    : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: totalMax == 0 ? 1 : totalMax * 1.1,
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: totalInterval,
                              reservedSize: 48,
                              getTitlesWidget:
                                  (value, meta) => buildYAxisTitle(
                                    value,
                                    totalMax,
                                    totalInterval,
                                  ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= totalSeries.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  totalSeries[index].label,
                                  style: bottomLabelStyle,
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            color: _lineColors[2],
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                            spots: [
                              for (var i = 0; i < totalSeries.length; i++)
                                FlSpot(i.toDouble(), totalSeries[i].value),
                            ],
                          ),
                        ],
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: totalInterval,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: gridColor,
                                dashArray: const [4, 4],
                                strokeWidth: 1,
                              ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        lineTouchData: const LineTouchData(enabled: false),
                        clipData: const FlClipData.all(),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: I18n.t(context, 'analytics.accountsOverTime'),
          child: SizedBox(
            height: 260,
            child:
                perAccountSeries.isEmpty
                    ? _InlineEmptyState(
                      icon: Icons.stacked_line_chart_rounded,
                      label: I18n.t(context, 'analytics.noAccBalanceData'),
                    )
                    : Column(
                      children: [
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY:
                                  perAccountMax == 0 ? 1 : perAccountMax * 1.1,
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: perAccountInterval,
                                    reservedSize: 48,
                                    getTitlesWidget:
                                        (value, meta) => buildYAxisTitle(
                                          value,
                                          perAccountMax,
                                          perAccountInterval,
                                        ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 ||
                                          index >= perAccountSeries.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        perAccountSeries[index].label,
                                        style: bottomLabelStyle,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                for (var i = 0; i < accounts.length; i++)
                                  LineChartBarData(
                                    isCurved: true,
                                    barWidth: 2.5,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                    color: _lineColors[i % _lineColors.length],
                                    spots: [
                                      for (
                                        var j = 0;
                                        j < perAccountSeries.length;
                                        j++
                                      )
                                        FlSpot(
                                          j.toDouble(),
                                          (perAccountSeries[j].values[_slug(
                                                accounts[i].name,
                                              )] ??
                                              0.0),
                                        ),
                                    ],
                                  ),
                              ],
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                horizontalInterval: perAccountInterval,
                                getDrawingHorizontalLine:
                                    (value) => FlLine(
                                      color: gridColor,
                                      dashArray: const [4, 4],
                                      strokeWidth: 1,
                                    ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: borderColor,
                                  width: 1,
                                ),
                              ),
                              lineTouchData: const LineTouchData(
                                enabled: false,
                              ),
                              clipData: const FlClipData.all(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _LineLegend(
                          colorByName: {
                            for (var i = 0; i < accounts.length; i++)
                              accounts[i].name:
                                  _lineColors[i % _lineColors.length],
                          },
                        ),
                      ],
                    ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCharts extends StatelessWidget {
  const _CategoryCharts({
    required this.expenseData,
    required this.incomeData,
    required this.selectedMonth,
  });

  final Map<String, double> expenseData;
  final Map<String, double> incomeData;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: I18n.t(context, 'analytics.expensesByCat'),
          child: _PieBlock(
            data: expenseData,
            emptyMessageKey: 'analytics.noExpenseData',
            month: selectedMonth,
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: I18n.t(context, 'analytics.incomeByCat'),
          child: _PieBlock(
            data: incomeData,
            emptyMessageKey: 'analytics.noIncomeData',
            month: selectedMonth,
          ),
        ),
      ],
    );
  }
}

class _PieBlock extends StatelessWidget {
  const _PieBlock({
    required this.data,
    required this.emptyMessageKey,
    required this.month,
  });
  final Map<String, double> data;
  final String emptyMessageKey;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 240,
        child: _InlineEmptyState(
          icon: Icons.pie_chart_outline_rounded,
          label: I18n.t(context, emptyMessageKey),
        ),
      );
    }

    final slices = _buildCategorySlices(data);
    if (slices.isEmpty) {
      return SizedBox(
        height: 240,
        child: _InlineEmptyState(
          icon: Icons.pie_chart_outline_rounded,
          label: I18n.t(context, emptyMessageKey),
        ),
      );
    }
    final total = slices.fold<double>(0, (sum, item) => sum + item.value);
    final top = slices.first;
    final language = Localizations.localeOf(context).languageCode;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat('MMMM yyyy', localeTag).format(month);
    final totalText = I18n.t(context, 'analytics.monthlyTotal');
    final topText = language == 'es' ? 'MAYOR' : 'HIGHEST';
    final theme = Theme.of(context);
    final onSurface = LGColors.textPrimary(context);
    final surface = LGColors.surfaceSolid(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        var chartSize = (availableWidth * 0.56).clamp(150.0, 220.0).toDouble();
        if (!chartSize.isFinite || chartSize <= 0) chartSize = 190.0;
        final centerSpace = chartSize * 0.30;
        // In fl_chart, section radius is ring thickness (not outer radius).
        final sliceRadius = chartSize * 0.18;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$totalText - $monthLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.74),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              money(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: chartSize,
                width: chartSize,
                child: ClipRect(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(enabled: false),
                          centerSpaceRadius: centerSpace,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                          sections: [
                            for (var i = 0; i < slices.length; i++)
                              PieChartSectionData(
                                showTitle: false,
                                radius: sliceRadius,
                                value: slices[i].value,
                                color: slices[i].color,
                                borderSide: BorderSide(
                                  color: surface,
                                  width: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              topText,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: onSurface.withValues(alpha: 0.66),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              top.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${top.percent.toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: top.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _LegendGrid(items: slices),
          ],
        );
      },
    );
  }
}

class _LegendGrid extends StatelessWidget {
  const _LegendGrid({required this.items});
  final List<_CategorySlice> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = constraints.maxWidth;
        final tileWidth =
            width >= 280 ? ((width - gap) / 2).toDouble() : width.toDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: LGColors.surfaceTinted(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: LGColors.textSecondary(
                        context,
                      ).withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: LGColors.textSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.percent.toStringAsFixed(0)}%',
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                color: LGColors.textPrimary(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: I18n.t(context, 'analytics.accountSummary'),
      child:
          accounts.isEmpty
              ? _InlineEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                label: I18n.t(context, 'analytics.noBalanceData'),
              )
              : Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    _AccountSummaryRow(account: accounts[i]),
                    if (i != accounts.length - 1)
                      Divider(
                        height: LGSpacing.lg,
                        color: LGColors.textSecondary(
                          context,
                        ).withValues(alpha: 0.14),
                      ),
                  ],
                ],
              ),
    );
  }
}

class _AccountSummaryRow extends StatelessWidget {
  const _AccountSummaryRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary.withValues(
              alpha: LGColors.isDark(context) ? 0.18 : 0.10,
            ),
            borderRadius: BorderRadius.circular(LGRadius.md),
            border: Border.all(color: primary.withValues(alpha: 0.20)),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: primary),
        ),
        const SizedBox(width: LGSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LGColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((account.type ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  account.type ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: LGSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            money(account.balance),
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: LGColors.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: LGColors.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: LGSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.lg,
        vertical: LGSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: LGColors.surfaceTinted(context),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(
          color: LGColors.textSecondary(context).withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(height: LGSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: LGColors.textSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineLegend extends StatelessWidget {
  const _LineLegend({required this.colorByName});
  final Map<String, Color> colorByName;

  @override
  Widget build(BuildContext context) {
    if (colorByName.isEmpty) return const SizedBox.shrink();
    final entries = colorByName.entries.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LGSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: LGColors.surfaceTinted(context),
              borderRadius: BorderRadius.circular(LGRadius.pill),
              border: Border.all(
                color: LGColors.textSecondary(context).withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Point {
  const _Point({required this.label, required this.value});
  final String label;
  final double value;
}

class _CategorySlice {
  const _CategorySlice({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
  final String label;
  final double value;
  final double percent;
  final Color color;
}

class _AccountSeriesRow {
  const _AccountSeriesRow({required this.label, required this.values});
  final String label;
  final Map<String, double> values;
}

class _BalanceDatasets {
  const _BalanceDatasets({
    required this.totalSeries,
    required this.accountSeries,
    required this.growthPercent,
  });

  final List<_Point> totalSeries;
  final List<_AccountSeriesRow> accountSeries;
  final double growthPercent;
}

String _slug(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
double _round(double value) => (value * 100).round() / 100;

List<_CategorySlice> _buildCategorySlices(Map<String, double> data) {
  final sorted =
      data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.isEmpty) return const [];

  final total = sorted.fold<double>(0, (sum, item) => sum + item.value);
  if (total <= 0) return const [];

  const maxVisible = 4;
  final collapsed = <MapEntry<String, double>>[];
  var remaining = 0.0;

  for (var i = 0; i < sorted.length; i++) {
    if (i < maxVisible) {
      collapsed.add(sorted[i]);
    } else {
      remaining += sorted[i].value;
    }
  }
  if (remaining > 0) {
    collapsed.add(MapEntry('Others', remaining));
  }

  return [
    for (var i = 0; i < collapsed.length; i++)
      _CategorySlice(
        label: collapsed[i].key,
        value: _round(collapsed[i].value),
        percent: (collapsed[i].value / total) * 100,
        color: _pieColors[i % _pieColors.length],
      ),
  ];
}

double _maxValue(Iterable<double> values) {
  var maxValue = 0.0;
  for (final value in values) {
    if (value > maxValue) maxValue = value;
  }
  return maxValue;
}

double _gridInterval(double maxValue) {
  if (maxValue <= 0) return 1;
  final target = maxValue / 3;
  if (target <= 0) return 1;
  final exponent = (math.log(target) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  for (final multiplier in [1, 2, 5, 10]) {
    final candidate = magnitude * multiplier;
    if (target <= candidate) {
      return candidate.toDouble();
    }
  }
  return magnitude * 10;
}

String _formatCompactNumber(double value, NumberFormat formatter) {
  if (value == 0) return '0';
  if (value.abs() < 1000) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
  return formatter.format(value);
}

const _lineColors = [
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
];

const _pieColors = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF22C55E),
];
