import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../liquid_glass/liquid_glass.dart';
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
    }) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: LGMetricCard(
          title: label,
          value: value,
          icon: icon,
          accentColor: valueColor ?? colorScheme.primary,
          style: LGMetricCardStyle.solid,
        ),
      );
    }

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.only(left: LGSpacing.xs),
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            color: LGColors.textPrimary(context),
            fontWeight: FontWeight.w900,
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
        padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LGColors.intentContainer(context, LGIntent.primary),
                borderRadius: BorderRadius.circular(LGRadius.md),
                border: Border.all(
                  color: LGColors.intentStroke(context, LGIntent.primary),
                ),
              ),
              child: Icon(icon, size: 19, color: colorScheme.primary),
            ),
            const SizedBox(width: LGSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LGColors.textSecondary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? LGColors.textPrimary(context),
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
    final accountType = account.type ?? '';
    final subtitleParts = <String>[
      if (accountType.isNotEmpty) accountType,
      if ((account.bankName ?? '').isNotEmpty) account.bankName!,
    ];
    final headerSubtitle =
        subtitleParts.isEmpty ? null : subtitleParts.join(' - ');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            LGPageHeader(
              title: account.name,
              subtitle: headerSubtitle,
              leading: const _AccountDetailBackButton(),
              action: _AccountDetailHeaderIcon(
                isInvestment: isInvestmentAccount,
                balance: displayBalance,
              ),
            ),
            LGSolidCard(
              variant: LGCardVariant.hero,
              tinted: true,
              child: Padding(
                padding: EdgeInsets.zero,
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
                    const SizedBox(height: LGSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(displayBalance),
                        maxLines: 1,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          color:
                              displayBalance >= 0
                                  ? const Color(0xFF16A34A)
                                  : colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    Wrap(
                      spacing: LGSpacing.sm,
                      runSpacing: LGSpacing.sm,
                      children: [
                        if (accountType.isNotEmpty)
                          LGStatusBadge(
                            label: accountType,
                            variant:
                                isInvestmentAccount
                                    ? LGStatusBadgeVariant.info
                                    : LGStatusBadgeVariant.neutral,
                            icon:
                                isInvestmentAccount
                                    ? Icons.trending_up_rounded
                                    : Icons.account_balance_wallet_outlined,
                          ),
                        LGStatusBadge(
                          label: statusLabel,
                          variant:
                              account.isActive
                                  ? LGStatusBadgeVariant.active
                                  : LGStatusBadgeVariant.danger,
                          icon:
                              account.isActive
                                  ? Icons.check_rounded
                                  : Icons.pause_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: LGSpacing.lg),
            Wrap(
              spacing: LGSpacing.sm,
              runSpacing: LGSpacing.sm,
              children: [
                _AccountDetailCapsuleButton(
                  label: I18n.t(context, 'accounts.details.edit'),
                  icon: Icons.edit_outlined,
                  tone: _AccountDetailButtonTone.edit,
                  onPressed: _accountBusy ? null : _editAccount,
                ),
                _AccountDetailCapsuleButton(
                  label: I18n.t(context, 'accounts.details.delete'),
                  icon: Icons.delete_outline,
                  tone: _AccountDetailButtonTone.danger,
                  onPressed: _accountBusy ? null : _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: LGSpacing.xl),
            sectionTitle(I18n.t(context, 'accounts.details.quickActions')),
            const SizedBox(height: LGSpacing.md),
            Wrap(
              spacing: LGSpacing.sm,
              runSpacing: LGSpacing.sm,
              children: [
                _AccountDetailCapsuleButton(
                  label: I18n.t(context, 'accounts.details.newTransaction'),
                  icon: Icons.add_circle_outline,
                  tone: _AccountDetailButtonTone.quick,
                  onPressed: _processingQuickAction ? null : _createTransaction,
                ),
                _AccountDetailCapsuleButton(
                  label: I18n.t(context, 'accounts.details.recurring'),
                  icon: Icons.autorenew,
                  tone: _AccountDetailButtonTone.quick,
                  onPressed:
                      _processingQuickAction ? null : _createRecurringPayment,
                ),
              ],
            ),
            const SizedBox(height: LGSpacing.xl),
            sectionTitle(I18n.t(context, 'accounts.details.metrics')),
            const SizedBox(height: LGSpacing.md),
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
            const SizedBox(height: LGSpacing.xl),
            sectionTitle(I18n.t(context, 'accounts.details.accountInfo')),
            const SizedBox(height: LGSpacing.md),
            LGSolidCard(
              variant: LGCardVariant.elevated,
              child: Padding(
                padding: EdgeInsets.zero,
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
                    const Divider(height: LGSpacing.lg),
                    infoRow(
                      icon: Icons.confirmation_number_outlined,
                      label: I18n.t(context, 'accounts.details.accountNumber'),
                      value: maskAccountNumber(account.accountNumber),
                    ),
                    const Divider(height: LGSpacing.lg),
                    infoRow(
                      icon: Icons.style_outlined,
                      label: I18n.t(context, 'accounts.details.type'),
                      value:
                          (account.type ?? '').isEmpty
                              ? I18n.t(context, 'accounts.details.notSet')
                              : account.type!,
                    ),
                    const Divider(height: LGSpacing.lg),
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
            const SizedBox(height: LGSpacing.xl),
            sectionTitle(I18n.t(context, 'accounts.details.transactions')),
            const SizedBox(height: LGSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: LGSpacing.lg),
                child: LGLoadingState(),
              )
            else if (_error != null)
              LGSolidCard(
                tinted: true,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(context, 'accounts.details.error'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LGSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: LGButton(
                          label: I18n.t(context, 'accounts.details.retry'),
                          icon: Icons.refresh,
                          variant: LGButtonVariant.outline,
                          onPressed: _load,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_txs.isEmpty)
              LGEmptyState(
                icon: Icons.receipt_long_outlined,
                title: I18n.t(context, 'accounts.details.transactions'),
                message: I18n.t(context, 'accounts.details.noTransactions'),
              )
            else
              ...groupedTx.entries.expand((entry) sync* {
                yield Padding(
                  padding: const EdgeInsets.only(
                    bottom: LGSpacing.xs,
                    top: LGSpacing.md,
                    left: LGSpacing.xs,
                  ),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: LGColors.textSecondary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
                for (final tx in entry.value) {
                  yield _TxRow(item: tx);
                }
              }),
            const SizedBox(height: LGSpacing.xl),
          ],
        ),
      ),
    );
  }
}

enum _AccountDetailButtonTone { edit, danger, quick }

class _AccountDetailCapsuleButton extends StatelessWidget {
  const _AccountDetailCapsuleButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _AccountDetailButtonTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = LGColors.isDark(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(LGRadius.pill);
    final colors = _buttonColors(context, isDark);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onPressed : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(
            horizontal: LGSpacing.lg,
            vertical: LGSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: radius,
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: LGColors.alpha(
                  isDark ? Colors.black : const Color(0xFF0F172A),
                  isDark ? 0.20 : 0.06,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: colors.foreground),
              const SizedBox(width: LGSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 112,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Opacity(opacity: enabled ? 1 : 0.55, child: button);
  }

  ({Color background, Color border, Color foreground}) _buttonColors(
    BuildContext context,
    bool isDark,
  ) {
    switch (tone) {
      case _AccountDetailButtonTone.edit:
        return (
          background:
              isDark
                  ? LGColors.alpha(LGColors.primaryBlue, 0.12)
                  : LGColors.surfaceSolid(context),
          border: LGColors.alpha(LGColors.primaryBlue, isDark ? 0.32 : 0.24),
          foreground: LGColors.primaryBlue,
        );
      case _AccountDetailButtonTone.danger:
        return (
          background: LGColors.alpha(LGColors.danger, isDark ? 0.16 : 0.08),
          border: LGColors.alpha(LGColors.danger, isDark ? 0.34 : 0.22),
          foreground: LGColors.danger,
        );
      case _AccountDetailButtonTone.quick:
        return (
          background:
              isDark
                  ? LGColors.alpha(LGColors.primaryBlue, 0.13)
                  : LGColors.alpha(LGColors.primaryBlue, 0.06),
          border: LGColors.alpha(LGColors.primaryBlue, isDark ? 0.30 : 0.18),
          foreground: isDark ? LGColors.electricBlue : LGColors.primaryBlue,
        );
    }
  }
}

class _AccountDetailBackButton extends StatelessWidget {
  const _AccountDetailBackButton();

  @override
  Widget build(BuildContext context) {
    final color = LGColors.textPrimary(context);
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(46),
        minimumSize: const Size.square(46),
        foregroundColor: color,
        backgroundColor: LGColors.surfaceTinted(context),
        side: BorderSide(
          color: LGColors.textSecondary(context).withValues(alpha: 0.14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.lg),
        ),
      ),
    );
  }
}

class _AccountDetailHeaderIcon extends StatelessWidget {
  const _AccountDetailHeaderIcon({
    required this.isInvestment,
    required this.balance,
  });

  final bool isInvestment;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final color =
        balance < 0
            ? LGColors.danger
            : (balance == 0 ? LGColors.warning : LGColors.success);
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(
        isInvestment
            ? Icons.trending_up_rounded
            : Icons.account_balance_wallet_outlined,
        color: color,
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
    final accent =
        isTransfer
            ? LGColors.info
            : (isIncome ? LGColors.success : theme.colorScheme.error);
    final icon =
        isTransfer
            ? Icons.swap_horiz_rounded
            : (isIncome
                ? Icons.call_received_rounded
                : Icons.call_made_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.sm),
      child: LGSolidCard(
        tinted: true,
        padding: const EdgeInsets.all(LGSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(
                  alpha: LGColors.isDark(context) ? 0.18 : 0.10,
                ),
                borderRadius: BorderRadius.circular(LGRadius.md),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: LGSpacing.md),
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
                      color: LGColors.textPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(item.date)}'
                    '${(item.effectiveCategory ?? '').isNotEmpty ? ' - ${item.effectiveCategory}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LGColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LGSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amountStr,
                  maxLines: 1,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
