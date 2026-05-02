import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../widgets/new_transaction_dialog.dart';
import '../widgets/quick_create_dialogs.dart';

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({super.key, required this.account});
  final Account account;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late final DataService _data;
  late final int _accountId;
  late final RefreshBus _refreshBus;
  int _accountsTick = 0;
  int _transactionsTick = 0;

  Account? _account;
  bool _loading = true;
  bool _processingQuickAction = false;
  bool _accountBusy = false;
  String? _error;
  List<TransactionItem> _txs = [];

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _accountsTick = _refreshBus.accounts;
    _transactionsTick = _refreshBus.transactions;
    _refreshBus.addListener(_handleRefresh);
    _accountId = widget.account.id;
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _account = widget.account;
    _load();
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
    if (shouldRefresh) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await _data.getAccounts();
      final txsAll = await _data.getTransactions();
      final Account acc = accounts.firstWhere(
        (a) => a.id == _accountId,
        orElse: () => _account ?? widget.account,
      );
      final List<TransactionItem> filtered =
          txsAll.where((t) => t.accountId == _accountId).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _account = acc;
        _txs = filtered;
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

  Future<void> _createTransaction() async {
    if (_processingQuickAction) return;
    setState(() => _processingQuickAction = true);
    try {
      final result = await showNewTransactionDialog(context, _data);
      if (result == true && mounted) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(I18n.tr(context, 'tx.added'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingQuickAction = false);
      }
    }
  }

  Future<void> _createRecurringPayment() async {
    if (_processingQuickAction) return;
    setState(() => _processingQuickAction = true);
    try {
      final created = await showQuickNewPaymentDialog(context);
      if (created == true && mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create recurring payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingQuickAction = false);
      }
    }
  }

  Future<void> _editAccount() async {
    final acc = _account ?? widget.account;
    final nameCtrl = TextEditingController(text: acc.name);
    final balanceCtrl = TextEditingController(
      text: acc.editableBalance.toStringAsFixed(2),
    );
    final bankCtrl = TextEditingController(text: acc.bankName ?? '');
    final numberCtrl = TextEditingController(text: acc.accountNumber ?? '');
    const types = ['Checking', 'Savings', 'Business', 'Investment', 'Credit'];
    String type = acc.type ?? 'Checking';
    bool isActive = acc.isActive;

    final updated = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: Text(I18n.t(context, 'accounts.edit')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: I18n.t(context, 'accounts.name'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: type,
                          onChanged:
                              (value) =>
                                  setStateDialog(() => type = value ?? type),
                          items:
                              types
                                  .map(
                                    (t) => DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(
                                        I18n.t(
                                          context,
                                          'accounts.type.${t.toLowerCase()}',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          decoration: InputDecoration(
                            labelText: I18n.t(context, 'accounts.type'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: balanceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: I18n.t(context, 'kpi.totalBalance'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: bankCtrl,
                          decoration: InputDecoration(
                            labelText: I18n.t(
                              context,
                              'accounts.bankNameOptional',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: numberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: I18n.t(
                              context,
                              'accounts.accountNumberOptional',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: isActive,
                          onChanged:
                              (value) => setStateDialog(() => isActive = value),
                          title: Text(I18n.t(context, 'accounts.active')),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: Text(I18n.t(context, 'label.cancel')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await _data.updateAccount(acc.id, {
                            'name': nameCtrl.text.trim(),
                            'type': type,
                            'balance':
                                double.tryParse(balanceCtrl.text) ??
                                acc.editableBalance,
                            'bank_name':
                                bankCtrl.text.trim().isEmpty
                                    ? null
                                    : bankCtrl.text.trim(),
                            'account_number':
                                numberCtrl.text.trim().isEmpty
                                    ? null
                                    : numberCtrl.text.trim(),
                            'is_active': isActive,
                          });
                          if (context.mounted) Navigator.pop(dialogCtx, true);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update account: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(I18n.t(context, 'label.save')),
                    ),
                  ],
                ),
          ),
    );

    if (updated == true && mounted) {
      context.read<RefreshBus>().notifyAccounts();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.t(context, 'accounts.details.updateSuccess')),
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_accountBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: Text(I18n.t(context, 'accounts.details.deleteTitle')),
            content: Text(I18n.t(context, 'accounts.details.deleteConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(I18n.t(context, 'accounts.details.delete')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _accountBusy = true);
    try {
      await _data.deleteAccount(_accountId);
      if (!mounted) return;
      context.read<RefreshBus>().notifyAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'accounts.details.deleted'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _accountBusy = false);
      }
    }
  }

  Map<String, List<TransactionItem>> _groupTransactions() {
    final map = <String, List<TransactionItem>>{};
    for (final tx in _txs) {
      final key = formatDate(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final account = _account ?? widget.account;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final heroCardColor = isDark ? colorScheme.surface : Colors.blue.shade50;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    double inflow30 = 0;
    double outflow30 = 0;
    int count30 = 0;
    for (final tx in _txs) {
      if (tx.date.isBefore(cutoff)) continue;
      count30++;
      if (tx.amount >= 0) {
        inflow30 += tx.amount;
      } else {
        outflow30 += tx.amount.abs();
      }
    }
    final net30 = inflow30 - outflow30;
    final avgTicket =
        _txs.isEmpty
            ? 0
            : _txs.fold<double>(0, (sum, tx) => sum + tx.amount.abs()) /
                _txs.length;
    final displayBalance = account.displayBalance;
    final isInvestmentAccount = account.isInvestment;
    String maskAccountNumber(String? value) {
      if (value == null || value.trim().isEmpty) return '--';
      final trimmed = value.trim();
      if (trimmed.length <= 4) return trimmed;
      final suffix = trimmed.substring(trimmed.length - 4);
      return '****$suffix';
    }

    Widget metricTile({
      required IconData icon,
      required String label,
      required String value,
      Color? valueColor,
    }) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: valueColor ?? colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? theme.textTheme.titleMedium?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget infoRow({
      required IconData icon,
      required String label,
      required String value,
      Color? valueColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final statusLabel =
        account.isActive
            ? I18n.t(context, 'label.active')
            : I18n.t(context, 'label.inactive');
    final statusColor =
        account.isActive ? const Color(0xFF16A34A) : colorScheme.error;

    final Map<String, List<TransactionItem>> groupedTx = _groupTransactions();

    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Card(
              color: heroCardColor,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.t(
                        context,
                        isInvestmentAccount
                            ? 'accounts.details.estimatedValue'
                            : 'label.currentBalance',
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(displayBalance),
                        maxLines: 1,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              displayBalance >= 0
                                  ? const Color(0xFF16A34A)
                                  : colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if ((account.type ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: ShapeDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              account.type!,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          statusLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _accountBusy ? null : _editAccount,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(I18n.t(context, 'accounts.details.edit')),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _accountBusy ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(I18n.t(context, 'accounts.details.delete')),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              I18n.t(context, 'accounts.details.quickActions'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _processingQuickAction ? null : _createTransaction,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    I18n.t(context, 'accounts.details.newTransaction'),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _processingQuickAction ? null : _createRecurringPayment,
                  icon: const Icon(Icons.autorenew),
                  label: Text(I18n.t(context, 'accounts.details.recurring')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              I18n.t(context, 'accounts.details.metrics'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int cols = 1;
                if (width >= 900) {
                  cols = 3;
                } else if (width >= 600) {
                  cols = 2;
                }
                const spacing = 12.0;
                final double tileWidth =
                    cols == 1 ? width : (width - (cols - 1) * spacing) / cols;
                final tiles = [
                  metricTile(
                    icon: Icons.swap_vert,
                    label: I18n.t(context, 'accounts.details.count30'),
                    value: count30.toString(),
                  ),
                  metricTile(
                    icon: Icons.call_received,
                    label: I18n.t(context, 'accounts.details.inflow30'),
                    value: money(inflow30),
                    valueColor: const Color(0xFF16A34A),
                  ),
                  metricTile(
                    icon: Icons.call_made,
                    label: I18n.t(context, 'accounts.details.outflow30'),
                    value: money(outflow30),
                    valueColor: colorScheme.error,
                  ),
                  metricTile(
                    icon: Icons.trending_up,
                    label: I18n.t(context, 'accounts.details.net30'),
                    value: money(net30),
                    valueColor:
                        net30 >= 0
                            ? const Color(0xFF16A34A)
                            : colorScheme.error,
                  ),
                  metricTile(
                    icon: Icons.payments_outlined,
                    label: I18n.t(context, 'accounts.details.avgTicket'),
                    value: money(avgTicket),
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: tileWidth, child: tile),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              I18n.t(context, 'accounts.details.accountInfo'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    infoRow(
                      icon: Icons.account_balance,
                      label: I18n.t(context, 'accounts.details.bank'),
                      value:
                          (account.bankName ?? '').isEmpty
                              ? I18n.t(context, 'accounts.details.notSet')
                              : account.bankName!,
                    ),
                    const Divider(),
                    infoRow(
                      icon: Icons.confirmation_number_outlined,
                      label: I18n.t(context, 'accounts.details.accountNumber'),
                      value: maskAccountNumber(account.accountNumber),
                    ),
                    const Divider(),
                    infoRow(
                      icon: Icons.style_outlined,
                      label: I18n.t(context, 'accounts.details.type'),
                      value:
                          (account.type ?? '').isEmpty
                              ? I18n.t(context, 'accounts.details.notSet')
                              : account.type!,
                    ),
                    const Divider(),
                    infoRow(
                      icon: Icons.verified_user_outlined,
                      label: I18n.t(context, 'accounts.details.status'),
                      value: statusLabel,
                      valueColor: statusColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              I18n.t(context, 'accounts.details.transactions'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(context, 'accounts.details.error'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _load,
                          child: Text(
                            I18n.t(context, 'accounts.details.retry'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_txs.isEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    I18n.t(context, 'accounts.details.noTransactions'),
                  ),
                ),
              )
            else
              ...groupedTx.entries.expand((entry) sync* {
                yield Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 12),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
                for (final tx in entry.value) {
                  yield _TxRow(item: tx);
                }
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.item});
  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final isTransfer = item.isTransfer;
    final isIncome = !isTransfer && item.amount >= 0;
    final amountStr = signedMoney(item.amount);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color bg =
        isDark
            ? (isTransfer
                ? const Color(0xFF1D2A44)
                : (isIncome
                    ? const Color(0xFF103521)
                    : const Color(0xFF3A1C1C)))
            : (isTransfer
                ? Colors.blue.shade50
                : (isIncome ? Colors.green.shade50 : Colors.red.shade50));

    return Card(
      color: bg,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    item.description.isEmpty
                        ? '(No description)'
                        : item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(item.date)}'
                    '${(item.effectiveCategory ?? '').isNotEmpty ? ' - ${item.effectiveCategory}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountStr,
              style: TextStyle(
                color:
                    isTransfer
                        ? Colors.blue
                        : (isIncome
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.error),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
