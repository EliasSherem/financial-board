import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../utils/format.dart';
import '../widgets/new_transaction_dialog.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../i18n.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final DataService _data;
  final _scroll = ScrollController();

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
  Map<String, int> _categoryNameToId = {};
  Map<String, int> _subcategoryNameToId = {};
  Map<String, Set<String>> _categoryToSubNames = {};

  @override
  void initState() {
    super.initState();
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
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t(context, 'tx.deleteTitle')),
        content: Text('This will delete "' + t.description + '"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      await _data.deleteTransaction(t.id);
      if (mounted) await _load();
    }
  }  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
      List<ExpenseCategory> catalog = [];
      try {
        catalog = await _data.getExpenseCategories();
      } catch (_) {
        catalog = [];
      }

      // newest first
      txs.sort((a, b) => b.date.compareTo(a.date));
      _all = txs;

      // categories from data
      final set = <String>{};
      final categoryMap = <String, int>{};
      final subcategoryMap = <String, int>{};
      final categoryToSubs = <String, Set<String>>{};

      for (final cat in catalog) {
        final name = cat.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        set.add(name);
        categoryMap[key] = cat.id;
        categoryToSubs.putIfAbsent(key, () => <String>{});
        for (final sub in cat.subcategories) {
          final subName = sub.name.trim();
          if (subName.isEmpty) continue;
          final subKey = subName.toLowerCase();
          set.add(subName);
          subcategoryMap[subKey] = sub.id;
          categoryToSubs[key]!.add(subKey);
        }
      }

      for (final t in txs) {
        final c = t.category?.trim();
        if (c != null && c.isNotEmpty) set.add(c);
        final catName = t.categoryName?.trim();
        if (catName != null && catName.isNotEmpty) {
          set.add(catName);
          final key = catName.toLowerCase();
          if (t.categoryId != null) categoryMap[key] = t.categoryId!;
          categoryToSubs.putIfAbsent(key, () => <String>{});
        }
        final subName = t.subcategoryName?.trim();
        if (subName != null && subName.isNotEmpty) {
          set.add(subName);
          final subKey = subName.toLowerCase();
          if (t.subcategoryId != null) subcategoryMap[subKey] = t.subcategoryId!;
          final parentKey = (catName ?? c)?.toLowerCase();
          if (parentKey != null && parentKey.isNotEmpty) {
            categoryToSubs.putIfAbsent(parentKey, () => <String>{});
            categoryToSubs[parentKey]!.add(subKey);
          }
        }
      }
      _categories = set.toList()..sort();
      _categoryNameToId = categoryMap;
      _subcategoryNameToId = subcategoryMap;
      _categoryToSubNames = categoryToSubs;

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
      final normalized = _category!.toLowerCase();
      final categoryId = _categoryNameToId[normalized];
      final subcategoryId = _subcategoryNameToId[normalized];
      final subNamesForCategory = _categoryToSubNames[normalized];
      final isCategorySelection = subNamesForCategory != null;

      bool matches(TransactionItem t) {
        final catNameLower = (t.categoryName ?? t.category ?? '').toLowerCase();
        final rawCategoryLower = (t.category ?? '').toLowerCase();
        final subLower = (t.subcategoryName ?? '').toLowerCase();

        if (isCategorySelection) {
          if (categoryId != null && t.categoryId == categoryId) return true;
          if (catNameLower == normalized || rawCategoryLower == normalized) return true;
          if (subNamesForCategory!.contains(subLower)) return true;
          return false;
        } else {
          if (subcategoryId != null && t.subcategoryId == subcategoryId) return true;
          return subLower == normalized;
        }
      }

      list = list.where(matches);
    }
    if (_accountId != null) list = list.where((t) => t.accountId == _accountId);
    if (_projectId != null) {
      final p = _projects.firstWhere(
        (x) => x.id == _projectId,
        orElse: () => Project(id: -1, name: '', description: null, budget: 0, spent: 0, status: 'Active'),
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
        setState(() => _visible = next > _filtered.length ? _filtered.length : next);
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
              if (picked != null) setLocal(() => start = DateTime(picked.year, picked.month, picked.day));
            }

            Future<void> pickEnd() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: end ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setLocal(() => end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
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
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Type'),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('All Types')),
                        DropdownMenuItem<String?>(value: 'Income', child: Text('Income')),
                        DropdownMenuItem<String?>(value: 'Expense', child: Text('Expense')),
                      ],
                      onChanged: (v) => setLocal(() => type = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String?>(
                      value: category,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Categories'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                        ..._categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setLocal(() => category = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int?>(
                      value: accountId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Accounts'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Accounts')),
                        ..._accounts.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setLocal(() => accountId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int?>(
                      value: projectId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Projects'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Projects')),
                        ..._projects.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (v) => setLocal(() => projectId = v),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(text: start == null ? '' : formatDate(start!)),
                            decoration: InputDecoration(
                              labelText: 'Start date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: pickStart),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(text: end == null ? '' : formatDate(end!)),
                            decoration: InputDecoration(
                              labelText: 'End date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: pickEnd),
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

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '4'); // fallback not used; actual formatting below
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                  Row(
                    children: [
          OutlinedButton.icon(
            onPressed: _openFiltersSheet,
            icon: const Icon(Icons.filter_alt_outlined),
            label: Text(I18n.t(context, 'tx.filters')),
          ),
                      const SizedBox(width: 8),
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
                    for (final t in _filtered.take(_visible)) _TxCard(item: t, fmt: NumberFormat.currency(symbol: '\$'), onEdit: () => _editTransaction(t), onDelete: () => _deleteTransaction(t)),
                    if (_visible < _filtered.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: Text('Showing $_visible of ${_filtered.length}')),
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
  const _TxCard({required this.item, required this.fmt, required this.onEdit, required this.onDelete});
  final TransactionItem item;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.amount >= 0;
    final amountStr = (isIncome ? '+' : '-') + fmt.format(item.amount.abs());
    final color = isIncome ? Colors.green : Colors.red;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? (isIncome ? const Color(0xFF103521) : const Color(0xFF3A1C1C))
        : (isIncome ? Colors.green.shade50 : Colors.red.shade50);
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
                        item.description.isEmpty ? '(No description)' : item.description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final parts = <String>[];
                        if ((item.accountName ?? '').isNotEmpty) parts.add(item.accountName!);
                        parts.add(formatDate(item.date));
                        if ((item.category ?? '').isNotEmpty) parts.add(item.category!);
                        if ((item.projectName ?? '').isNotEmpty) parts.add(item.projectName!);
                        return Text(
                          parts.join(' - '),
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amountStr, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Edit', icon: Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                        IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: onDelete),
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





