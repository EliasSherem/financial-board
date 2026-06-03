import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
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

    if (_loading && accounts.isEmpty) {
      return WillPopScope(
        onWillPop: () async => !widget.forceCreate,
        child: Scaffold(
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            children: [
              LGPageHeader(
                title: I18n.t(context, 'title.accounts'),
                leading: const _AccountsHeaderIcon(),
              ),
              const Center(child: LGLoadingState()),
            ],
          ),
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
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            children: [
              LGPageHeader(
                title: I18n.t(context, 'title.accounts'),
                leading: const _AccountsHeaderIcon(),
              ),
              const Center(child: LGLoadingState()),
            ],
          ),
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

    Widget kpi(IconData ic, String title, String value, Color accentColor) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: LGMetricCard(
          title: title,
          value: value,
          icon: ic,
          accentColor: accentColor,
        ),
      );
    }

    List<Widget> accountCards() =>
        accounts.map((a) {
          return _AccountCard(
            account: a,
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
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            children: [
              LGPageHeader(
                title: I18n.t(context, 'title.accounts'),
                leading: const _AccountsHeaderIcon(),
              ),
              if (widget.forceCreate && accounts.isEmpty) ...[
                LGSolidCard(
                  tinted: true,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LGColors.intentContainer(
                              context,
                              LGIntent.primary,
                            ),
                            borderRadius: BorderRadius.circular(LGRadius.lg),
                            border: Border.all(
                              color: LGColors.intentStroke(
                                context,
                                LGIntent.primary,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.flag_outlined,
                            color: LGColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: LGSpacing.md),
                        Expanded(
                          child: Text(
                            I18n.t(context, 'onboarding.createFirstAccount'),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: LGColors.textSecondary(context),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LGSpacing.md),
              ],
              Wrap(
                spacing: LGSpacing.sm,
                runSpacing: LGSpacing.sm,
                children: [
                  LGButton(
                    label: I18n.t(context, 'label.addAccount'),
                    icon: Icons.add,
                    onPressed:
                        () => _showCreateAccount(
                          context,
                          data,
                          forceCreate: widget.forceCreate,
                        ),
                  ),
                  LGButton(
                    label: I18n.t(context, 'accounts.transferFunds'),
                    icon: Icons.swap_horiz,
                    variant: LGButtonVariant.outline,
                    onPressed:
                        _loading
                            ? null
                            : () => _showTransferDialog(context, data),
                  ),
                ],
              ),
              const SizedBox(height: LGSpacing.md),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  const gap = LGSpacing.md;
                  final cards = <Widget>[
                    kpi(
                      Icons.attach_money,
                      I18n.t(context, 'kpi.totalBalance'),
                      money(total),
                      total >= 0 ? LGColors.success : LGColors.danger,
                    ),
                    kpi(
                      Icons.account_balance_wallet_outlined,
                      I18n.t(context, 'kpi.accounts'),
                      activeCount.toString(),
                      Theme.of(context).colorScheme.primary,
                    ),
                    kpi(
                      Icons.trending_up,
                      I18n.t(context, 'analytics.highestBalanceAccount'),
                      money(highest?.displayBalance ?? 0),
                      LGColors.info,
                    ),
                  ];
                  final columns = w < 360 ? 1 : 2;
                  final itemW = (w - (columns - 1) * gap) / columns;
                  final children = <Widget>[];
                  for (var i = 0; i < cards.length; i++) {
                    final isLastOdd =
                        columns > 1 &&
                        (cards.length % 2 == 1) &&
                        i == cards.length - 1;
                    final width = isLastOdd ? w : itemW;
                    children.add(SizedBox(width: width, child: cards[i]));
                  }
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: children,
                  );
                },
              ),
              const SizedBox(height: LGSpacing.lg),
              if (accounts.isEmpty)
                LGEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: I18n.t(context, 'title.accounts'),
                  message: I18n.t(context, 'onboarding.createFirstAccount'),
                  action: LGEmptyAction(
                    label: I18n.t(context, 'label.addAccount'),
                    icon: Icons.add,
                    onPressed:
                        () => _showCreateAccount(
                          context,
                          data,
                          forceCreate: widget.forceCreate,
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
                            decoration: LGForm.solidInputDecoration(
                              context,
                              labelText: I18n.t(context, 'accounts.name'),
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
                            decoration: LGForm.dropdownDecoration(
                              context,
                              labelText: I18n.t(context, 'accounts.type'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: balanceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: LGForm.solidInputDecoration(
                              context,
                              labelText: I18n.t(
                                context,
                                'accounts.initialBalance',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: bankCtrl,
                            decoration: LGForm.solidInputDecoration(
                              context,
                              labelText: I18n.t(
                                context,
                                'accounts.bankNameOptional',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: numberCtrl,
                            keyboardType: TextInputType.number,
                            decoration: LGForm.solidInputDecoration(
                              context,
                              labelText: I18n.t(
                                context,
                                'accounts.accountNumberOptional',
                              ),
                              hintText: '****1234',
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
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Account account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final displayBalance = account.displayBalance;
    final primary = Theme.of(context).colorScheme.primary;
    final balanceColor = _balanceColor(displayBalance);
    final accountType = _accountTypeLabel(context, account);
    final meta = _accountMeta(account);

    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.md),
      child: LGSolidCard(
        variant: LGCardVariant.elevated,
        padding: const EdgeInsets.all(LGSpacing.lg),
        onTap: onTap,
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
                    color: balanceColor.withValues(
                      alpha: LGColors.isDark(context) ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(LGRadius.lg),
                    border: Border.all(
                      color: balanceColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(_accountIcon(account), color: balanceColor),
                ),
                const SizedBox(width: LGSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
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
                          if (accountType != null)
                            LGStatusBadge(
                              label: accountType,
                              variant:
                                  account.isInvestment
                                      ? LGStatusBadgeVariant.info
                                      : LGStatusBadgeVariant.neutral,
                              icon:
                                  account.isInvestment
                                      ? Icons.trending_up_rounded
                                      : Icons.account_balance_wallet_outlined,
                            ),
                          LGStatusBadge(
                            label: account.isActive ? 'Active' : 'Inactive',
                            variant:
                                account.isActive
                                    ? LGStatusBadgeVariant.active
                                    : LGStatusBadgeVariant.neutral,
                            icon:
                                account.isActive
                                    ? Icons.check_rounded
                                    : Icons.pause_rounded,
                          ),
                          if (meta != null)
                            _AccountMetaPill(
                              icon: Icons.account_balance_outlined,
                              label: meta,
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
                    _AccountActionButton(
                      tooltip: 'Edit',
                      icon: Icons.edit_outlined,
                      color: primary,
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: LGSpacing.xs),
                    _AccountActionButton(
                      tooltip: 'Delete',
                      icon: Icons.delete_outline,
                      color: LGColors.danger,
                      onPressed: () {
                        onDelete();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: LGSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LGSpacing.md),
              decoration: BoxDecoration(
                color: LGColors.surfaceTinted(context),
                borderRadius: BorderRadius.circular(LGRadius.lg),
                border: Border.all(
                  color: LGColors.textSecondary(
                    context,
                  ).withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: balanceColor.withValues(
                        alpha: LGColors.isDark(context) ? 0.18 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(LGRadius.md),
                    ),
                    child: Icon(
                      account.isInvestment
                          ? Icons.stacked_line_chart_rounded
                          : Icons.payments_outlined,
                      color: balanceColor,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          I18n.t(
                            context,
                            account.isInvestment
                                ? 'accounts.details.estimatedValue'
                                : 'label.currentBalance',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: LGColors.textSecondary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            money(displayBalance),
                            maxLines: 1,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: balanceColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LGSpacing.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: LGColors.textSecondary(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _balanceColor(double balance) {
    if (balance < 0) return LGColors.danger;
    if (balance == 0) return LGColors.warning;
    return LGColors.success;
  }

  IconData _accountIcon(Account account) {
    if (account.isInvestment) return Icons.trending_up_rounded;
    final type = (account.type ?? '').toLowerCase();
    if (type.contains('credit')) return Icons.credit_card_rounded;
    if (type.contains('business')) return Icons.business_center_outlined;
    if (type.contains('savings')) return Icons.savings_outlined;
    return Icons.account_balance_wallet_outlined;
  }

  String? _accountTypeLabel(BuildContext context, Account account) {
    if (account.isInvestment) {
      return I18n.t(context, 'accounts.type.investment');
    }
    final type = account.type;
    if (type == null || type.isEmpty) return null;
    return type;
  }

  String? _accountMeta(Account account) {
    final bank = account.bankName ?? '';
    final number = account.accountNumber ?? '';
    final lastDigits =
        number.isEmpty
            ? ''
            : (number.length > 4
                ? number.substring(number.length - 4)
                : number);
    if (bank.isEmpty && lastDigits.isEmpty) return null;
    if (bank.isEmpty) return lastDigits;
    if (lastDigits.isEmpty) return bank;
    return '$bank   $lastDigits';
  }
}

class _AccountsHeaderIcon extends StatelessWidget {
  const _AccountsHeaderIcon();

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
      child: Icon(
        Icons.account_balance_wallet_outlined,
        color: color,
        size: 25,
      ),
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        backgroundColor: color.withValues(
          alpha: LGColors.isDark(context) ? 0.18 : 0.10,
        ),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.24)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.md),
        ),
      ),
    );
  }
}

class _AccountMetaPill extends StatelessWidget {
  const _AccountMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 26,
        maxWidth: MediaQuery.sizeOf(context).width - 96,
      ),
      child: Container(
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: LGColors.textSecondary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
