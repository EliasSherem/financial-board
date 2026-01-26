import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
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
        await _showCreateAccount(context, data, forceCreate: widget.forceCreate);
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
          appBar: appBar,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_loadError != null && accounts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthStore>();
        if (auth.isAuthenticated) auth.logout();
      });
      return WillPopScope(
        onWillPop: () async => !widget.forceCreate,
        child: Scaffold(
          appBar: appBar,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final total = accounts.fold<double>(
      0,
      (s, a) => s + a.displayBalance,
    );
    final activeCount = accounts.where((a) => a.isActive).length;
    final highest =
        accounts.isEmpty
            ? null
            : accounts.reduce(
              (a, b) => a.displayBalance >= b.displayBalance ? a : b,
            );

    Widget kpi(
      IconData ic,
      String title,
      String value, {
      Color? iconColor,
    }) => SizedBox(
      height: 110,
      child: Card(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface
                : Colors.blue.shade50,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      (iconColor ?? Theme.of(context).colorScheme.primary)
                          .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  ic,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
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
      ),
    );

    List<Widget> accountCards() =>
        accounts.map((a) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final displayBalance = a.displayBalance;
          final Color cardBg =
              isDark
                  ? Theme.of(context).colorScheme.surface
                  : (displayBalance > 0
                      ? Colors.green.shade50
                      : (displayBalance == 0
                          ? Colors.yellow.shade50
                          : Colors.red.shade50));
          final statusColor =
              a.isActive ? const Color(0xFF16A34A) : Colors.grey;
          final statusBg =
              a.isActive ? const Color(0xFFE6F7EC) : Colors.grey.shade200;
          return Card(
            color: cardBg,
            elevation: 6,
            child: InkWell(
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (a.isInvestment || (a.type ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F0FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              a.isInvestment
                                  ? I18n.t(
                                    context,
                                    'accounts.type.investment',
                                  )
                                  : a.type!,
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if ((a.bankName ?? '').isNotEmpty ||
                        (a.accountNumber ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${a.bankName ?? ''}${(a.accountNumber ?? '').isNotEmpty ? '   ' + (a.accountNumber!.length > 4 ? a.accountNumber!.substring(a.accountNumber!.length - 4) : a.accountNumber!) : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      I18n.t(
                        context,
                        a.isInvestment
                            ? 'accounts.details.estimatedValue'
                            : 'label.currentBalance',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(displayBalance),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            a.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(color: statusColor),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditAccount(context, data, a),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
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
                                        onPressed:
                                            () => Navigator.of(
                                              dctx,
                                            ).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed:
                                            () => Navigator.of(
                                              dctx,
                                            ).pop(true),
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
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete account: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();
    return WillPopScope(
      onWillPop: () async => !widget.forceCreate,
      child: Scaffold(
        appBar: appBar,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.forceCreate && accounts.isEmpty) ...[
                Card(
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            I18n.t(context, 'onboarding.createFirstAccount'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  FilledButton.icon(
                    onPressed:
                        () => _showCreateAccount(
                          context,
                          data,
                          forceCreate: widget.forceCreate,
                        ),
                    icon: const Icon(Icons.add),
                    label: Text(I18n.t(context, 'label.addAccount')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  const gap = 12.0;
                  final cards = <Widget>[
                    kpi(
                      Icons.attach_money,
                      I18n.t(context, 'kpi.totalBalance'),
                      money(total),
                    ),
                    kpi(
                      Icons.account_balance_wallet_outlined,
                      I18n.t(context, 'kpi.accounts'),
                      activeCount.toString(),
                    ),
                    kpi(
                      Icons.trending_up,
                      I18n.t(context, 'analytics.highestBalanceAccount'),
                      money(highest?.displayBalance ?? 0),
                    ),
                  ];
                  final itemW =
                      (w - gap) /
                      2; // always 2 columns; last odd spans full width
                  final children = <Widget>[];
                  for (var i = 0; i < cards.length; i++) {
                    final isLastOdd =
                        (cards.length % 2 == 1) && i == cards.length - 1;
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
              const SizedBox(height: 16),
              ...accountCards(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateAccount(
    BuildContext context,
    DataService data,
    {
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
