import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
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

  @override
  void initState() {
    super.initState();
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
                  if (v == null)
                    d = 0.0;
                  else if (v is num)
                    d = v.toDouble();
                  else
                    d = double.tryParse('$v'.replaceAll(',', '')) ?? 0.0;
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
                          if (picked != null)
                            dateCtrl.text = formatDate(picked);
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
    if (ok == true && mounted) await _load();
  }

  Future<void> _delete(Investment inv) async {
    try {
      // server ids are ints, we stored as string; try parse
      final id = int.tryParse(inv.id) ?? 0;
      if (id != 0) {
        final ds = _data ?? _svc();
        await ds.deleteInvestment(id);
      }
      if (mounted) await _load();
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
        appBar: AppBar(title: Text(I18n.t(context, 'title.investments'))),
        body: const ProBlock(feature: 'Investments'),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t(context, 'title.investments'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child:
            _items.isEmpty
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(I18n.t(context, 'invest.none')),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _addDialog,
                            icon: const Icon(Icons.add),
                            label: Text(I18n.t(context, 'invest.add')),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                  if (i == 0) {
                    final totals = _computeTotals();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _addDialog,
                            icon: const Icon(Icons.add),
                            label: Text(I18n.t(context, 'invest.add')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _kpiGrid(context, totals),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  final it = _items[i - 1];
                  // Estimated value should include compounded contributions when available from server.
                  // Fallback: add raw contributions (non‑compounded) if server didn't send estimated_value.
                  final value =
                      (it.estimatedValue ?? _valueToday(it)) +
                      (it.estimatedValue == null ? it.totalContrib : 0);
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Card(
                    color: isDark ? cs.surface : Colors.blue.shade50,
                    elevation: 6,
                    child: InkWell(
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Start: ' +
                                        formatDate(it.startDate) +
                                        ' • Rate: ' +
                                        it.annualRate.toStringAsFixed(2) +
                                        '%',
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _kv(
                                          context,
                                          I18n.t(context, 'invest.amount'),
                                          money(it.principal),
                                        ),
                                      ),
                                      Expanded(
                                        child: _kv(
                                          context,
                                          I18n.t(
                                            context,
                                            'invest.estimatedValue',
                                          ),
                                          money(value),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: I18n.t(context, 'label.delete'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _delete(it),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
      ),
      _kpiCard(
        context,
        Icons.add_card_outlined,
        'Total Contributions',
        money(t['contrib'] ?? 0),
      ),
      _kpiCard(
        context,
        Icons.stacked_line_chart,
        'Total Value',
        money(t['value'] ?? 0),
      ),
      _kpiCard(
        context,
        Icons.trending_up,
        'Total Revenue',
        money(t['revenue'] ?? 0),
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        const itemH = 110.0;
        const spacing = 12.0;
        final w = c.maxWidth;
        final itemW = (w - spacing) / 2; // two columns
        final aspect = itemW / itemH;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspect,
          children: tiles,
        );
      },
    );
  }

  Widget _kpiCard(
    BuildContext context,
    IconData ic,
    String title,
    String value,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color:
          isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(ic, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
