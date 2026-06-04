import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/format.dart';
import '../utils/category_icons.dart';
import '../widgets/new_transaction_dialog.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final DataService _data;
  final _scroll = ScrollController();
  late final RefreshBus _refreshBus;
  int _transactionsTick = 0;
  int _accountsTick = 0;
  int _projectsTick = 0;

  bool _loading = true;
  List<TransactionItem> _all = [];
  List<TransactionItem> _filtered = [];
  int _visible = 10; // show last 10 initially

  // Filters
  DateTime? _start;
  DateTime? _end;
  String? _type; // Income | Expense
  String? _category;
  int? _accountId;
  int? _projectId; // filtered by project name, see below

  // Meta for filter dropdowns
  List<Account> _accounts = [];
  List<Project> _projects = [];
  List<String> _categories = [];
  bool _reportBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _transactionsTick = _refreshBus.transactions;
    _accountsTick = _refreshBus.accounts;
    _projectsTick = _refreshBus.projects;
    _refreshBus.addListener(_handleRefresh);
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    _load();
    _scroll.addListener(_onScroll);
  }

  Future<void> _editTransaction(TransactionItem t) async {
    final ok = await showNewTransactionDialog(context, _data, initial: t);
    if (ok == true && mounted) await _load();
  }

  Future<void> _deleteTransaction(TransactionItem t) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: LGColors.surfaceSolid(context),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LGRadius.xl),
              side: BorderSide(
                color: LGColors.alpha(LGColors.textSecondary(context), 0.14),
              ),
            ),
            title: Text(I18n.t(context, 'tx.deleteTitle')),
            content: Text('This will delete "${t.description}"'),
            actions: [
              LGButton(
                label: 'Cancel',
                size: LGButtonSize.sm,
                variant: LGButtonVariant.outline,
                onPressed: () => Navigator.pop(ctx, false),
              ),
              _TxSoftDangerButton(
                label: 'Delete',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
    );
    if (yes == true) {
      await _data.deleteTransaction(t.id);
      if (mounted) {
        context.read<RefreshBus>().notifyTransactions();
        await _load();
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    if (!mounted) return;
    var shouldRefresh = false;
    if (_refreshBus.transactions != _transactionsTick) {
      _transactionsTick = _refreshBus.transactions;
      shouldRefresh = true;
    }
    if (_refreshBus.accounts != _accountsTick) {
      _accountsTick = _refreshBus.accounts;
      shouldRefresh = true;
    }
    if (_refreshBus.projects != _projectsTick) {
      _projectsTick = _refreshBus.projects;
      shouldRefresh = true;
    }
    if (shouldRefresh) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load required datasets first
      final txs = await _data.getTransactions();
      try {
        _accounts = await _data.getAccounts();
      } catch (_) {
        _accounts = [];
      }
      try {
        _projects = await _data.getProjects();
      } catch (_) {
        _projects = [];
      }

      // newest first
      txs.sort((a, b) => b.date.compareTo(a.date));
      _all = txs;

      // categories from data
      final set = <String>{};
      for (final t in txs) {
        final c = t.effectiveCategory?.trim();
        if (c != null && c.isNotEmpty) set.add(c);
      }
      _categories = set.toList()..sort();

      _applyFilters(resetVisible: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters({bool resetVisible = false}) {
    _filtered = _filterTransactions(
      _all,
      start: _start,
      end: _end,
      type: _type,
      category: _category,
      accountId: _accountId,
      projectId: _projectId,
    );
    if (resetVisible) {
      _visible = _filtered.length < 10 ? _filtered.length : 10;
    }
    setState(() {});
  }

  List<TransactionItem> _filterTransactions(
    List<TransactionItem> source, {
    DateTime? start,
    DateTime? end,
    String? type,
    String? category,
    int? accountId,
    Set<int>? accountIds,
    int? projectId,
  }) {
    Iterable<TransactionItem> list = source;
    if (start != null) list = list.where((t) => !t.date.isBefore(start));
    if (end != null) list = list.where((t) => !t.date.isAfter(end));
    if (type != null) list = list.where((t) => t.type == type);
    if (category != null && category.isNotEmpty) {
      list = list.where((t) => (t.effectiveCategory ?? '') == category);
    }
    if (accountId != null) {
      list = list.where((t) => t.accountId == accountId);
    }
    if (accountIds != null) {
      list = list.where((t) => accountIds.contains(t.accountId));
    }
    if (projectId != null) {
      final p = _projects.firstWhere(
        (x) => x.id == projectId,
        orElse:
            () => Project(
              id: -1,
              name: '',
              description: null,
              budget: 0,
              spent: 0,
              status: 'Active',
            ),
      );
      if (p.id != -1) {
        list = list.where((t) => (t.projectName ?? '') == p.name);
      }
    }
    return list.toList();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent <= 0) return; // content shorter than viewport
    if (pos.pixels >= pos.maxScrollExtent - 12) {
      if (_visible < _filtered.length) {
        final next = _visible + 10;
        setState(
          () => _visible = next > _filtered.length ? _filtered.length : next,
        );
      }
    }
  }

  void _openFiltersSheet() {
    String? type = _type;
    String? category = _category;
    int? accountId = _accountId;
    int? projectId = _projectId;
    DateTime? start = _start;
    DateTime? end = _end;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> pickStart() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: start ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocal(
                  () => start = DateTime(picked.year, picked.month, picked.day),
                );
              }
            }

            Future<void> pickEnd() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: end ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocal(
                  () =>
                      end = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        23,
                        59,
                        59,
                      ),
                );
              }
            }

            return LGBottomSheetShell(
              title: I18n.t(context, 'tx.filters'),
              solidContent: true,
              maxHeightFactor: 0.92,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      key: ValueKey('filter-type-${type ?? 'all'}'),
                      initialValue: type,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.t(context, 'tx.type'),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(I18n.t(context, 'tx.allTypes')),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Income',
                          child: Text(I18n.t(context, 'tx.income')),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Expense',
                          child: Text(I18n.t(context, 'tx.expense')),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => type = v),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('filter-category-${category ?? 'all'}'),
                      initialValue: category,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.t(context, 'tx.categories'),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(I18n.t(context, 'tx.allCategories')),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => category = v),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('filter-account-${accountId ?? 'all'}'),
                      initialValue: accountId,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.t(context, 'tx.accounts'),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(I18n.t(context, 'tx.allAccounts')),
                        ),
                        ..._accounts.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => accountId = v),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('filter-project-${projectId ?? 'all'}'),
                      initialValue: projectId,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.t(context, 'tx.projects'),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(I18n.t(context, 'tx.allProjects')),
                        ),
                        ..._projects.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => projectId = v),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: start == null ? '' : formatDate(start!),
                            ),
                            decoration: LGForm.dateFieldDecoration(
                              context,
                              labelText: I18n.t(context, 'tx.startDate'),
                              onCalendarTap: pickStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: LGSpacing.md),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: end == null ? '' : formatDate(end!),
                            ),
                            decoration: LGForm.dateFieldDecoration(
                              context,
                              labelText: I18n.t(context, 'tx.endDate'),
                              onCalendarTap: pickEnd,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Row(
                      children: [
                        LGButton(
                          label: I18n.t(context, 'label.clear'),
                          size: LGButtonSize.sm,
                          variant: LGButtonVariant.outline,
                          onPressed: () {
                            setLocal(() {
                              type = null;
                              category = null;
                              accountId = null;
                              projectId = null;
                              start = null;
                              end = null;
                            });
                          },
                        ),
                        const Spacer(),
                        LGButton(
                          label: I18n.t(context, 'label.process'),
                          size: LGButtonSize.sm,
                          onPressed: () {
                            _type = type;
                            _category = category;
                            _accountId = accountId;
                            _projectId = projectId;
                            _start = start;
                            _end = end;
                            _applyFilters(resetVisible: true);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  _ReportConfig _seedReportConfig() {
    final selectedAccountIds =
        _accountId != null
            ? <int>{_accountId!}
            : _accounts.map((account) => account.id).toSet();
    return _ReportConfig(
      type: _type,
      category: _category,
      projectId: _projectId,
      start: _start,
      end: _end,
      accountIds: selectedAccountIds,
    );
  }

  Future<_ReportConfig?> _openReportOptionsSheet() async {
    final seed = _seedReportConfig();
    String? type = seed.type;
    String? category = seed.category;
    int? projectId = seed.projectId;
    DateTime? start = seed.start;
    DateTime? end = seed.end;
    final accountIds = Set<int>.from(seed.accountIds);

    return showModalBottomSheet<_ReportConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> pickStart() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocal(
                  () => start = DateTime(picked.year, picked.month, picked.day),
                );
              }
            }

            Future<void> pickEnd() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: end ?? start ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocal(
                  () =>
                      end = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        23,
                        59,
                        59,
                      ),
                );
              }
            }

            return LGBottomSheetShell(
              title: I18n.tr(context, 'tx.reportOptions'),
              solidContent: true,
              maxHeightFactor: 0.92,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      key: ValueKey('report-type-${type ?? 'all'}'),
                      initialValue: type,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.tr(context, 'tx.type'),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(I18n.tr(context, 'tx.allTypes')),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Income',
                          child: Text(I18n.tr(context, 'tx.income')),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Expense',
                          child: Text(I18n.tr(context, 'tx.expense')),
                        ),
                      ],
                      onChanged: (value) => setLocal(() => type = value),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('report-category-${category ?? 'all'}'),
                      initialValue: category,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.tr(context, 'tx.categories'),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(I18n.tr(context, 'tx.allCategories')),
                        ),
                        ..._categories.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item,
                            child: Text(item),
                          ),
                        ),
                      ],
                      onChanged: (value) => setLocal(() => category = value),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('report-project-${projectId ?? 'all'}'),
                      initialValue: projectId,
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.tr(context, 'tx.projects'),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(I18n.tr(context, 'tx.allProjects')),
                        ),
                        ..._projects.map(
                          (project) => DropdownMenuItem<int?>(
                            value: project.id,
                            child: Text(project.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setLocal(() => projectId = value),
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Row(
                      children: [
                        Text(
                          I18n.tr(context, 'tx.accounts'),
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        LGButton(
                          label: I18n.tr(context, 'tx.allAccounts'),
                          size: LGButtonSize.sm,
                          variant: LGButtonVariant.outline,
                          onPressed:
                              () => setLocal(
                                () =>
                                    accountIds
                                      ..clear()
                                      ..addAll(
                                        _accounts.map((account) => account.id),
                                      ),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LGSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _accounts.map((account) {
                            final selected = accountIds.contains(account.id);
                            return FilterChip(
                              selected: selected,
                              label: Text(account.name),
                              selectedColor: LGColors.intentContainer(
                                context,
                                LGIntent.primary,
                              ),
                              checkmarkColor: LGColors.primaryBlue,
                              onSelected:
                                  (value) => setLocal(() {
                                    if (value) {
                                      accountIds.add(account.id);
                                    } else {
                                      accountIds.remove(account.id);
                                    }
                                  }),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: start == null ? '' : formatDate(start!),
                            ),
                            decoration: LGForm.dateFieldDecoration(
                              context,
                              labelText: I18n.tr(context, 'tx.startDate'),
                              onCalendarTap: pickStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: LGSpacing.md),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: end == null ? '' : formatDate(end!),
                            ),
                            decoration: LGForm.dateFieldDecoration(
                              context,
                              labelText: I18n.tr(context, 'tx.endDate'),
                              onCalendarTap: pickEnd,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Row(
                      children: [
                        LGButton(
                          label: I18n.tr(context, 'label.clear'),
                          size: LGButtonSize.sm,
                          variant: LGButtonVariant.outline,
                          onPressed: () {
                            setLocal(() {
                              type = null;
                              category = null;
                              projectId = null;
                              start = null;
                              end = null;
                              accountIds
                                ..clear()
                                ..addAll(
                                  _accounts.map((account) => account.id),
                                );
                            });
                          },
                        ),
                        const Spacer(),
                        LGButton(
                          label: I18n.tr(context, 'tx.generateReport'),
                          size: LGButtonSize.sm,
                          onPressed: () {
                            if (accountIds.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    I18n.tr(context, 'tx.reportSelectAccount'),
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(
                              ctx,
                              _ReportConfig(
                                type: type,
                                category: category,
                                projectId: projectId,
                                start: start,
                                end: end,
                                accountIds: Set<int>.from(accountIds),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Account> _reportAccounts(_ReportConfig config) {
    if (config.accountIds.isEmpty) return List<Account>.from(_accounts);
    return _accounts
        .where((account) => config.accountIds.contains(account.id))
        .toList();
  }

  String _reportDateLabel(
    _ReportConfig config,
    DateFormat dateFmt,
    String allDatesLabel,
  ) {
    final start = config.start;
    final end = config.end;
    if (start == null && end == null) return allDatesLabel;
    if (start != null && end != null) {
      return '${dateFmt.format(start)} - ${dateFmt.format(end)}';
    }
    if (start != null) {
      return '${I18n.tr(context, 'tx.startDate')}: ${dateFmt.format(start)}';
    }
    return '${I18n.tr(context, 'tx.endDate')}: ${dateFmt.format(end!)}';
  }

  String _reportFileName(_ReportConfig config) {
    final fmt = DateFormat('yyyy_MM_dd');
    if (config.start != null && config.end != null) {
      return 'FinSight_Transactions_${fmt.format(config.start!)}_${fmt.format(config.end!)}.pdf';
    }
    if (config.start != null) {
      return 'FinSight_Transactions_from_${fmt.format(config.start!)}.pdf';
    }
    if (config.end != null) {
      return 'FinSight_Transactions_until_${fmt.format(config.end!)}.pdf';
    }
    return 'FinSight_Transactions_${fmt.format(DateTime.now())}.pdf';
  }

  Future<Uint8List> _buildReportPdf(
    _ReportConfig config,
    List<TransactionItem> txs,
    List<Account> reportAccounts,
  ) async {
    final logoBytes = await rootBundle.load('assets/finsight-icon.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat('dd/MM/yyyy', locale);
    final moneyFmt = NumberFormat.currency(symbol: '\$');

    final reportTitle = I18n.tr(context, 'tx.reportTitle');
    final reportPeriod = I18n.tr(context, 'tx.reportPeriod');
    final reportAccountsIncluded = I18n.tr(
      context,
      'tx.reportAccountsIncluded',
    );
    final reportAllDates = I18n.tr(context, 'tx.reportAllDates');
    final reportIncome = I18n.tr(context, 'tx.reportIncome');
    final reportExpense = I18n.tr(context, 'tx.reportExpense');
    final reportNet = I18n.tr(context, 'tx.reportNet');
    final reportBalances = I18n.tr(context, 'tx.reportBalances');
    final reportAllTransactions = I18n.tr(context, 'tx.reportAllTransactions');
    final reportAccountTransactions = I18n.tr(
      context,
      'tx.reportAccountTransactions',
    );
    final reportNoAccountTransactions = I18n.tr(
      context,
      'tx.reportNoAccountTransactions',
    );
    final noDescription = I18n.tr(context, 'tx.noDescription');
    final totalBalanceLabel = I18n.tr(context, 'kpi.totalBalance');
    final allAccountsLabel = I18n.tr(context, 'tx.allAccounts');
    final periodLabel = _reportDateLabel(config, dateFmt, reportAllDates);
    final accountSummary =
        reportAccounts.isEmpty
            ? allAccountsLabel
            : reportAccounts.map((account) => account.name).join(', ');

    final headers = [
      I18n.tr(context, 'tx.date'),
      I18n.tr(context, 'tx.description'),
      I18n.tr(context, 'tx.category'),
      I18n.tr(context, 'tx.account'),
      I18n.tr(context, 'tx.amount'),
    ];
    final accountHeaders = [
      I18n.tr(context, 'tx.date'),
      I18n.tr(context, 'tx.description'),
      I18n.tr(context, 'tx.category'),
      I18n.tr(context, 'tx.amount'),
    ];

    final accountNameById = <int, String>{};
    final accountBalanceById = <int, double>{};
    for (final account in reportAccounts) {
      accountNameById[account.id] = account.name;
      accountBalanceById[account.id] = account.displayBalance;
    }
    for (final t in txs) {
      accountNameById.putIfAbsent(
        t.accountId,
        () =>
            t.accountName ?? '${I18n.tr(context, 'tx.account')} ${t.accountId}',
      );
      accountBalanceById.putIfAbsent(t.accountId, () => 0);
    }
    final accountIds =
        accountNameById.keys.toList()..sort(
          (a, b) => accountNameById[a]!.toLowerCase().compareTo(
            accountNameById[b]!.toLowerCase(),
          ),
        );

    final balanceRows =
        accountIds
            .map(
              (id) => [
                accountNameById[id] ?? '-',
                moneyFmt.format(accountBalanceById[id] ?? 0),
              ],
            )
            .toList();
    if (balanceRows.isNotEmpty) {
      final totalBalance =
          reportAccounts.isNotEmpty
              ? reportAccounts.fold<double>(
                0,
                (sum, account) => sum + account.displayBalance,
              )
              : accountBalanceById.values.fold<double>(
                0,
                (sum, balance) => sum + balance,
              );
      balanceRows.insert(0, [totalBalanceLabel, moneyFmt.format(totalBalance)]);
    }

    List<List<String>> buildRows(
      List<TransactionItem> items, {
      required bool includeAccount,
    }) {
      return items.map((t) {
        final desc = t.description.isEmpty ? noDescription : t.description;
        final effectiveCategory = t.effectiveCategory;
        final category =
            (effectiveCategory ?? '').isEmpty ? '-' : effectiveCategory!;
        final account = (t.accountName ?? '').isEmpty ? '-' : t.accountName!;
        return [
          dateFmt.format(t.date),
          desc,
          category,
          if (includeAccount) account,
          moneyFmt.format(t.amount),
        ];
      }).toList();
    }

    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (t.isIncome) {
        income += t.amount;
      } else if (t.isExpense) {
        expense += t.amount.abs();
      }
    }
    final net = income - expense;

    final rows = buildRows(txs, includeAccount: true);
    final txsByAccount = <int, List<TransactionItem>>{};
    for (final t in txs) {
      txsByAccount.putIfAbsent(t.accountId, () => []).add(t);
    }

    final doc = pw.Document();
    final sectionTitle = pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final subSectionTitle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          final content = <pw.Widget>[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logo, width: 32, height: 32),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FinSight',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      reportTitle,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '$reportPeriod: $periodLabel',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Text(
              '$reportAccountsIncluded: $accountSummary',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 16),
            pw.Text(reportBalances, style: sectionTitle),
            pw.SizedBox(height: 6),
            if (balanceRows.isEmpty)
              pw.Text(
                I18n.tr(context, 'analytics.noAccBalanceData'),
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.Table.fromTextArray(
                headers: [
                  I18n.tr(context, 'tx.account'),
                  I18n.tr(context, 'label.currentBalance'),
                ],
                data: balanceRows,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {1: pw.Alignment.centerRight},
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(1.2),
                },
              ),
            pw.SizedBox(height: 16),
            pw.Text(reportAllTransactions, style: sectionTitle),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: headers,
              data: rows,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {4: pw.Alignment.centerRight},
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(2.4),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.2),
              },
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '$reportIncome: ${moneyFmt.format(income)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    '$reportExpense: ${moneyFmt.format(expense)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Divider(),
                  pw.Text(
                    '$reportNet: ${moneyFmt.format(net)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ];

          if (accountIds.isNotEmpty) {
            content.add(pw.SizedBox(height: 16));
            content.add(
              pw.Text(reportAccountTransactions, style: sectionTitle),
            );
            for (final accountId in accountIds) {
              final name = accountNameById[accountId] ?? '-';
              final accountTxs =
                  txsByAccount[accountId] ?? const <TransactionItem>[];
              content.add(pw.SizedBox(height: 8));
              content.add(pw.Text(name, style: subSectionTitle));
              content.add(pw.SizedBox(height: 4));
              if (accountTxs.isEmpty) {
                content.add(
                  pw.Text(
                    reportNoAccountTransactions,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              } else {
                final accountRows = buildRows(
                  accountTxs,
                  includeAccount: false,
                );
                content.add(
                  pw.Table.fromTextArray(
                    headers: accountHeaders,
                    data: accountRows,
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellAlignments: {3: pw.Alignment.centerRight},
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1.2),
                      1: pw.FlexColumnWidth(2.6),
                      2: pw.FlexColumnWidth(1.6),
                      3: pw.FlexColumnWidth(1.2),
                    },
                  ),
                );
              }
            }
          }

          return content;
        },
      ),
    );
    return doc.save();
  }

  Future<void> _downloadReport() async {
    if (_reportBusy) return;
    setState(() => _reportBusy = true);
    try {
      final config = await _openReportOptionsSheet();
      if (config == null) return;
      final txs = _filterTransactions(
        _all,
        start: config.start,
        end: config.end,
        type: config.type,
        category: config.category,
        accountIds: config.accountIds,
        projectId: config.projectId,
      )..sort((a, b) => a.date.compareTo(b.date));
      if (txs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'tx.reportEmpty'))),
        );
        return;
      }
      final reportAccounts = _reportAccounts(config);
      final pdfBytes = await _buildReportPdf(config, txs, reportAccounts);
      if (!mounted) return;
      final filename = _reportFileName(config);
      try {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => pdfBytes,
        );
      } catch (_) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'tx.reportFailed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  List<_FilterBadgeData> _activeFilterBadges() {
    final badges = <_FilterBadgeData>[];
    final type = _type;
    if (type != null) {
      badges.add(
        _FilterBadgeData(
          label:
              type == 'Income'
                  ? I18n.t(context, 'tx.income')
                  : type == 'Expense'
                  ? I18n.t(context, 'tx.expense')
                  : type,
          icon: Icons.swap_vert_rounded,
          variant:
              type == 'Income'
                  ? LGStatusBadgeVariant.success
                  : type == 'Expense'
                  ? LGStatusBadgeVariant.danger
                  : LGStatusBadgeVariant.info,
        ),
      );
    }
    final category = _category;
    if (category != null && category.isNotEmpty) {
      badges.add(
        _FilterBadgeData(
          label: category,
          icon: Icons.sell_outlined,
          variant: LGStatusBadgeVariant.info,
        ),
      );
    }
    final accountId = _accountId;
    if (accountId != null) {
      final account = _accounts.where((item) => item.id == accountId);
      badges.add(
        _FilterBadgeData(
          label:
              account.isEmpty
                  ? '${I18n.t(context, 'tx.account')} $accountId'
                  : account.first.name,
          icon: Icons.account_balance_wallet_outlined,
          variant: LGStatusBadgeVariant.neutral,
        ),
      );
    }
    final projectId = _projectId;
    if (projectId != null) {
      final project = _projects.where((item) => item.id == projectId);
      badges.add(
        _FilterBadgeData(
          label:
              project.isEmpty
                  ? '${I18n.t(context, 'tx.projects')} $projectId'
                  : project.first.name,
          icon: Icons.folder_outlined,
          variant: LGStatusBadgeVariant.warning,
        ),
      );
    }
    if (_start != null) {
      badges.add(
        _FilterBadgeData(
          label: '${I18n.t(context, 'tx.startDate')}: ${formatDate(_start!)}',
          icon: Icons.calendar_today_outlined,
          variant: LGStatusBadgeVariant.neutral,
        ),
      );
    }
    if (_end != null) {
      badges.add(
        _FilterBadgeData(
          label: '${I18n.t(context, 'tx.endDate')}: ${formatDate(_end!)}',
          icon: Icons.event_available_outlined,
          variant: LGStatusBadgeVariant.neutral,
        ),
      );
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filtered.take(_visible).toList();

    void openNewTransaction() async {
      final ok = await showNewTransactionDialog(context, _data);
      if (ok == true && mounted) await _load();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body:
          _loading
              ? SafeArea(
                child: Center(
                  child: LGLoadingState(
                    label: I18n.t(context, 'nav.transactions'),
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    LGSpacing.lg,
                    LGSpacing.lg,
                    LGSpacing.lg,
                    128,
                  ),
                  children: [
                    LGPageHeader(
                      title: I18n.t(context, 'nav.transactions'),
                      leading: const _TransactionsHeaderIcon(),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LGButton(
                        label: I18n.t(context, 'add.newTransaction'),
                        icon: Icons.add,
                        size: LGButtonSize.sm,
                        onPressed: openNewTransaction,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.md),
                    _TransactionsControlCard(
                      totalCount: _all.length,
                      filteredCount: _filtered.length,
                      visibleCount: visibleItems.length,
                      badges: _activeFilterBadges(),
                      onFilters: _openFiltersSheet,
                      onReport: _reportBusy ? null : _downloadReport,
                      reportBusy: _reportBusy,
                      onClear: () {
                        _type = null;
                        _category = null;
                        _accountId = null;
                        _projectId = null;
                        _start = null;
                        _end = null;
                        _applyFilters(resetVisible: true);
                      },
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    if (_filtered.isEmpty)
                      LGEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: I18n.t(context, 'tx.none'),
                        message: I18n.t(context, 'tx.clearFilters'),
                      )
                    else ...[
                      for (final t in visibleItems) ...[
                        _TxCard(
                          item: t,
                          fmt: NumberFormat.currency(symbol: '\$'),
                          onEdit: () => _editTransaction(t),
                          onDelete: () => _deleteTransaction(t),
                        ),
                        const SizedBox(height: LGSpacing.sm),
                      ],
                      if (_visible < _filtered.length)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: LGStatusBadge(
                              label: 'Showing $_visible of ${_filtered.length}',
                              variant: LGStatusBadgeVariant.neutral,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: openNewTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ReportConfig {
  const _ReportConfig({
    required this.accountIds,
    this.start,
    this.end,
    this.type,
    this.category,
    this.projectId,
  });

  final Set<int> accountIds;
  final DateTime? start;
  final DateTime? end;
  final String? type;
  final String? category;
  final int? projectId;
}

class _FilterBadgeData {
  const _FilterBadgeData({
    required this.label,
    required this.icon,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final LGStatusBadgeVariant variant;
}

class _TransactionsHeaderIcon extends StatelessWidget {
  const _TransactionsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LGColors.intentContainer(context, LGIntent.primary),
        borderRadius: BorderRadius.circular(LGRadius.xl),
        border: Border.all(
          color: LGColors.intentStroke(context, LGIntent.primary),
        ),
      ),
      child: const Icon(
        Icons.swap_horiz_rounded,
        color: LGColors.primaryBlue,
        size: 28,
      ),
    );
  }
}

class _TransactionsControlCard extends StatelessWidget {
  const _TransactionsControlCard({
    required this.totalCount,
    required this.filteredCount,
    required this.visibleCount,
    required this.badges,
    required this.onFilters,
    required this.onReport,
    required this.onClear,
    required this.reportBusy,
  });

  final int totalCount;
  final int filteredCount;
  final int visibleCount;
  final List<_FilterBadgeData> badges;
  final VoidCallback onFilters;
  final VoidCallback? onReport;
  final VoidCallback onClear;
  final bool reportBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LGGlassCard(
      variant: LGCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.t(context, 'label.transactions'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: LGColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xs),
                    Text(
                      '$visibleCount / $filteredCount',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LGColors.textSecondary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              LGStatusBadge(
                label: '$totalCount',
                variant: LGStatusBadgeVariant.info,
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.md),
          if (badges.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: LGStatusBadge(
                label: I18n.t(context, 'tx.allTypes'),
                variant: LGStatusBadgeVariant.neutral,
                icon: Icons.filter_alt_off_outlined,
              ),
            )
          else
            Wrap(
              spacing: LGSpacing.sm,
              runSpacing: LGSpacing.sm,
              children: [
                for (final badge in badges)
                  LGStatusBadge(
                    label: badge.label,
                    variant: badge.variant,
                    icon: badge.icon,
                  ),
              ],
            ),
          const SizedBox(height: LGSpacing.lg),
          Wrap(
            spacing: LGSpacing.sm,
            runSpacing: LGSpacing.sm,
            children: [
              LGButton(
                label: I18n.t(context, 'tx.filters'),
                icon: Icons.filter_alt_outlined,
                size: LGButtonSize.sm,
                variant: LGButtonVariant.outline,
                onPressed: onFilters,
              ),
              LGButton(
                label: I18n.t(context, 'tx.reports'),
                icon: Icons.picture_as_pdf_outlined,
                size: LGButtonSize.sm,
                variant: LGButtonVariant.outline,
                loading: reportBusy,
                onPressed: onReport,
              ),
              LGButton(
                label: I18n.t(context, 'tx.clearFilters'),
                size: LGButtonSize.sm,
                variant: LGButtonVariant.ghost,
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxSoftDangerButton extends StatelessWidget {
  const _TxSoftDangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LGRadius.pill),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(
              horizontal: LGSpacing.md,
              vertical: LGSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: LGColors.intentContainer(context, LGIntent.danger),
              borderRadius: BorderRadius.circular(LGRadius.pill),
              border: Border.all(
                color: LGColors.intentStroke(context, LGIntent.danger),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LGColors.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.item,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });
  final TransactionItem item;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = item.isTransfer;
    final isIncome = !isTransfer && item.amount >= 0;
    final amountStr = (isIncome ? '+' : '-') + fmt.format(item.amount.abs());
    final color =
        isTransfer
            ? LGColors.info
            : (isIncome ? LGColors.success : LGColors.danger);
    final intent =
        isTransfer
            ? LGIntent.info
            : (isIncome ? LGIntent.success : LGIntent.danger);
    final typeLabel =
        isTransfer
            ? I18n.t(context, 'tx.transfer')
            : (isIncome
                ? I18n.t(context, 'tx.income')
                : I18n.t(context, 'tx.expense'));
    final typeVariant =
        isTransfer
            ? LGStatusBadgeVariant.info
            : (isIncome
                ? LGStatusBadgeVariant.success
                : LGStatusBadgeVariant.danger);
    final iconKey =
        (item.subcategoryIcon?.trim().isNotEmpty ?? false)
            ? item.subcategoryIcon!.trim()
            : (item.categoryIcon?.trim().isNotEmpty ?? false)
            ? item.categoryIcon!.trim()
            : null;
    final iconData =
        iconKey != null
            ? iconDataFromKey(iconKey)
            : (isTransfer
                ? Icons.swap_horiz
                : isIncome
                ? Icons.trending_up_outlined
                : Icons.receipt_long_outlined);
    final metadata = <String>[];
    if ((item.accountName ?? '').isNotEmpty) metadata.add(item.accountName!);
    metadata.add(formatDate(item.date));
    if ((item.projectName ?? '').isNotEmpty) metadata.add(item.projectName!);
    final category = item.effectiveCategory;

    return LGSolidCard(
      variant: LGCardVariant.elevated,
      tinted: true,
      padding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.md,
        vertical: 14,
      ),
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
                  color: LGColors.intentContainer(context, intent),
                  borderRadius: BorderRadius.circular(LGRadius.md),
                  border: Border.all(
                    color: LGColors.intentStroke(context, intent),
                  ),
                ),
                child: Icon(iconData, size: 20, color: color),
              ),
              const SizedBox(width: LGSpacing.sm),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xs),
                    Text(
                      metadata.join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LGColors.textSecondary(context),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amountStr,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: LGSpacing.xs,
                  runSpacing: LGSpacing.xs,
                  children: [
                    LGStatusBadge(
                      label: typeLabel,
                      variant: typeVariant,
                      icon:
                          isTransfer
                              ? Icons.swap_horiz_rounded
                              : isIncome
                              ? Icons.trending_up_outlined
                              : Icons.trending_down_outlined,
                    ),
                    if ((category ?? '').isNotEmpty)
                      LGStatusBadge(
                        label: category!,
                        variant: LGStatusBadgeVariant.neutral,
                        icon: Icons.sell_outlined,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TxIconAction(
                    tooltip: 'Edit',
                    icon: Icons.edit_outlined,
                    intent: LGIntent.primary,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: LGSpacing.xs),
                  _TxIconAction(
                    tooltip: 'Delete',
                    icon: Icons.delete_outline,
                    intent: LGIntent.danger,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxIconAction extends StatelessWidget {
  const _TxIconAction({
    required this.tooltip,
    required this.icon,
    required this.intent,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final LGIntent intent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = LGColors.intentColor(intent);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LGRadius.pill),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LGColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(LGRadius.pill),
              border: Border.all(color: LGColors.intentStroke(context, intent)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
