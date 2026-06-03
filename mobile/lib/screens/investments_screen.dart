import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../liquid_glass/liquid_glass.dart';
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

  Future<void> _editDialog(Investment inv) async {
    final id = int.tryParse(inv.id) ?? 0;
    if (id == 0) return;

    final nameCtrl = TextEditingController(text: inv.name);
    final amountCtrl = TextEditingController(
      text: inv.principal.toStringAsFixed(2),
    );
    final rateCtrl = TextEditingController(
      text: inv.annualRate.toStringAsFixed(2),
    );
    final dateCtrl = TextEditingController(text: formatDate(inv.startDate));
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: Text(
              '${I18n.t(context, 'label.edit')} ${I18n.t(context, 'title.investments')}',
            ),
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
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: inv.startDate,
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
                  final dialogNavigator = Navigator.of(dialogCtx);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  try {
                    final amt =
                        double.tryParse(amountCtrl.text.replaceAll(',', '')) ??
                        0;
                    final rate =
                        double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? 0;
                    final start =
                        parseDdMmYyyy(dateCtrl.text.trim()) ?? inv.startDate;
                    final name =
                        nameCtrl.text.trim().isEmpty
                            ? I18n.tr(context, 'invest.defaultName')
                            : nameCtrl.text.trim();
                    if (amt <= 0) {
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text(
                            I18n.tr(context, 'invest.validationAmount'),
                          ),
                        ),
                      );
                      return;
                    }
                    final ds = _data ?? _svc();
                    await ds.updateInvestment(
                      id: id,
                      name: name,
                      principal: amt,
                      annualRate: rate,
                      startDate: start.toIso8601String().substring(0, 10),
                    );
                    dialogNavigator.pop(true);
                  } catch (e) {
                    messenger?.showSnackBar(
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
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
          children: [
            LGPageHeader(
              title: I18n.t(context, 'title.investments'),
              leading: const _InvestmentsHeaderIcon(),
            ),
            const ProBlock(feature: 'Investments'),
          ],
        ),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: LGLoadingState()));
    }

    final totals = _computeTotals();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
          children: [
            LGPageHeader(
              title: I18n.t(context, 'title.investments'),
              leading: const _InvestmentsHeaderIcon(),
              action: LGButton(
                label: I18n.t(context, 'invest.add'),
                icon: Icons.add,
                onPressed: _addDialog,
              ),
            ),
            const SizedBox(height: LGSpacing.sm),
            if (_items.isNotEmpty) ...[
              _kpiGrid(context, totals),
              const SizedBox(height: LGSpacing.md),
              for (var i = 0; i < _items.length; i++) ...[
                _investmentCard(context, _items[i]),
                if (i != _items.length - 1)
                  const SizedBox(height: LGSpacing.md),
              ],
            ] else
              LGEmptyState(
                icon: Icons.trending_up_rounded,
                title: I18n.t(context, 'invest.none'),
                message: I18n.t(context, 'title.investments'),
                action: LGEmptyAction(
                  label: I18n.t(context, 'invest.add'),
                  icon: Icons.add,
                  onPressed: _addDialog,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        child: const Icon(Icons.add),
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
    final tiles = <Widget>[
      _kpiCard(
        context,
        Icons.account_balance,
        'Total Invested',
        money((t['principal'] ?? 0) + (t['contrib'] ?? 0)),
        Theme.of(context).colorScheme.primary,
      ),
      _kpiCard(
        context,
        Icons.add_card_outlined,
        'Total Contributions',
        money(t['contrib'] ?? 0),
        LGColors.info,
      ),
      _kpiCard(
        context,
        Icons.stacked_line_chart,
        'Total Value',
        money(t['value'] ?? 0),
        LGColors.success,
      ),
      _kpiCard(
        context,
        (t['revenue'] ?? 0) >= 0 ? Icons.trending_up : Icons.trending_down,
        'Total Revenue',
        money(t['revenue'] ?? 0),
        (t['revenue'] ?? 0) >= 0 ? LGColors.success : LGColors.danger,
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        const spacing = 12.0;
        final w = c.maxWidth;
        final cols = w < 360 ? 1 : 2;
        final itemW = (w - ((cols - 1) * spacing)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: itemW,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 132),
                  child: tile,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(
    BuildContext context,
    IconData ic,
    String title,
    String value,
    Color accentColor,
  ) {
    return LGMetricCard(
      title: title,
      value: value,
      icon: ic,
      accentColor: accentColor,
    );
  }

  Widget _investmentCard(BuildContext context, Investment it) {
    // Estimated value should include compounded contributions when available from server.
    // Fallback: add raw contributions (non-compounded) if server didn't send estimated_value.
    final value =
        (it.estimatedValue ?? _valueToday(it)) +
        (it.estimatedValue == null ? it.totalContrib : 0);
    final gain = value - (it.principal + it.totalContrib);
    final gainColor = gain >= 0 ? LGColors.success : LGColors.danger;
    final primary = Theme.of(context).colorScheme.primary;

    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(
                    alpha: LGColors.isDark(context) ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(LGRadius.lg),
                  border: Border.all(color: primary.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.trending_up_rounded, color: primary),
              ),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                          context,
                          Icons.calendar_today_outlined,
                          formatDate(it.startDate),
                        ),
                        _metaPill(
                          context,
                          Icons.percent_rounded,
                          '${it.annualRate.toStringAsFixed(2)}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconActionButton(
                    tooltip: I18n.t(context, 'label.edit'),
                    icon: Icons.edit_outlined,
                    color: primary,
                    onPressed: () => _editDialog(it),
                  ),
                  const SizedBox(width: LGSpacing.xs),
                  _IconActionButton(
                    tooltip: I18n.t(context, 'label.delete'),
                    icon: Icons.delete_outline,
                    color: LGColors.danger,
                    onPressed: () => _delete(it),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 360;
              final gap = twoColumns ? LGSpacing.md : LGSpacing.sm;
              final itemWidth =
                  twoColumns
                      ? (constraints.maxWidth - gap) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: LGSpacing.sm,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _kv(
                      context,
                      I18n.t(context, 'invest.amount'),
                      money(it.principal),
                      Icons.account_balance_wallet_outlined,
                      primary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _kv(
                      context,
                      I18n.t(context, 'invest.estimatedValue'),
                      money(value),
                      Icons.stacked_line_chart_rounded,
                      LGColors.success,
                    ),
                  ),
                  if (it.totalContrib > 0)
                    SizedBox(
                      width: itemWidth,
                      child: _kv(
                        context,
                        'Total Contributions',
                        money(it.totalContrib),
                        Icons.add_card_outlined,
                        LGColors.info,
                      ),
                    ),
                  SizedBox(
                    width: itemWidth,
                    child: _kv(
                      context,
                      'Total Revenue',
                      money(gain),
                      gain >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      gainColor,
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

  Widget _metaPill(BuildContext context, IconData icon, String label) {
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

  Widget _kv(
    BuildContext context,
    String k,
    String v,
    IconData icon,
    Color accentColor, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(LGSpacing.md),
      decoration: BoxDecoration(
        color: LGColors.surfaceTinted(context),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(
          color: LGColors.textSecondary(context).withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
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
}

class _InvestmentsHeaderIcon extends StatelessWidget {
  const _InvestmentsHeaderIcon();

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
      child: Icon(Icons.trending_up_rounded, color: color, size: 25),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.md),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}
