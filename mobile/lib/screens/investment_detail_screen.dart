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

class InvestmentDetailScreen extends StatefulWidget {
  const InvestmentDetailScreen({super.key, required this.investmentId, required this.name});
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
      _cons = (res['contributions'] as List<dynamic>).cast<Map<String, dynamic>>();
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
      builder: (dctx) => AlertDialog(
        title: Text(I18n.t(context, 'invest.addContribution')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: I18n.t(context, 'invest.amount'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('${I18n.t(context, 'invoices.date')}: ${formatDate(date)}')),
              IconButton(onPressed: () async { final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (p != null) { date = p; (dctx as Element).markNeedsBuild(); } }, icon: const Icon(Icons.calendar_today_outlined))
            ])
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(I18n.t(context, 'label.cancel'))),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(I18n.t(context, 'label.save'))),
        ],
      ),
    );
    if (ok == true) {
      try {
        final amt = double.tryParse(amtCtrl.text.replaceAll(',', '')) ?? 0;
        if (amt <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'invest.validationAmount'))));
          return;
        }
        await _data.addInvestmentContribution(investmentId: widget.investmentId, amount: amt, date: date.toIso8601String().substring(0,10));
        if (mounted) {
          context.read<RefreshBus>().notifyInvestments();
        }
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'invest.contributionAdded'))));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${I18n.tr(context, 'invest.addFailed')}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return const Scaffold(body: ProBlock(feature: 'Investments'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Add contribution',
            icon: const Icon(Icons.add),
            onPressed: _addContribution,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addContribution, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Failed to load investment', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : (_inv == null)
                  ? const Center(child: Text('Investment not found'))
                  : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summary(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('Contributions', style: Theme.of(context).textTheme.titleMedium)),
                    TextButton.icon(onPressed: _addContribution, icon: const Icon(Icons.add), label: const Text('Add')),
                  ],
                ),
                const SizedBox(height: 8),
                if (_cons.isEmpty)
                  Card(
                    color: cs.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No contributions yet'),
                          const SizedBox(height: 8),
                          FilledButton.icon(onPressed: _addContribution, icon: const Icon(Icons.add), label: const Text('Add contribution')),
                        ],
                      ),
                    ),
                  )
                else
                  ..._cons.map((c) => Card(
                        color: cs.surface,
                        child: ListTile(
                          leading: const Icon(Icons.savings_outlined),
                          title: Text(money(_toDouble(c['amount']))),
                          subtitle: Text(formatYmd(c['date'] as String)),
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _summary() {
    final inv = _inv!;
    final principal = _toDouble(inv['principal']);
    final rate = _toDouble(inv['annual_rate']);
    final start = DateTime.parse(inv['start_date'] as String);
    final daysActive = DateTime.now().difference(DateTime(start.year, start.month, start.day)).inDays;
    final totalContrib = principal + _cons.fold<double>(0, (s, c) => s + _toDouble(c['amount']));
    final current = _valueToday();
    final revenue = current - totalContrib;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _kv('Initial Amount', money(principal))),
            Expanded(child: _kv('Rate (APR)', rate.toStringAsFixed(2) + '%')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _kv('Days Active', daysActive.toString())),
            Expanded(child: _kv('Total Contributed', money(totalContrib))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _kv('Current Value', money(current))),
            Expanded(child: _kv('Revenue', money(revenue))),
          ]),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}
