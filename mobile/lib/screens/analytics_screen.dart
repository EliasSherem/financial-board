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
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
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
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (ctx) => FSBottomSheetShell(
            title: I18n.tr(context, 'tx.reportPickMonth'),
            scrollable: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: displayMonths.length,
                    itemBuilder: (ctx, index) {
                      final month = displayMonths[index];
                      final isSelected = _sameMonth(month, selectedMonth);
                      return _MonthPickerTile(
                        label: monthFmt.format(month),
                        selected: isSelected,
                        onTap: () => Navigator.pop(ctx, month),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = _monthStart(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isProOrExempt) {
      return Scaffold(
        backgroundColor: FSColors.background(context),
        appBar: AppBar(title: Text(I18n.t(context, 'title.analytics'))),
        body: const ProBlock(feature: 'Analytics'),
      );
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
            return _AnalyticsErrorState(message: 'Error: ${snap.error}');
          }
          return const FSLoadingState();
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

        return Scaffold(
          backgroundColor: FSColors.background(context),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: Theme.of(context).colorScheme.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FSSpacing.lg,
                FSSpacing.lg,
                FSSpacing.lg,
                FSSpacing.xxl,
              ),
              children: [
                FSPageHeader(
                  title: I18n.t(context, 'title.analytics'),
                  leading: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FSColors.intentContainer(
                        context,
                        FSIntent.primary,
                      ),
                      borderRadius: BorderRadius.circular(FSRadius.md),
                      border: Border.all(
                        color: FSColors.intentBorder(context, FSIntent.primary),
                      ),
                    ),
                    child: const Icon(
                      Icons.query_stats_rounded,
                      color: FSColors.primary,
                    ),
                  ),
                ),
                _SummaryGrid(
                  totalBalance: totalBalance,
                  highestAccount: highestAccount,
                  growthPercent: balanceDatasets.growthPercent,
                ),
                const SizedBox(height: FSSpacing.md),
                _BalanceCharts(
                  totalSeries: balanceDatasets.totalSeries,
                  perAccountSeries: balanceDatasets.accountSeries,
                  accounts: accounts,
                ),
                const SizedBox(height: FSSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FSButton(
                    label: selectedMonthLabel,
                    icon: Icons.calendar_month_outlined,
                    variant: FSButtonVariant.outline,
                    onPressed:
                        () =>
                            _pickAnalyticsMonth(availableMonths, selectedMonth),
                  ),
                ),
                const SizedBox(height: FSSpacing.md),
                _CategoryCharts(
                  expenseData: expenseByCategory,
                  incomeData: incomeByCategory,
                  selectedMonth: selectedMonth,
                ),
                const SizedBox(height: FSSpacing.md),
                _AccountSummary(accounts: accounts),
              ],
            ),
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

class _MonthPickerTile extends StatelessWidget {
  const _MonthPickerTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.sm),
      child: Material(
        color:
            selected
                ? FSColors.intentContainer(context, FSIntent.primary)
                : FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FSRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.md,
              vertical: FSSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(
                color:
                    selected
                        ? FSColors.intentBorder(context, FSIntent.primary)
                        : FSColors.border(context),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: FSSpacing.sm),
                  Icon(Icons.check_rounded, color: foreground, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsErrorState extends StatelessWidget {
  const _AnalyticsErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FSCard(
        margin: const EdgeInsets.all(FSSpacing.lg),
        variant: FSCardVariant.subtle,
        child: FSEmptyState(icon: Icons.error_outline_rounded, title: message),
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
      FSMetricCard(
        title: I18n.t(context, 'analytics.currentTotalBalance'),
        value: money(totalBalance),
        icon: Icons.account_balance_wallet_outlined,
        accent: FSIntent.success,
      ),
      FSMetricCard(
        title: I18n.t(context, 'analytics.highestBalanceAccount'),
        value: money(highestAccount?.balance ?? 0),
        subtitle: highestAccount?.name ?? '-',
        icon: Icons.account_balance_rounded,
        accent: FSIntent.primary,
      ),
      FSMetricCard(
        title: I18n.t(context, 'analytics.balanceGrowth'),
        value:
            '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
        icon: growthPercent >= 0 ? Icons.trending_up : Icons.trending_down,
        accent: growthPercent >= 0 ? FSIntent.success : FSIntent.danger,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = FSSpacing.md;
        final double maxWidth = constraints.maxWidth;
        final cols = maxWidth < 360 ? 1 : 2;
        final double itemWidth = (maxWidth - (cols - 1) * spacing) / cols;
        final children = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          final isLastOdd =
              cols == 2 && cards.length.isOdd && i == cards.length - 1;
          children.add(
            SizedBox(
              width: isLastOdd ? maxWidth : itemWidth,
              height: 138,
              child: cards[i],
            ),
          );
        }
        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      },
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
      color: FSColors.mutedText(context),
      fontWeight: FontWeight.w500,
    );
    final bottomLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: FSColors.mutedText(context),
      fontWeight: FontWeight.w600,
    );
    final gridColor = FSColors.alpha(theme.colorScheme.onSurface, 0.12);
    final borderColor = FSColors.border(context);

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
          icon: Icons.stacked_line_chart_rounded,
          accent: FSIntent.primary,
          child: SizedBox(
            height: 260,
            child:
                totalSeries.isEmpty
                    ? FSEmptyState(
                      icon: Icons.stacked_line_chart_rounded,
                      title: I18n.t(context, 'analytics.noBalanceData'),
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
        const SizedBox(height: FSSpacing.md),
        _Card(
          title: I18n.t(context, 'analytics.accountsOverTime'),
          icon: Icons.account_tree_outlined,
          accent: FSIntent.info,
          child: SizedBox(
            height: 260,
            child:
                perAccountSeries.isEmpty
                    ? FSEmptyState(
                      icon: Icons.account_tree_outlined,
                      title: I18n.t(context, 'analytics.noAccBalanceData'),
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
                        const SizedBox(height: FSSpacing.md),
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
          icon: Icons.trending_down_rounded,
          accent: FSIntent.danger,
          child: _PieBlock(
            data: expenseData,
            emptyMessageKey: 'analytics.noExpenseData',
            month: selectedMonth,
          ),
        ),
        const SizedBox(height: FSSpacing.md),
        _Card(
          title: I18n.t(context, 'analytics.incomeByCat'),
          icon: Icons.trending_up_rounded,
          accent: FSIntent.success,
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
        child: FSEmptyState(
          icon: Icons.pie_chart_outline,
          title: I18n.t(context, emptyMessageKey),
        ),
      );
    }

    final slices = _buildCategorySlices(data);
    if (slices.isEmpty) {
      return SizedBox(
        height: 240,
        child: FSEmptyState(
          icon: Icons.pie_chart_outline,
          title: I18n.t(context, emptyMessageKey),
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
    final onSurface = theme.colorScheme.onSurface;
    final surface = FSColors.surfaceElevated(context);
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
                color: FSColors.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: FSSpacing.xs),
            Text(
              money(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: FSSpacing.lg),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: FSSpacing.lg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              topText,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: FSColors.mutedText(context),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: FSSpacing.xs),
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
            const SizedBox(height: FSSpacing.md),
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
        const gap = FSSpacing.sm;
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
                    horizontal: FSSpacing.md,
                    vertical: FSSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: FSColors.surface(context),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                    border: Border.all(color: FSColors.border(context)),
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
                      const SizedBox(width: FSSpacing.sm),
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
                                color: FSColors.mutedText(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.percent.toStringAsFixed(0)}%',
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
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
      icon: Icons.account_balance_wallet_outlined,
      accent: FSIntent.primary,
      child: Column(
        children: [
          if (accounts.isEmpty)
            FSEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: I18n.t(context, 'analytics.accountSummary'),
            )
          else
            ...accounts.map((a) => _AccountSummaryRow(account: a)),
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
    final balanceColor =
        account.balance < 0
            ? FSColors.danger
            : Theme.of(context).colorScheme.onSurface;
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
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(color: FSColors.border(context)),
            ),
            child: Icon(
              account.isInvestment
                  ? Icons.trending_up_rounded
                  : Icons.account_balance_rounded,
              size: 19,
              color: FSColors.mutedText(context),
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if ((account.type ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    account.type!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FSColors.mutedText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                money(account.balance),
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.icon,
    this.accent = FSIntent.primary,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final FSIntent accent;

  @override
  Widget build(BuildContext context) {
    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FSColors.intentContainer(context, accent),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                    border: Border.all(
                      color: FSColors.intentBorder(context, accent),
                    ),
                  ),
                  child: Icon(icon, size: 20, color: FSColors.intent(accent)),
                ),
                const SizedBox(width: FSSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.md),
          child,
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
      spacing: FSSpacing.sm,
      runSpacing: FSSpacing.sm,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FSSpacing.md,
              vertical: FSSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: FSColors.surface(context),
              borderRadius: BorderRadius.circular(FSRadius.pill),
              border: Border.all(color: FSColors.border(context)),
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
                const SizedBox(width: FSSpacing.sm),
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FSColors.mutedText(context),
                    fontWeight: FontWeight.w600,
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
