import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../ui/finsight_ui.dart';
import 'investment_detail_screen.dart';
import '../widgets/pro_widgets.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
  return 0.0;
}

class Investment {
  final String id;
  final String name;
  final double principal;
  final double annualRate; // as percent, e.g., 8.5
  final DateTime startDate;
  final double? estimatedValue;
  final double totalContrib;

  Investment({
    required this.id,
    required this.name,
    required this.principal,
    required this.annualRate,
    required this.startDate,
    this.estimatedValue,
    this.totalContrib = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'principal': principal,
    'annualRate': annualRate,
    'startDate': startDate.toIso8601String().substring(0, 10),
  };

  static Investment fromJson(Map<String, dynamic> m) => Investment(
    id: (m['id']).toString(),
    name: m['name'] as String? ?? '',
    principal: _toDouble(m['principal']),
    annualRate: _toDouble(m['annual_rate'] ?? m['annualRate']),
    startDate: DateTime.parse(
      (m['start_date'] as String?) ?? (m['startDate'] as String),
    ),
    estimatedValue:
        m.containsKey('estimated_value')
            ? _toDouble(m['estimated_value'])
            : null,
    totalContrib: _toDouble(m['total_contributions']),
  );
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key, this.autoOpen = false});
  final bool autoOpen;

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Investment> _items = [];
  bool _loading = true;
  DataService? _data;
  late final RefreshBus _refreshBus;
  int _investmentsTick = 0;

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _investmentsTick = _refreshBus.investments;
    _refreshBus.addListener(_handleRefresh);
    final isPro = context.read<AuthStore>().isProOrExempt;
    if (isPro) {
      _load();
    } else {
      _loading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthStore>().isProOrExempt && widget.autoOpen) {
        try {
          _addDialog();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  DataService _svc() {
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    return DataService(api);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      _data ??= _svc();
      final rows = await _data!.getInvestments();
      if (!mounted) return;
      setState(() {
        _items = rows.map(Investment.fromJson).toList();
        _loading = false;
      });
      // Fallback enrichment: if contributions are missing (0) try fetching per-item details
      if (mounted && _items.any((e) => (e.totalContrib) == 0)) {
        try {
          final List<Investment> enriched = [];
          for (final it in _items) {
            if ((it.totalContrib) == 0) {
              final id = int.tryParse(it.id) ?? 0;
              if (id != 0) {
                final detail = await (_data ?? _svc()).getInvestmentDetail(id);
                final cons =
                    (detail['contributions'] as List<dynamic>? ?? const [])
                        .cast<Map<String, dynamic>>();
                final sum = cons.fold<double>(0.0, (s, c) {
                  final v = c['amount'];
                  double d;
                  if (v == null) {
                    d = 0.0;
                  } else if (v is num) {
                    d = v.toDouble();
                  } else {
                    d = double.tryParse('$v'.replaceAll(',', '')) ?? 0.0;
                  }
                  return s + d;
                });
                enriched.add(
                  Investment(
                    id: it.id,
                    name: it.name,
                    principal: it.principal,
                    annualRate: it.annualRate,
                    startDate: it.startDate,
                    estimatedValue: it.estimatedValue,
                    totalContrib: sum,
                  ),
                );
              } else {
                enriched.add(it);
              }
            } else {
              enriched.add(it);
            }
          }
          if (mounted) setState(() => _items = enriched);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load investments: $e')));
    }
  }

  Future<void> _refresh() => _load(showLoader: false);

  void _handleRefresh() {
    if (!mounted) return;
    if (_refreshBus.investments != _investmentsTick) {
      _investmentsTick = _refreshBus.investments;
      _refresh();
    }
  }

  double _valueToday(Investment x) {
    final now = DateTime.now();
    final start = DateTime(
      x.startDate.year,
      x.startDate.month,
      x.startDate.day,
    );
    final days = now.difference(start).inDays;
    if (days <= 0) return x.principal;
    final r = (x.annualRate / 100.0) / 365.0; // daily rate
    return (x.principal * math.pow(1 + r, days)).toDouble();
  }

  Future<void> _addDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '');
    final rateCtrl = TextEditingController(text: '');
    final dateCtrl = TextEditingController(text: formatDate(DateTime.now()));
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: Text(I18n.t(context, 'invest.add')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invest.name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invest.amount'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invest.rate'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invest.startDate'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dateCtrl.text = formatDate(picked);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final amt =
                        double.tryParse(amountCtrl.text.replaceAll(',', '')) ??
                        0;
                    final rate =
                        double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? 0;
                    final start =
                        parseDdMmYyyy(dateCtrl.text.trim()) ?? DateTime.now();
                    if (amt <= 0) {
                      final sm = ScaffoldMessenger.maybeOf(context);
                      sm?.showSnackBar(
                        SnackBar(
                          content: Text(
                            I18n.tr(context, 'invest.validationAmount'),
                          ),
                        ),
                      );
                      return;
                    }
                    final ds = _data ?? _svc();
                    await ds.createInvestment(
                      name:
                          nameCtrl.text.trim().isEmpty
                              ? I18n.tr(context, 'invest.defaultName')
                              : nameCtrl.text.trim(),
                      principal: amt,
                      annualRate: rate,
                      startDate: start.toIso8601String().substring(0, 10),
                    );
                    Navigator.of(dialogCtx).pop(true);
                  } catch (e) {
                    final sm = ScaffoldMessenger.maybeOf(context);
                    sm?.showSnackBar(
                      SnackBar(content: Text('Failed to save: $e')),
                    );
                  }
                },
                child: Text(I18n.t(context, 'label.save')),
              ),
            ],
          ),
    );
    if (ok == true && mounted) {
      context.read<RefreshBus>().notifyInvestments();
      await _load();
    }
  }

  Future<void> _delete(Investment inv) async {
    try {
      // server ids are ints, we stored as string; try parse
      final id = int.tryParse(inv.id) ?? 0;
      if (id != 0) {
        final ds = _data ?? _svc();
        await ds.deleteInvestment(id);
      }
      if (mounted) {
        context.read<RefreshBus>().notifyInvestments();
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return Scaffold(
        backgroundColor: FSColors.background(context),
        appBar: AppBar(title: Text(I18n.t(context, 'title.investments'))),
        body: const ProBlock(feature: 'Investments'),
      );
    }
    if (_loading) return const FSLoadingState();
    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(title: Text(I18n.t(context, 'title.investments'))),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _refresh,
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
              title: I18n.t(context, 'title.investments'),
              leading: const _InvestmentsHeaderIcon(),
              action: FSButton(
                label: I18n.t(context, 'invest.add'),
                icon: Icons.add_rounded,
                size: FSButtonSize.sm,
                onPressed: _addDialog,
              ),
            ),
            if (_items.isEmpty)
              FSCard(
                variant: FSCardVariant.elevated,
                child: FSEmptyState(
                  icon: Icons.trending_up_rounded,
                  title: I18n.t(context, 'invest.none'),
                  action: FSButton(
                    label: I18n.t(context, 'invest.add'),
                    icon: Icons.add_rounded,
                    onPressed: _addDialog,
                  ),
                ),
              )
            else ...[
              _kpiGrid(context, _computeTotals()),
              const SizedBox(height: FSSpacing.md),
              for (final it in _items) ...[
                _InvestmentCard(
                  investment: it,
                  value:
                      (it.estimatedValue ?? _valueToday(it)) +
                      (it.estimatedValue == null ? it.totalContrib : 0),
                  onTap: () async {
                    final intId = int.tryParse(it.id) ?? 0;
                    if (intId != 0) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => InvestmentDetailScreen(
                                investmentId: intId,
                                name: it.name,
                              ),
                        ),
                      );
                      if (mounted) await _load();
                    }
                  },
                  onDelete: () => _delete(it),
                ),
                const SizedBox(height: FSSpacing.md),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.lg),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Map<String, double> _computeTotals() {
    double principal = 0, contrib = 0, value = 0;
    for (final it in _items) {
      principal += it.principal;
      contrib += it.totalContrib;
      value += (it.estimatedValue ?? _valueToday(it));
    }
    final revenue = value - (principal + contrib);
    return {
      'principal': principal,
      'contrib': contrib,
      'value': value,
      'revenue': revenue,
    };
  }

  Widget _kpiGrid(BuildContext context, Map<String, double> t) {
    final revenue = t['revenue'] ?? 0;
    final tiles = <Widget>[
      FSMetricCard(
        title: 'Total Invested',
        value: money((t['principal'] ?? 0) + (t['contrib'] ?? 0)),
        icon: Icons.account_balance_rounded,
        accent: FSIntent.primary,
      ),
      FSMetricCard(
        title: 'Total Contributions',
        value: money(t['contrib'] ?? 0),
        icon: Icons.add_card_outlined,
        accent: FSIntent.info,
      ),
      FSMetricCard(
        title: 'Total Value',
        value: money(t['value'] ?? 0),
        icon: Icons.stacked_line_chart_rounded,
        accent: FSIntent.success,
      ),
      FSMetricCard(
        title: 'Total Revenue',
        value: money(revenue),
        icon:
            revenue >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
        accent: revenue >= 0 ? FSIntent.success : FSIntent.danger,
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        const spacing = FSSpacing.md;
        final w = c.maxWidth;
        final columns = w < 360 ? 1 : 2;
        final itemW = (w - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: itemW, height: 138, child: tile),
          ],
        );
      },
    );
  }
}

class _InvestmentsHeaderIcon extends StatelessWidget {
  const _InvestmentsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FSColors.intentContainer(context, FSIntent.primary),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color: FSColors.intentBorder(context, FSIntent.primary),
        ),
      ),
      child: const Icon(Icons.trending_up_rounded, color: FSColors.primary),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({
    required this.investment,
    required this.value,
    required this.onTap,
    required this.onDelete,
  });

  final Investment investment;
  final double value;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final gain = value - (investment.principal + investment.totalContrib);
    final gainIntent = gain >= 0 ? FSIntent.success : FSIntent.danger;
    final gainColor = FSColors.intent(gainIntent);
    return FSCard(
      variant: FSCardVariant.interactive,
      onTap: onTap,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FSColors.intentContainer(context, FSIntent.primary),
                  borderRadius: BorderRadius.circular(FSRadius.md),
                  border: Border.all(
                    color: FSColors.intentBorder(context, FSIntent.primary),
                  ),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: FSColors.primary,
                ),
              ),
              const SizedBox(width: FSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: FSSpacing.xs),
                    Wrap(
                      spacing: FSSpacing.sm,
                      runSpacing: FSSpacing.xs,
                      children: [
                        FSStatusBadge(
                          label: '${investment.annualRate.toStringAsFixed(2)}%',
                          variant: FSStatusBadgeVariant.info,
                          icon: Icons.percent_rounded,
                        ),
                        FSStatusBadge(
                          label: formatDate(investment.startDate),
                          variant: FSStatusBadgeVariant.neutral,
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FSSpacing.sm),
              IconButton(
                tooltip: I18n.t(context, 'label.delete'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(40),
                  backgroundColor: FSColors.alpha(FSColors.danger, 0.10),
                  foregroundColor: FSColors.danger,
                  side: BorderSide(
                    color: FSColors.alpha(FSColors.danger, 0.18),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FSRadius.md),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 320;
              final width =
                  twoColumns
                      ? (constraints.maxWidth - FSSpacing.sm) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: FSSpacing.sm,
                runSpacing: FSSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _InvestmentValueTile(
                      label: I18n.t(context, 'invest.amount'),
                      value: money(investment.principal),
                      icon: Icons.savings_outlined,
                      intent: FSIntent.primary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _InvestmentValueTile(
                      label: I18n.t(context, 'invest.estimatedValue'),
                      value: money(value),
                      icon: Icons.stacked_line_chart_rounded,
                      intent: FSIntent.success,
                    ),
                  ),
                  if (investment.totalContrib > 0)
                    SizedBox(
                      width: width,
                      child: _InvestmentValueTile(
                        label: 'Contributions',
                        value: money(investment.totalContrib),
                        icon: Icons.add_card_outlined,
                        intent: FSIntent.info,
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _InvestmentValueTile(
                      label: 'Gain',
                      value: money(gain),
                      icon:
                          gain >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                      intent: gainIntent,
                      valueColor: gainColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvestmentValueTile extends StatelessWidget {
  const _InvestmentValueTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.intent,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final FSIntent intent;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(FSRadius.md),
            ),
            child: Icon(icon, size: 18, color: FSColors.intent(intent)),
          ),
          const SizedBox(width: FSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FSColors.mutedText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
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
}
