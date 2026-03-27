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
  DateTime? _registeredMonth;
  bool _registeredMonthLoaded = false;
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
            title: Text(I18n.t(context, 'tx.deleteTitle')),
            content: Text('This will delete "' + t.description + '"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
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
    Iterable<TransactionItem> list = _all;
    if (_start != null) list = list.where((t) => !t.date.isBefore(_start!));
    if (_end != null) list = list.where((t) => !t.date.isAfter(_end!));
    if (_type != null) list = list.where((t) => t.type == _type);
    if (_category != null && _category!.isNotEmpty) {
      list = list.where((t) => (t.effectiveCategory ?? '') == _category);
    }
    if (_accountId != null) list = list.where((t) => t.accountId == _accountId);
    if (_projectId != null) {
      final p = _projects.firstWhere(
        (x) => x.id == _projectId,
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
      if (p.id != -1) list = list.where((t) => (t.projectName ?? '') == p.name);
    }
    _filtered = list.toList();
    if (resetVisible) {
      _visible = _filtered.length < 10 ? _filtered.length : 10;
    }
    setState(() {});
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
              if (picked != null)
                setLocal(
                  () => start = DateTime(picked.year, picked.month, picked.day),
                );
            }

            Future<void> pickEnd() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: end ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null)
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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String?>(
                      value: type,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Income',
                          child: Text('Income'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'Expense',
                          child: Text('Expense'),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => type = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String?>(
                      value: category,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Categories',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories'),
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
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int?>(
                      value: accountId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Accounts',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Accounts'),
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
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int?>(
                      value: projectId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Projects',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Projects'),
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
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: start == null ? '' : formatDate(start!),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Start date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today_outlined),
                                onPressed: pickStart,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: end == null ? '' : formatDate(end!),
                            ),
                            decoration: InputDecoration(
                              labelText: 'End date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today_outlined),
                                onPressed: pickEnd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
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
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
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
                          child: const Text('Apply'),
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

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime? _resolveReportMonth() {
    if (_start != null && _end != null) {
      if (_start!.year == _end!.year && _start!.month == _end!.month) {
        return _monthStart(_start!);
      }
    } else if (_start != null) {
      return _monthStart(_start!);
    } else if (_end != null) {
      return _monthStart(_end!);
    }
    return null;
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    if (value is double) {
      return _parseDateValue(value.toInt());
    }
    if (value is Map) {
      final date = value['date'];
      if (date != null) return _parseDateValue(date);
    }
    return null;
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {}
    }
    return null;
  }

  DateTime? _extractRegistrationDate(Map<String, dynamic> me) {
    DateTime? fromMap(Map<String, dynamic> map) {
      const keys = [
        'created_at',
        'createdAt',
        'registered_at',
        'registeredAt',
        'joined_at',
        'joinedAt',
        'signup_at',
        'signupAt',
        'created',
      ];
      for (final key in keys) {
        final dt = _parseDateValue(map[key]);
        if (dt != null) return dt;
      }
      return null;
    }

    final direct = fromMap(me);
    if (direct != null) return direct;
    final user = _asStringMap(me['user']);
    if (user != null) {
      final dt = fromMap(user);
      if (dt != null) return dt;
    }
    final profile = _asStringMap(me['profile']);
    if (profile != null) {
      final dt = fromMap(profile);
      if (dt != null) return dt;
    }
    final data = _asStringMap(me['data']);
    if (data != null) {
      final dt = fromMap(data);
      if (dt != null) return dt;
    }
    return null;
  }

  DateTime? _earliestTransactionDate() {
    if (_all.isEmpty) return null;
    var earliest = _all.first.date;
    for (final t in _all) {
      if (t.date.isBefore(earliest)) earliest = t.date;
    }
    return earliest;
  }

  Future<void> _ensureRegisteredMonth() async {
    if (_registeredMonthLoaded) return;
    _registeredMonthLoaded = true;
    DateTime? registered;
    try {
      final me = await _data.getMe();
      registered = _extractRegistrationDate(me);
    } catch (_) {}
    if (registered != null) {
      final month = _monthStart(registered);
      if (_registeredMonth == null || month.isBefore(_registeredMonth!)) {
        _registeredMonth = month;
      }
    }
    _registeredMonth ??= _monthStart(
      _earliestTransactionDate() ?? DateTime.now(),
    );
  }

  List<DateTime> _availableReportMonths() {
    final now = _monthStart(DateTime.now());
    var start = _monthStart(_registeredMonth ?? now);
    if (start.isAfter(now)) start = now;
    final months = <DateTime>[];
    var cursor = DateTime(start.year, start.month, 1);
    while (!cursor.isAfter(now)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  Future<DateTime?> _pickReportMonth({DateTime? selected}) async {
    await _ensureRegisteredMonth();
    final months = _availableReportMonths();
    if (months.isEmpty) return null;
    if (months.length == 1) return months.first;
    final locale = Localizations.localeOf(context).toString();
    final monthFmt = DateFormat('MMMM yyyy', locale);
    final selectedMonth = selected != null ? _monthStart(selected) : null;
    final displayMonths = months.reversed.toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    I18n.t(context, 'tx.reportPickMonth'),
                    style: textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    itemCount: displayMonths.length,
                    itemBuilder: (ctx, index) {
                      final month = displayMonths[index];
                      final isSelected =
                          selectedMonth != null &&
                          month.year == selectedMonth.year &&
                          month.month == selectedMonth.month;
                      return ListTile(
                        title: Text(monthFmt.format(month)),
                        trailing: isSelected ? const Icon(Icons.check) : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(ctx, month),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<TransactionItem> _reportTransactions(DateTime month) {
    Iterable<TransactionItem> list = _all;
    if (_type != null) list = list.where((t) => t.type == _type);
    if (_category != null && _category!.isNotEmpty) {
      list = list.where((t) => (t.effectiveCategory ?? '') == _category);
    }
    if (_accountId != null) list = list.where((t) => t.accountId == _accountId);
    if (_projectId != null) {
      final p = _projects.firstWhere(
        (x) => x.id == _projectId,
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
      if (p.id != -1) list = list.where((t) => (t.projectName ?? '') == p.name);
    }
    list = list.where(
      (t) => t.date.year == month.year && t.date.month == month.month,
    );
    final result = list.toList()..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  String _reportFileName(DateTime month) {
    final mm = month.month.toString().padLeft(2, '0');
    return 'FinSight_Transactions_${month.year}_$mm.pdf';
  }

  Future<Uint8List> _buildReportPdf(
    DateTime month,
    List<TransactionItem> txs,
  ) async {
    final logoBytes = await rootBundle.load('assets/finsight-icon.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat('MMMM yyyy', locale).format(month);
    final dateFmt = DateFormat('dd/MM/yyyy', locale);
    final moneyFmt = NumberFormat.currency(symbol: '\$');

    final reportTitle = I18n.tr(context, 'tx.reportTitle');
    final reportMonth = I18n.tr(context, 'tx.reportMonth');
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
    for (final account in _accounts) {
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
          _accounts.isNotEmpty
              ? _accounts.fold<double>(
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
              '$reportMonth: $monthLabel',
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
      final month = await _pickReportMonth(selected: _resolveReportMonth());
      if (month == null) return;
      final txs = _reportTransactions(month);
      if (txs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.tr(context, 'tx.reportEmpty'))),
        );
        return;
      }
      final pdfBytes = await _buildReportPdf(month, txs);
      if (!mounted) return;
      final filename = _reportFileName(month);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openFiltersSheet,
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: Text(I18n.t(context, 'tx.filters')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reportBusy ? null : _downloadReport,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(I18n.t(context, 'tx.reports')),
                        ),
                        TextButton(
                          onPressed: () {
                            _type = null;
                            _category = null;
                            _accountId = null;
                            _projectId = null;
                            _start = null;
                            _end = null;
                            _applyFilters(resetVisible: true);
                          },
                          child: Text(I18n.t(context, 'tx.clearFilters')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_filtered.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(I18n.t(context, 'tx.none')),
                        ),
                      )
                    else ...[
                      for (final t in _filtered.take(_visible))
                        _TxCard(
                          item: t,
                          fmt: NumberFormat.currency(symbol: '\$'),
                          onEdit: () => _editTransaction(t),
                          onDelete: () => _deleteTransaction(t),
                        ),
                      if (_visible < _filtered.length)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              'Showing $_visible of ${_filtered.length}',
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await showNewTransactionDialog(context, _data);
          if (ok == true && mounted) await _load();
        },
        child: const Icon(Icons.add),
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
    final isTransfer = item.isTransfer;
    final isIncome = item.amount >= 0;
    final amountStr = (isIncome ? '+' : '-') + fmt.format(item.amount.abs());
    final color =
        isTransfer ? Colors.blue : (isIncome ? Colors.green : Colors.red);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
    final iconFg =
        isDark
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.primary;
    final iconBg =
        isDark
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.82);
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
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, size: 20, color: iconFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description.isEmpty
                            ? '(No description)'
                            : item.description,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final parts = <String>[];
                          if ((item.accountName ?? '').isNotEmpty)
                            parts.add(item.accountName!);
                          parts.add(formatDate(item.date));
                          if ((item.effectiveCategory ?? '').isNotEmpty)
                            parts.add(item.effectiveCategory!);
                          if ((item.projectName ?? '').isNotEmpty)
                            parts.add(item.projectName!);
                          return Text(
                            parts.join(' - '),
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountStr,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: Icon(Icons.edit_outlined, size: 20),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
