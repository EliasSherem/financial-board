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
import '../widgets/pro_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<List<Object>>? _future;
  String? _token;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isProOrExempt) {
      return Scaffold(
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
            return Center(child: Text('Error: ${snap.error}'));
          }
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snap.data![0] as List<Account>;
        final transactions = snap.data![1] as List<TransactionItem>;
        final balanceHistory = snap.data![2] as List<BalanceHistoryItem>;
        final investments = snap.data![3] as List<Map<String, dynamic>>;

        final investmentsTotal = accounts
            .where((a) => a.isInvestment)
            .fold<double>(0, (sum, a) => sum + a.displayBalance);
        final totalBalance =
            accounts.fold<double>(0, (sum, a) => sum + a.displayBalance);
        final highestAccount = _highestAccount(accounts);

        final balanceDatasets = _buildBalanceDatasets(accounts, balanceHistory);
        final expenseByCategory = _bucketByCategory(transactions, expense: true);
        final incomeByCategory = _bucketByCategory(transactions, expense: false);

        return Scaffold(
          appBar: AppBar(title: Text(I18n.t(context, 'title.analytics'))),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryGrid(
                  totalBalance: totalBalance,
                  highestAccount: highestAccount,
                  growthPercent: balanceDatasets.growthPercent,
                ),
                const SizedBox(height: 16),
                _BalanceCharts(
                  totalSeries: balanceDatasets.totalSeries,
                  perAccountSeries: balanceDatasets.accountSeries,
                  accounts: accounts,
                ),
                const SizedBox(height: 16),
                _CategoryCharts(
                  expenseData: expenseByCategory,
                  incomeData: incomeByCategory,
                ),
                const SizedBox(height: 16),
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
      final total = accounts.fold<double>(0, (sum, a) => sum + a.displayBalance);
      final accountValues = <String, double>{};
      for (final account in accounts) {
        accountValues[_slug(account.name)] = _round(account.displayBalance);
      }
      return _BalanceDatasets(
        totalSeries: [
          _Point(label: label, value: _round(total)),
        ],
        accountSeries: [
          _AccountSeriesRow(label: label, values: accountValues),
        ],
        growthPercent: 0,
      );
    }

    final monthly = <String, Map<int, double>>{};
    for (final row in history) {
      final key = '${row.year.toString().padLeft(4, '0')}-${row.month.toString().padLeft(2, '0')}';
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

    return _BalanceDatasets(totalSeries: totalSeries, accountSeries: perAccountSeries, growthPercent: growth);
  }

  static Map<String, double> _bucketByCategory(List<TransactionItem> txs, {required bool expense}) {
    final monthPrefix = DateFormat('yyyy-MM').format(DateTime.now());
    final map = <String, double>{};
    for (final t in txs) {
      final key = t.date.toIso8601String().substring(0, 7);
      if (key != monthPrefix) continue;
      final amount = t.amount;
      if (expense && amount >= 0) continue;
      if (!expense && amount <= 0) continue;
      final category = t.categoryName ?? t.category ?? 'Other';
      final value = expense ? amount.abs() : amount;
      map.update(category, (v) => v + value, ifAbsent: () => value);
    }
    return map.map((k, v) => MapEntry(k, _round(v)));
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
    final locale = Localizations.localeOf(context);
    final cards = [
      _Card(
        title: I18n.t(context, 'analytics.currentTotalBalance'),
        child: Text(
          money(totalBalance),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green),
        ),
      ),
      _Card(
        title: I18n.t(context, 'analytics.highestBalanceAccount'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(highestAccount?.name ?? '-'),
            const SizedBox(height: 4),
            Text(
              NumberFormat.simpleCurrency(locale: locale.toLanguageTag()).format(highestAccount?.balance ?? 0),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      _Card(
        title: I18n.t(context, 'analytics.balanceGrowth'),
        child: Text(
          '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: growthPercent >= 0 ? Colors.green : Colors.red,
              ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final double maxWidth = constraints.maxWidth;
        final double itemWidth = (maxWidth - spacing) / 2;
        final children = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          final isLastOdd = cards.length.isOdd && i == cards.length - 1;
          children.add(
            SizedBox(
              width: isLastOdd ? maxWidth : itemWidth,
              child: cards[i],
            ),
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children,
        );
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
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      fontWeight: FontWeight.w500,
    );
    final bottomLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );
    final gridColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

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
            child: totalSeries.isEmpty
                ? Center(child: Text(I18n.t(context, 'analytics.noBalanceData')))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: totalMax == 0 ? 1 : totalMax * 1.1,
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: totalInterval,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) => buildYAxisTitle(value, totalMax, totalInterval),
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
                        getDrawingHorizontalLine: (value) => FlLine(
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
            child: perAccountSeries.isEmpty
                ? Center(child: Text(I18n.t(context, 'analytics.noAccBalanceData')))
                : Column(
                    children: [
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: perAccountMax == 0 ? 1 : perAccountMax * 1.1,
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: perAccountInterval,
                                  reservedSize: 48,
                                  getTitlesWidget: (value, meta) =>
                                      buildYAxisTitle(value, perAccountMax, perAccountInterval),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= perAccountSeries.length) {
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
                                    for (var j = 0; j < perAccountSeries.length; j++)
                                      FlSpot(
                                        j.toDouble(),
                                        (perAccountSeries[j].values[_slug(accounts[i].name)] ?? 0.0),
                                      ),
                                  ],
                                ),
                            ],
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              horizontalInterval: perAccountInterval,
                              getDrawingHorizontalLine: (value) => FlLine(
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
                      const SizedBox(height: 12),
                      _LineLegend(
                        colorByName: {
                          for (var i = 0; i < accounts.length; i++)
                            accounts[i].name: _lineColors[i % _lineColors.length],
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
  });

  final Map<String, double> expenseData;
  final Map<String, double> incomeData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          title: I18n.t(context, 'analytics.expensesByCatCM'),
          child: _PieBlock(
            data: expenseData,
            emptyMessageKey: 'analytics.noExpenseData',
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: I18n.t(context, 'analytics.incomeByCatCM'),
          child: _PieBlock(
            data: incomeData,
            emptyMessageKey: 'analytics.noIncomeData',
          ),
        ),
      ],
    );
  }
}

class _PieBlock extends StatelessWidget {
  const _PieBlock({required this.data, required this.emptyMessageKey});
  final Map<String, double> data;
  final String emptyMessageKey;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(child: Text(I18n.t(context, emptyMessageKey))),
      );
    }

    final entries = data.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final double maxSize = ((availableWidth - 48.0).clamp(120.0, 200.0)).toDouble();
        double chartSize = ((availableWidth * 0.55).clamp(120.0, maxSize)).toDouble();
        chartSize = math.min(chartSize, maxSize);
        if (!chartSize.isFinite || chartSize <= 0) chartSize = 140.0;
        final double sliceRadius = math.max(0, (chartSize / 2) - 8.0);
        return Column(
          children: [
            SizedBox(
              height: chartSize,
              width: chartSize,
              child: Center(
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(enabled: false),
                    sectionsSpace: 0,
                    centerSpaceRadius: 0,
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          showTitle: false,
                          radius: sliceRadius,
                          value: entries[i].value,
                          color: _pieColors[i % _pieColors.length],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _LegendList(data: data),
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
      child: Column(
        children: accounts
            .map(
              (a) => ListTile(
                title: Text(a.name),
                subtitle: Text(a.type ?? ''),
                trailing: Text(money(a.balance)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LegendList extends StatelessWidget {
  const _LegendList({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _pieColors[i % _pieColors.length],
              radius: 6,
            ),
            title: Text(entries[i].key),
            trailing: Text(money(entries[i].value)),
          ),
      ],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
            ],
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

String _slug(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
double _round(double value) => (value * 100).round() / 100;

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
