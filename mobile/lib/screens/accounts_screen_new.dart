import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../i18n.dart';
import 'account_detail_screen.dart';

class AccountsScreenNew extends StatefulWidget {
  const AccountsScreenNew({
    super.key,
    this.autoOpenAdd = false,
    this.forceCreate = false,
    this.onAccountCreated,
  });
  final bool autoOpenAdd;
  final bool forceCreate;
  final VoidCallback? onAccountCreated;

  @override
  State<AccountsScreenNew> createState() => _AccountsScreenNewState();
}

class _AccountsScreenNewState extends State<AccountsScreenNew> {
  bool _opened = false;
  String? _token;
  List<Account> _accounts = [];
  bool _loading = true;
  String? _loadError;
  late final RefreshBus _refreshBus;
  int _accountsTick = 0;
  int _transactionsTick = 0;

  Future<List<Account>> _loadAccounts(String? token) {
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    return data.getAccounts();
  }

  Future<void> _load({bool showLoading = true}) async {
    final token = _token ?? context.read<AuthStore>().token;
    _token = token;
    if (showLoading) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final accounts = await _loadAccounts(token);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load(showLoading: false);

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
      _refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _accountsTick = _refreshBus.accounts;
    _transactionsTick = _refreshBus.transactions;
    _refreshBus.addListener(_handleRefresh);
    if (widget.autoOpenAdd && !_opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final api = ApiClient()..setToken(context.read<AuthStore>().token);
        final data = DataService(api);
        await _showCreateAccount(
          context,
          data,
          forceCreate: widget.forceCreate,
        );
        _opened = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<AuthStore>().token;
    if (token == null || token.isEmpty) return;
    if (_token != token) {
      _token = token;
      _load();
    }
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthStore>().token;
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    final accounts = _accounts;
    final appBar = AppBar(title: Text(I18n.t(context, 'title.accounts')));

    if (_loading && accounts.isEmpty) {
      return WillPopScope(
        onWillPop: () async => !widget.forceCreate,
        child: Scaffold(
          backgroundColor: FSColors.background(context),
          appBar: appBar,
          body: const FSLoadingState(),
        ),
      );
    }
    if (_loadError != null && accounts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthStore>();
        if (auth.isAuthenticated) auth.logout(force: true);
      });
      return WillPopScope(
        onWillPop: () async => !widget.forceCreate,
        child: Scaffold(
          backgroundColor: FSColors.background(context),
          appBar: appBar,
          body: const FSLoadingState(),
        ),
      );
    }

    final total = accounts.fold<double>(0, (s, a) => s + a.displayBalance);
    final activeCount = accounts.where((a) => a.isActive).length;
    final highest =
        accounts.isEmpty
            ? null
            : accounts.reduce(
              (a, b) => a.displayBalance >= b.displayBalance ? a : b,
            );

    List<Widget> accountCards() =>
        accounts.map((a) {
          return _AccountCard(
            account: a,
            typeLabel:
                a.isInvestment
                    ? I18n.t(context, 'accounts.type.investment')
                    : (a.type ?? ''),
            balanceLabel: I18n.t(
              context,
              a.isInvestment
                  ? 'accounts.details.estimatedValue'
                  : 'label.currentBalance',
            ),
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => AccountDetailScreen(account: a),
                    ),
                  )
                  .then((changed) {
                    if (changed == true && mounted) {
                      context.read<RefreshBus>().notifyAccounts();
                      _refresh();
                    }
                  });
            },
            onEdit: () => _showEditAccount(context, data, a),
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder:
                    (dctx) => AlertDialog(
                      title: const Text('Delete account?'),
                      content: Text(
                        'Delete ${a.name}?\n\nThis will permanently delete this account and ALL of its related data:\n\n'
                        '- Transactions (cascade)\n'
                        '- Recurring payments (cascade)\n'
                        '- Balance history (cascade)\n\n'
                        'This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );
              if (ok == true) {
                try {
                  await data.deleteAccount(a.id);
                  if (mounted) {
                    context.read<RefreshBus>().notifyAccounts();
                    _refresh();
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
              }
            },
          );
        }).toList();
    return WillPopScope(
      onWillPop: () async => !widget.forceCreate,
      child: Scaffold(
        backgroundColor: FSColors.background(context),
        appBar: appBar,
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
              if (widget.forceCreate && accounts.isEmpty) ...[
                FSCard(
                  variant: FSCardVariant.subtle,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FSColors.intentContainer(
                            context,
                            FSIntent.primary,
                          ),
                          borderRadius: BorderRadius.circular(FSRadius.md),
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: FSColors.primary,
                        ),
                      ),
                      const SizedBox(width: FSSpacing.md),
                      Expanded(
                        child: Text(
                          I18n.t(context, 'onboarding.createFirstAccount'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FSSpacing.md),
              ],
              Wrap(
                spacing: FSSpacing.sm,
                runSpacing: FSSpacing.sm,
                children: [
                  FSButton(
                    label: I18n.t(context, 'label.addAccount'),
                    icon: Icons.add_rounded,
                    onPressed:
                        () => _showCreateAccount(
                          context,
                          data,
                          forceCreate: widget.forceCreate,
                        ),
                  ),
                  FSButton(
                    label: I18n.t(context, 'accounts.transferFunds'),
                    icon: Icons.swap_horiz_rounded,
                    variant: FSButtonVariant.outline,
                    onPressed:
                        _loading
                            ? null
                            : () => _showTransferDialog(context, data),
                  ),
                ],
              ),
              const SizedBox(height: FSSpacing.md),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  const gap = FSSpacing.md;
                  final columns = w < 360 ? 1 : 2;
                  final itemW = (w - (columns - 1) * gap) / columns;
                  final cards = <Widget>[
                    FSMetricCard(
                      title: I18n.t(context, 'kpi.totalBalance'),
                      value: money(total),
                      icon: Icons.attach_money_rounded,
                      accent: total >= 0 ? FSIntent.success : FSIntent.danger,
                    ),
                    FSMetricCard(
                      title: I18n.t(context, 'kpi.accounts'),
                      value: activeCount.toString(),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: FSIntent.primary,
                    ),
                    FSMetricCard(
                      title: I18n.t(context, 'analytics.highestBalanceAccount'),
                      value: money(highest?.displayBalance ?? 0),
                      subtitle: highest?.name,
                      icon: Icons.trending_up_rounded,
                      accent: FSIntent.info,
                    ),
                  ];
                  final children = <Widget>[];
                  for (var i = 0; i < cards.length; i++) {
                    final isLastOdd =
                        columns == 2 &&
                        (cards.length % 2 == 1) &&
                        i == cards.length - 1;
                    final width = isLastOdd ? w : itemW;
                    children.add(
                      SizedBox(width: width, height: 138, child: cards[i]),
                    );
                  }
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: children,
                  );
                },
              ),
              const SizedBox(height: FSSpacing.md),
              if (accounts.isEmpty)
                FSCard(
                  variant: FSCardVariant.elevated,
                  child: FSEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: I18n.t(context, 'onboarding.createFirstAccount'),
                    action: FSButton(
                      label: I18n.t(context, 'label.addAccount'),
                      icon: Icons.add_rounded,
                      onPressed:
                          () => _showCreateAccount(
                            context,
                            data,
                            forceCreate: widget.forceCreate,
                          ),
                    ),
                  ),
                )
              else
                ...accountCards(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransferDialog(
    BuildContext context,
    DataService data,
  ) async {
    String tr(String key) => I18n.tr(context, key);
    final messenger = ScaffoldMessenger.of(context);
    List<Account> accounts = List<Account>.from(_accounts);
    if (accounts.length < 2) {
      try {
        accounts = await data.getAccounts();
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to load accounts: $e')),
        );
        return;
      }
    }
    if (!mounted) return;
    if (accounts.length < 2) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('accounts.transferNeedTwo'))),
      );
      return;
    }

    int? fromId = accounts.first.id;
    int? toId = accounts[1].id;
    final amountCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController(
      text: tr('accounts.transferDescriptionHint'),
    );
    DateTime transferDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (dialogContext, setStateDialog) => AlertDialog(
                  title: Text(tr('accounts.transferFunds')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: fromId,
                                items:
                                    accounts
                                        .map(
                                          (account) => DropdownMenuItem<int>(
                                            value: account.id,
                                            child: Text(account.name),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) =>
                                        setStateDialog(() => fromId = value),
                                decoration: InputDecoration(
                                  labelText: tr('accounts.transferFrom'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: toId,
                                items:
                                    accounts
                                        .map(
                                          (account) => DropdownMenuItem<int>(
                                            value: account.id,
                                            child: Text(account.name),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) =>
                                        setStateDialog(() => toId = value),
                                decoration: InputDecoration(
                                  labelText: tr('accounts.transferTo'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr('accounts.transferAmount'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: formatDate(transferDate),
                          ),
                          decoration: InputDecoration(
                            labelText: tr('accounts.transferDate'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: transferDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setStateDialog(() => transferDate = picked);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionCtrl,
                          decoration: InputDecoration(
                            labelText: tr('accounts.transferDescription'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(tr('label.cancel')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text) ?? 0;
                        if (fromId == null ||
                            toId == null ||
                            fromId == toId ||
                            amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('accounts.transferInvalid')),
                            ),
                          );
                          return;
                        }

                        final fromAccount = accounts.firstWhere(
                          (account) => account.id == fromId,
                        );
                        final toAccount = accounts.firstWhere(
                          (account) => account.id == toId,
                        );
                        if (fromAccount.editableBalance < amount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                tr('accounts.transferInsufficient'),
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          await data.transferFunds(
                            fromAccount: fromAccount,
                            toAccount: toAccount,
                            date: transferDate,
                            amount: amount,
                            description: descriptionCtrl.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to transfer funds: $e'),
                            ),
                          );
                        }
                      },
                      child: Text(tr('accounts.transferSubmit')),
                    ),
                  ],
                ),
          ),
    );

    if (saved == true && mounted) {
      final refreshBus = context.read<RefreshBus>();
      refreshBus.notifyAccounts();
      refreshBus.notifyTransactions();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('accounts.transferSuccess'))));
    }
  }

  Future<void> _showCreateAccount(
    BuildContext context,
    DataService data, {
    bool forceCreate = false,
  }) async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '');
    final bankCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final types = const [
      'Checking',
      'Savings',
      'Business',
      'Investment',
      'Credit',
    ];
    String type = 'Checking';
    bool isActive = true;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceCreate,
      builder:
          (_) => WillPopScope(
            onWillPop: () async => !forceCreate,
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text(I18n.t(context, 'accounts.addNew')),
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
                            items:
                                types
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setState(() => type = v ?? 'Checking'),
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
                              labelText: I18n.t(
                                context,
                                'accounts.initialBalance',
                              ),
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
                              hintText: '****1234',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: isActive,
                            onChanged: (v) => setState(() => isActive = v),
                            title: Text(I18n.t(context, 'accounts.active')),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      if (!forceCreate)
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(I18n.t(context, 'label.cancel')),
                        ),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await data.createAccount(
                              name: nameCtrl.text.trim(),
                              type: type,
                              balance: double.tryParse(balanceCtrl.text) ?? 0,
                              bankName:
                                  bankCtrl.text.trim().isEmpty
                                      ? null
                                      : bankCtrl.text.trim(),
                              accountNumber:
                                  numberCtrl.text.trim().isEmpty
                                      ? null
                                      : numberCtrl.text.trim(),
                              isActive: isActive,
                            );
                            if (context.mounted) {
                              widget.onAccountCreated?.call();
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              final msg =
                                  e.toString().contains('403')
                                      ? 'Free plan limit reached: max 3 accounts. Upgrade to create more.'
                                      : 'Failed to create account: $e';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          }
                        },
                        child: Text(I18n.t(context, 'label.createAccount')),
                      ),
                    ],
                  ),
            ),
          ),
    );
    if (saved == true && mounted) {
      context.read<RefreshBus>().notifyAccounts();
      _refresh();
    }
  }

  Future<void> _showEditAccount(
    BuildContext context,
    DataService data,
    Account a,
  ) async {
    final nameCtrl = TextEditingController(text: a.name);
    final balanceCtrl = TextEditingController(
      text: a.editableBalance.toStringAsFixed(2),
    );
    final bankCtrl = TextEditingController(text: a.bankName ?? '');
    final numberCtrl = TextEditingController(text: a.accountNumber ?? '');
    const types = ['Checking', 'Savings', 'Business', 'Investment', 'Credit'];
    String type = a.type ?? 'Checking';
    bool isActive = a.isActive;
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
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
                          items:
                              types
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => type = v ?? type),
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
                            hintText: '****1234',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v),
                          title: Text(I18n.t(context, 'accounts.active')),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(I18n.t(context, 'label.cancel')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await data.updateAccount(a.id, {
                            'name': nameCtrl.text.trim(),
                            'type': type,
                            'balance':
                                double.tryParse(balanceCtrl.text) ??
                                a.editableBalance,
                            'account_number':
                                numberCtrl.text.trim().isEmpty
                                    ? null
                                    : numberCtrl.text.trim(),
                            'bank_name':
                                bankCtrl.text.trim().isEmpty
                                    ? null
                                    : bankCtrl.text.trim(),
                            'is_active': isActive,
                          });
                          if (context.mounted) Navigator.pop(context, true);
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
    if (saved == true && mounted) {
      context.read<RefreshBus>().notifyAccounts();
      _refresh();
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.typeLabel,
    required this.balanceLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Account account;
  final String typeLabel;
  final String balanceLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final displayBalance = account.displayBalance;
    final balanceIntent =
        displayBalance > 0
            ? FSIntent.success
            : (displayBalance == 0 ? FSIntent.warning : FSIntent.danger);
    final balanceColor = FSColors.intent(balanceIntent);
    final metadata = _accountMetadata(account);

    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.md),
      child: FSCard(
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
                    color: FSColors.intentContainer(context, balanceIntent),
                    borderRadius: BorderRadius.circular(FSRadius.md),
                    border: Border.all(
                      color: FSColors.intentBorder(context, balanceIntent),
                    ),
                  ),
                  child: Icon(
                    account.isInvestment
                        ? Icons.trending_up_rounded
                        : Icons.account_balance_rounded,
                    color: balanceColor,
                  ),
                ),
                const SizedBox(width: FSSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: FSSpacing.xs),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: FSColors.mutedText(context)),
                        ),
                      ],
                      const SizedBox(height: FSSpacing.sm),
                      Wrap(
                        spacing: FSSpacing.sm,
                        runSpacing: FSSpacing.xs,
                        children: [
                          if (typeLabel.isNotEmpty)
                            FSStatusBadge(
                              label: typeLabel,
                              variant: FSStatusBadgeVariant.info,
                            ),
                          FSStatusBadge(
                            label: account.isActive ? 'Active' : 'Inactive',
                            variant:
                                account.isActive
                                    ? FSStatusBadgeVariant.active
                                    : FSStatusBadgeVariant.neutral,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FSSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AccountActionButton(
                      tooltip: 'Edit',
                      icon: Icons.edit_outlined,
                      onPressed: onEdit,
                    ),
                    const SizedBox(height: FSSpacing.xs),
                    _AccountActionButton(
                      tooltip: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onPressed: onDelete,
                      danger: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: FSSpacing.lg),
            _AccountBalanceTile(
              label: balanceLabel,
              value: money(displayBalance),
              intent: balanceIntent,
              valueColor: balanceColor,
            ),
          ],
        ),
      ),
    );
  }

  String _accountMetadata(Account account) {
    if ((account.bankName ?? '').isEmpty &&
        (account.accountNumber ?? '').isEmpty) {
      return '';
    }
    final accountNumber = account.accountNumber ?? '';
    final suffix =
        accountNumber.isEmpty
            ? ''
            : (accountNumber.length > 4
                ? accountNumber.substring(accountNumber.length - 4)
                : accountNumber);
    return '${account.bankName ?? ''}${suffix.isNotEmpty ? '   $suffix' : ''}';
  }
}

class _AccountBalanceTile extends StatelessWidget {
  const _AccountBalanceTile({
    required this.label,
    required this.value,
    required this.intent,
    required this.valueColor,
  });

  final String label;
  final String value;
  final FSIntent intent;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(FSRadius.md),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: FSColors.intent(intent),
            ),
          ),
          const SizedBox(width: FSSpacing.md),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? FSColors.danger : Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        backgroundColor: FSColors.alpha(color, 0.10),
        foregroundColor: color,
        side: BorderSide(color: FSColors.alpha(color, 0.18)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}
