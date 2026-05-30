import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../ui/finsight_ui.dart';
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
      FSIntent accent = FSIntent.primary,
    }) {
      return FSMetricCard(
        title: label,
        value: value,
        icon: icon,
        accent: accent,
        accentColor: valueColor,
      );
    }

    Widget infoRow({
      required IconData icon,
      required String label,
      required String value,
      Color? valueColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: FSSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: FSColors.intentContainer(context, FSIntent.primary),
                borderRadius: BorderRadius.circular(FSRadius.md),
                border: Border.all(
                  color: FSColors.intentBorder(context, FSIntent.primary),
                ),
              ),
              child: Icon(icon, size: 19, color: FSColors.primary),
            ),
            const SizedBox(width: FSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FSColors.mutedText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FSSpacing.xs),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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
    final statusColor = account.isActive ? FSColors.success : colorScheme.error;
    final statusVariant =
        account.isActive
            ? FSStatusBadgeVariant.active
            : FSStatusBadgeVariant.danger;

    final Map<String, List<TransactionItem>> groupedTx = _groupTransactions();

    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        title: Text(account.name),
        backgroundColor: FSColors.background(context),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FSSpacing.lg,
            FSSpacing.lg,
            FSSpacing.lg,
            FSSpacing.xxl,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FSCard(
              variant: FSCardVariant.elevated,
              padding: const EdgeInsets.all(FSSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: FSColors.intentContainer(
                            context,
                            isInvestmentAccount
                                ? FSIntent.info
                                : FSIntent.primary,
                          ),
                          borderRadius: BorderRadius.circular(FSRadius.lg),
                          border: Border.all(
                            color: FSColors.intentBorder(
                              context,
                              isInvestmentAccount
                                  ? FSIntent.info
                                  : FSIntent.primary,
                            ),
                          ),
                        ),
                        child: Icon(
                          isInvestmentAccount
                              ? Icons.trending_up
                              : Icons.account_balance_wallet_outlined,
                          color:
                              isInvestmentAccount
                                  ? FSColors.info
                                  : FSColors.primary,
                        ),
                      ),
                      const Spacer(),
                      FSStatusBadge(
                        label: statusLabel,
                        variant: statusVariant,
                        icon:
                            account.isActive
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: FSSpacing.lg),
                  Text(
                    I18n.t(
                      context,
                      isInvestmentAccount
                          ? 'accounts.details.estimatedValue'
                          : 'label.currentBalance',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FSColors.mutedText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FSSpacing.sm),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(displayBalance),
                      maxLines: 1,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color:
                            displayBalance >= 0
                                ? FSColors.success
                                : colorScheme.error,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: FSSpacing.md),
                  Wrap(
                    spacing: FSSpacing.sm,
                    runSpacing: FSSpacing.sm,
                    children: [
                      if ((account.type ?? '').isNotEmpty)
                        FSStatusBadge(
                          label: account.type!,
                          variant: FSStatusBadgeVariant.info,
                        ),
                      if ((account.bankName ?? '').isNotEmpty)
                        FSStatusBadge(
                          label: account.bankName!,
                          variant: FSStatusBadgeVariant.neutral,
                          icon: Icons.account_balance_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: FSSpacing.lg),
            Wrap(
              spacing: FSSpacing.md,
              runSpacing: FSSpacing.sm,
              children: [
                FSButton(
                  label: I18n.t(context, 'accounts.details.edit'),
                  onPressed: _accountBusy ? null : _editAccount,
                  icon: Icons.edit_outlined,
                  variant: FSButtonVariant.outline,
                ),
                FSButton(
                  label: I18n.t(context, 'accounts.details.delete'),
                  onPressed: _accountBusy ? null : _deleteAccount,
                  icon: Icons.delete_outline,
                  variant: FSButtonVariant.danger,
                ),
              ],
            ),
            const SizedBox(height: FSSpacing.lg),
            FSCard(
              variant: FSCardVariant.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t(context, 'accounts.details.quickActions'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: FSSpacing.md),
                  Wrap(
                    spacing: FSSpacing.md,
                    runSpacing: FSSpacing.sm,
                    children: [
                      FSButton(
                        label: I18n.t(
                          context,
                          'accounts.details.newTransaction',
                        ),
                        onPressed:
                            _processingQuickAction ? null : _createTransaction,
                        icon: Icons.add_circle_outline,
                        variant: FSButtonVariant.primary,
                      ),
                      FSButton(
                        label: I18n.t(context, 'accounts.details.recurring'),
                        onPressed:
                            _processingQuickAction
                                ? null
                                : _createRecurringPayment,
                        icon: Icons.autorenew,
                        variant: FSButtonVariant.outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: FSSpacing.xl),
            Text(
              I18n.t(context, 'accounts.details.metrics'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FSSpacing.md),
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
                    accent: FSIntent.info,
                  ),
                  metricTile(
                    icon: Icons.call_received,
                    label: I18n.t(context, 'accounts.details.inflow30'),
                    value: money(inflow30),
                    valueColor: FSColors.success,
                    accent: FSIntent.success,
                  ),
                  metricTile(
                    icon: Icons.call_made,
                    label: I18n.t(context, 'accounts.details.outflow30'),
                    value: money(outflow30),
                    valueColor: colorScheme.error,
                    accent: FSIntent.danger,
                  ),
                  metricTile(
                    icon: Icons.trending_up,
                    label: I18n.t(context, 'accounts.details.net30'),
                    value: money(net30),
                    valueColor:
                        net30 >= 0 ? FSColors.success : colorScheme.error,
                    accent: net30 >= 0 ? FSIntent.success : FSIntent.danger,
                  ),
                  metricTile(
                    icon: Icons.payments_outlined,
                    label: I18n.t(context, 'accounts.details.avgTicket'),
                    value: money(avgTicket),
                    accent: FSIntent.neutral,
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
            const SizedBox(height: FSSpacing.xl),
            Text(
              I18n.t(context, 'accounts.details.accountInfo'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FSSpacing.md),
            FSCard(
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
                  Divider(color: FSColors.border(context)),
                  infoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: I18n.t(context, 'accounts.details.accountNumber'),
                    value: maskAccountNumber(account.accountNumber),
                  ),
                  Divider(color: FSColors.border(context)),
                  infoRow(
                    icon: Icons.style_outlined,
                    label: I18n.t(context, 'accounts.details.type'),
                    value:
                        (account.type ?? '').isEmpty
                            ? I18n.t(context, 'accounts.details.notSet')
                            : account.type!,
                  ),
                  Divider(color: FSColors.border(context)),
                  infoRow(
                    icon: Icons.verified_user_outlined,
                    label: I18n.t(context, 'accounts.details.status'),
                    value: statusLabel,
                    valueColor: statusColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: FSSpacing.xl),
            Text(
              I18n.t(context, 'accounts.details.transactions'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: FSSpacing.md),
            if (_loading)
              const FSCard(
                variant: FSCardVariant.subtle,
                child: FSLoadingState(),
              )
            else if (_error != null)
              FSCard(
                variant: FSCardVariant.subtle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: FSColors.intentContainer(
                              context,
                              FSIntent.danger,
                            ),
                            borderRadius: BorderRadius.circular(FSRadius.md),
                            border: Border.all(
                              color: FSColors.intentBorder(
                                context,
                                FSIntent.danger,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: FSSpacing.md),
                        Expanded(
                          child: Text(
                            I18n.t(context, 'accounts.details.error'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FSSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FSButton(
                        label: I18n.t(context, 'accounts.details.retry'),
                        onPressed: _load,
                        icon: Icons.refresh,
                        variant: FSButtonVariant.outline,
                        size: FSButtonSize.sm,
                      ),
                    ),
                  ],
                ),
              )
            else if (_txs.isEmpty)
              FSCard(
                variant: FSCardVariant.subtle,
                child: FSEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: I18n.t(context, 'accounts.details.noTransactions'),
                ),
              )
            else
              ...groupedTx.entries.expand((entry) sync* {
                yield Padding(
                  padding: const EdgeInsets.only(
                    bottom: FSSpacing.sm,
                    top: FSSpacing.lg,
                  ),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: FSColors.mutedText(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
                for (final tx in entry.value) {
                  yield _TxRow(item: tx);
                }
              }),
            const SizedBox(height: FSSpacing.xl),
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
    final intent =
        isTransfer
            ? FSIntent.info
            : (isIncome ? FSIntent.success : FSIntent.danger);
    final amountColor = FSColors.intent(intent);

    return FSCard(
      variant: FSCardVariant.subtle,
      padding: const EdgeInsets.all(FSSpacing.md),
      margin: const EdgeInsets.only(bottom: FSSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(color: FSColors.intentBorder(context, intent)),
            ),
            child: Icon(
              isTransfer
                  ? Icons.swap_horiz
                  : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
              color: amountColor,
              size: 19,
            ),
          ),
          const SizedBox(width: FSSpacing.md),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: FSSpacing.xs),
                Text(
                  '${formatDate(item.date)}'
                  '${(item.effectiveCategory ?? '').isNotEmpty ? ' - ${item.effectiveCategory}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FSColors.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FSSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amountStr,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
