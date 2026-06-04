import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../widgets/pro_widgets.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';

class InvestmentDetailScreen extends StatefulWidget {
  const InvestmentDetailScreen({
    super.key,
    required this.investmentId,
    required this.name,
  });
  final int investmentId;
  final String name;

  @override
  State<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends State<InvestmentDetailScreen> {
  late final DataService _data;
  Map<String, dynamic>? _inv;
  List<Map<String, dynamic>> _cons = [];
  bool _loading = true;
  String? _error;

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _data.getInvestmentDetail(widget.investmentId);
      _inv = res['investment'] as Map<String, dynamic>;
      _cons =
          (res['contributions'] as List<dynamic>).cast<Map<String, dynamic>>();
      _error = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _valueToday() {
    if (_inv == null) return 0;
    final principal = _toDouble(_inv!['principal']);
    final rate = _toDouble(_inv!['annual_rate']);
    final start = DateTime.parse(_inv!['start_date'] as String);
    double sum = _futureValue(principal, rate, start);
    for (final c in _cons) {
      final amount = _toDouble(c['amount']);
      final date = DateTime.parse(c['date'] as String);
      sum += _futureValue(amount, rate, date);
    }
    return sum;
  }

  double _futureValue(double amount, double annualRate, DateTime from) {
    final now = DateTime.now();
    final start = DateTime(from.year, from.month, from.day);
    final days = now.difference(start).inDays;
    if (days <= 0) return amount;
    final r = (annualRate / 100.0) / 365.0;
    return (amount * math.pow(1 + r, days)).toDouble();
  }

  Future<void> _addContribution() async {
    final amtCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dctx) => AlertDialog(
            title: Text(I18n.t(context, 'invest.addContribution')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'invest.amount'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${I18n.t(context, 'invoices.date')}: ${formatDate(date)}',
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) {
                          date = p;
                          (dctx as Element).markNeedsBuild();
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dctx).pop(true),
                child: Text(I18n.t(context, 'label.save')),
              ),
            ],
          ),
    );
    if (ok == true) {
      try {
        final amt = double.tryParse(amtCtrl.text.replaceAll(',', '')) ?? 0;
        if (amt <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(I18n.tr(context, 'invest.validationAmount')),
            ),
          );
          return;
        }
        await _data.addInvestmentContribution(
          investmentId: widget.investmentId,
          amount: amt,
          date: date.toIso8601String().substring(0, 10),
        );
        if (mounted) {
          context.read<RefreshBus>().notifyInvestments();
        }
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(I18n.tr(context, 'invest.contributionAdded')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${I18n.tr(context, 'invest.addFailed')}: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return const Scaffold(body: ProBlock(feature: 'Investments'));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add contribution',
            icon: const Icon(Icons.add),
            onPressed: _addContribution,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContribution,
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: LGLoadingState())
              : (_error != null)
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LGSolidCard(
                    tinted: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DetailIcon(
                          icon: Icons.error_outline_rounded,
                          color: LGColors.danger,
                        ),
                        const SizedBox(height: LGSpacing.md),
                        Text(
                          'Failed to load investment',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: LGColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.sm),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: LGColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: LGSpacing.lg),
                        LGButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : (_inv == null)
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LGEmptyState(
                    icon: Icons.trending_up_rounded,
                    title: 'Investment not found',
                    message: widget.name,
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                children: [
                  _summary(),
                  const SizedBox(height: LGSpacing.lg),
                  _sectionHeader(
                    title: 'Contributions',
                    action: LGButton(
                      label: 'Add',
                      icon: Icons.add,
                      size: LGButtonSize.sm,
                      variant: LGButtonVariant.outline,
                      onPressed: _addContribution,
                    ),
                  ),
                  const SizedBox(height: LGSpacing.sm),
                  if (_cons.isEmpty)
                    LGEmptyState(
                      icon: Icons.savings_outlined,
                      title: 'No contributions yet',
                      message: I18n.t(context, 'invest.addContribution'),
                      action: LGEmptyAction(
                        label: I18n.t(context, 'invest.addContribution'),
                        icon: Icons.add,
                        onPressed: _addContribution,
                      ),
                    )
                  else
                    ..._cons.map((c) => _contributionRow(c)),
                ],
              ),
    );
  }

  Widget _summary() {
    final inv = _inv!;
    final principal = _toDouble(inv['principal']);
    final rate = _toDouble(inv['annual_rate']);
    final start = DateTime.parse(inv['start_date'] as String);
    final daysActive =
        DateTime.now()
            .difference(DateTime(start.year, start.month, start.day))
            .inDays;
    final totalContrib =
        principal + _cons.fold<double>(0, (s, c) => s + _toDouble(c['amount']));
    final current = _valueToday();
    final revenue = current - totalContrib;
    final revenueColor = revenue >= 0 ? LGColors.success : LGColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LGGlassCard(
          variant: LGCardVariant.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailIcon(
                    icon: Icons.trending_up_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv['name']?.toString().isNotEmpty == true
                              ? inv['name'].toString()
                              : widget.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            color: LGColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: LGSpacing.sm),
                        Wrap(
                          spacing: LGSpacing.sm,
                          runSpacing: LGSpacing.xs,
                          children: [
                            _metaPill(
                              Icons.calendar_today_outlined,
                              formatDate(start),
                            ),
                            _metaPill(
                              Icons.percent_rounded,
                              '${rate.toStringAsFixed(2)}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LGSpacing.xl),
              Text(
                'Current Value',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: LGColors.textSecondary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: LGSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(current),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: LGSpacing.md),
              Wrap(
                spacing: LGSpacing.sm,
                runSpacing: LGSpacing.sm,
                children: [
                  _valuePill(
                    Icons.account_balance_wallet_outlined,
                    'Invested ${money(totalContrib)}',
                    Theme.of(context).colorScheme.primary,
                  ),
                  _valuePill(
                    revenue >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    'Revenue ${money(revenue)}',
                    revenueColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: LGSpacing.md),
        LGMetricGrid(
          runGap: LGSpacing.sm,
          expandLastOdd: false,
          children: [
            _kv(
              'Initial Amount',
              money(principal),
              Icons.account_balance_wallet_outlined,
              Theme.of(context).colorScheme.primary,
            ),
            _kv(
              'Rate (APR)',
              '${rate.toStringAsFixed(2)}%',
              Icons.percent_rounded,
              LGColors.info,
            ),
            _kv(
              'Days Active',
              daysActive.toString(),
              Icons.calendar_view_day_outlined,
              LGColors.warning,
            ),
            _kv(
              'Total Contributed',
              money(totalContrib),
              Icons.add_card_outlined,
              LGColors.info,
            ),
            _kv(
              'Current Value',
              money(current),
              Icons.stacked_line_chart_rounded,
              LGColors.success,
            ),
            _kv(
              'Revenue',
              money(revenue),
              revenue >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              revenueColor,
              valueColor: revenueColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionHeader({required String title, Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: LGColors.textPrimary(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(width: LGSpacing.md), action],
      ],
    );
  }

  Widget _contributionRow(Map<String, dynamic> c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.sm),
      child: LGSolidCard(
        tinted: true,
        padding: const EdgeInsets.all(LGSpacing.md),
        child: Row(
          children: [
            _DetailIcon(
              icon: Icons.savings_outlined,
              color: LGColors.info,
              size: 42,
            ),
            const SizedBox(width: LGSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(_toDouble(c['amount'])),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LGColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: LGSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: LGColors.textSecondary(context),
                        size: 15,
                      ),
                      const SizedBox(width: LGSpacing.xs),
                      Expanded(
                        child: Text(
                          formatYmd(c['date'] as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: LGColors.textSecondary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(
    String k,
    String v,
    IconData icon,
    Color accentColor, {
    Color? valueColor,
  }) {
    return LGSolidCard(
      tinted: true,
      padding: const EdgeInsets.all(LGSpacing.md),
      child: Row(
        children: [
          _DetailIcon(icon: icon, color: accentColor, size: 38),
          const SizedBox(width: LGSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    v,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: valueColor ?? LGColors.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.sm,
        vertical: 5,
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
          Icon(icon, size: 14, color: LGColors.textSecondary(context)),
          const SizedBox(width: LGSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LGColors.textSecondary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valuePill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.md,
        vertical: LGSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(LGRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: LGSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailIcon extends StatelessWidget {
  const _DetailIcon({required this.icon, required this.color, this.size = 48});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(
          size >= 48 ? LGRadius.lg : LGRadius.md,
        ),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size >= 48 ? 25 : 18),
    );
  }
}
