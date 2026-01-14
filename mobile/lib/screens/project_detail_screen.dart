import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../utils/format.dart';
import '../widgets/pro_widgets.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final DataService _data;
  bool _loading = true;
  String? _error;
  List<TransactionItem> _transactions = const [];

  @override
  void initState() {
    super.initState();
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _data.getTransactions();
      final filtered =
          all.where((tx) {
              if (tx.projectId != null) {
                return tx.projectId == widget.project.id;
              }
              final name = tx.projectName;
              return name != null &&
                  name.isNotEmpty &&
                  name == widget.project.name;
            }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _transactions = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isProOrExempt) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.project.name)),
        body: const ProBlock(feature: 'Projects'),
      );
    }
    final listChildren = <Widget>[
      _summaryCard(context),
      const SizedBox(height: 16),
      _transactionsSection(context),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            tooltip: I18n.t(context, 'projects.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: listChildren,
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final project = widget.project;
    final budget = project.budget;
    final spent = project.spent;
    final remaining = budget - spent;
    final progress =
        budget == 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).toStringAsFixed(0);
    final onBudget = remaining >= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark
            ? (onBudget ? const Color(0xFF103521) : const Color(0xFF3A1C1C))
            : (onBudget ? Colors.green.shade50 : Colors.red.shade50);
    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if ((project.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          project.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                _statusChip(context, project.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _kv(
                    context,
                    I18n.t(context, 'projects.budget'),
                    money(budget),
                    valueStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: _kv(
                    context,
                    I18n.t(context, 'home.spent'),
                    money(spent),
                    valueStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(I18n.t(context, 'projects.progress')),
                const Spacer(),
                Text('$percent%'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (project.startDate != null && project.endDate != null)
              Text(
                '${I18n.t(context, 'projects.period')}: ${formatYmd(project.startDate!)} ${I18n.t(context, 'projects.to')} ${formatYmd(project.endDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              '${I18n.t(context, 'projects.remaining')}: ${money(remaining)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: remaining >= 0 ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsSection(BuildContext context) {
    if (_loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                I18n.t(context, 'label.failed'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(),
                child: Text(I18n.t(context, 'projects.refresh')),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.t(context, 'projects.latestTransactions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              Text(I18n.t(context, 'projects.noTransactions'))
            else
              ..._transactions
                  .take(10)
                  .map(
                    (tx) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: (tx.amount >= 0
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.1),
                        child: Icon(
                          tx.amount >= 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: tx.amount >= 0 ? Colors.green : Colors.red,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        tx.description.isNotEmpty
                            ? tx.description
                            : I18n.t(context, 'tx.description'),
                      ),
                      subtitle: Text(
                        [
                          formatDate(tx.date),
                          if ((tx.accountName ?? '').isNotEmpty)
                            tx.accountName!,
                        ].join(' | '),
                      ),
                      trailing: Text(
                        signedMoney(tx.amount),
                        style: TextStyle(
                          color: tx.amount >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String key,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.merge(valueStyle),
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final lower = status.toLowerCase();
    Color? bg;
    Color? fg;
    OutlinedBorder? shape;
    if (lower.contains('active')) {
      bg = const Color(0xFFE6F7EC);
      fg = const Color(0xFF16A34A);
    } else if (lower.contains('hold')) {
      bg = const Color(0xFFFFFAE6);
      const holdColor = Color(0xFFB45309);
      fg = holdColor;
      shape = StadiumBorder(
        side: BorderSide(color: holdColor.withValues(alpha: 0.5)),
      );
    } else {
      bg = const Color(0xFFEAF2FF);
      fg = const Color(0xFF2563EB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: bg,
        shape: shape ?? const StadiumBorder(),
      ),
      child: Text(
        lower,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
