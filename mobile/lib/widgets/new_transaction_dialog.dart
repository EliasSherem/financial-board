import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/api.dart';
import '../utils/format.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../i18n.dart';
import '../screens/manage_categories_screen.dart';
import 'category_picker.dart';

Future<bool?> showNewTransactionDialog(
  BuildContext context,
  DataService? data, {
  TransactionItem? initial,
  bool forceCreate = false,
}) {
  // Allow passing null; if null, build DataService from AuthStore
  final svc =
      data ??
      DataService(ApiClient()..setToken(context.read<AuthStore>().token));
  final enforce = forceCreate && initial == null;
  return showDialog<bool>(
    context: context,
    barrierDismissible: !enforce,
    builder:
        (_) => _TransactionForm(
          data: svc,
          initial: initial,
          forceCreate: enforce,
        ),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({
    required this.data,
    this.initial,
    this.forceCreate = false,
  });
  final DataService data;
  final TransactionItem? initial;
  final bool forceCreate;
  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final descCtrl = TextEditingController();
  final amtCtrl = TextEditingController(text: '');
  final categoryCtrl = TextEditingController();
  DateTime date = DateTime.now();
  String type = 'Expense';
  int? accountId;
  int? projectId; // optional

  bool loading = true;
  bool saving = false;
  List<Account> accounts = [];
  List<Project> projects = [];
  List<ExpenseCategory> categories = [];
  ExpenseCategory? selectedCategory;
  ExpenseSubcategory? selectedSubcategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Fetch required data first
      accounts = await widget.data.getAccounts();
      // Projects may be gated in trial accounts; ignore failures gracefully
      try {
        projects = await widget.data.getProjects();
      } catch (_) {
        projects = [];
      }
      final prevCategoryId = selectedCategory?.id;
      final prevSubcategoryId = selectedSubcategory?.id;
      selectedCategory = null;
      selectedSubcategory = null;

      try {
        categories = await widget.data.getExpenseCategories();
        categories.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      } catch (_) {
        categories = [];
      }
      if (widget.initial != null) {
        final it = widget.initial!;
        date = it.date;
        descCtrl.text = it.description;
        amtCtrl.text = it.amount.abs().toStringAsFixed(2);
        type = it.type;
        accountId = it.accountId;
        if (categories.isNotEmpty) {
          if (it.categoryId != null) {
            for (final cat in categories) {
              if (cat.id == it.categoryId) {
                selectedCategory = cat;
                break;
              }
            }
          }
          if (it.subcategoryId != null) {
            for (final cat in categories) {
              for (final sub in cat.subcategories) {
                if (sub.id == it.subcategoryId) {
                  selectedCategory = cat;
                  selectedSubcategory = sub;
                  break;
                }
              }
              if (selectedSubcategory != null) break;
            }
          }
          if (selectedCategory == null && it.categoryName != null) {
            for (final cat in categories) {
              if (cat.name == it.categoryName) {
                selectedCategory = cat;
                break;
              }
            }
          }
          if (selectedSubcategory == null &&
              selectedCategory != null &&
              it.category != null) {
            for (final sub in selectedCategory!.subcategories) {
              if (sub.name == it.category) {
                selectedSubcategory = sub;
                break;
              }
            }
          }
          if (selectedCategory != null || selectedSubcategory != null) {
            categoryCtrl.clear();
          }
        }
        if ((it.category ?? '').isNotEmpty &&
            selectedCategory == null &&
            selectedSubcategory == null) {
          categoryCtrl.text = it.category!;
        }
        if ((it.projectName ?? '').isNotEmpty) {
          final p = projects.firstWhere(
            (p) => p.name == it.projectName,
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
          if (p.id != -1)
            projectId = p.id;
          else
            projectId = null;
        }
      } else {
        if (accounts.isNotEmpty && accountId == null)
          accountId = accounts.first.id;
        if (prevCategoryId != null) {
          for (final cat in categories) {
            if (cat.id == prevCategoryId) {
              selectedCategory = cat;
              break;
            }
          }
        }
        if (prevSubcategoryId != null) {
          for (final cat in categories) {
            for (final sub in cat.subcategories) {
              if (sub.id == prevSubcategoryId) {
                selectedCategory = cat;
                selectedSubcategory = sub;
                break;
              }
            }
            if (selectedSubcategory != null) break;
          }
        }
        if (selectedCategory != null || selectedSubcategory != null) {
          categoryCtrl.clear();
        }
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
    if (!mounted) return;
    setState(() => loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final typeOptions =
        type == 'Transfer'
            ? const ['Expense', 'Income', 'Transfer']
            : const ['Expense', 'Income'];
    final double dropdownItemWidth = (MediaQuery.of(context).size.width * 0.7)
        .clamp(200.0, 360.0);

    final dialog = AlertDialog(
      title: Text(
        isEdit
            ? I18n.t(context, 'tx.editTitle')
            : I18n.t(context, 'tx.addTitle'),
      ),
      content:
          loading
              ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date
                    Text(
                      I18n.t(context, 'tx.date'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: formatDate(date)),
                      readOnly: true,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    Text(
                      I18n.t(context, 'tx.description'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Type + Amount
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                I18n.t(context, 'tx.type'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: type,
                                items:
                                    typeOptions
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(
                                              I18n.t(
                                                context,
                                                t == 'Expense'
                                                    ? 'tx.expense'
                                                    : t == 'Income'
                                                    ? 'tx.income'
                                                    : 'tx.transfer',
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (v) =>
                                        setState(() => type = v ?? 'Expense'),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                I18n.t(context, 'tx.amount'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: amtCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Category (optional)
                    Text(
                      I18n.t(context, 'tx.category'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    if (categories.isEmpty)
                      TextField(
                        controller: categoryCtrl,
                        decoration: InputDecoration(
                          hintText: I18n.t(context, 'tx.optional'),
                          border: const OutlineInputBorder(),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategorySelectorField(
                            width: dropdownItemWidth,
                            selectedCategory: selectedCategory,
                            selectedSubcategory: selectedSubcategory,
                            onTap: () => _pickCategory(context),
                            onClear: () {
                              setState(() {
                                selectedCategory = null;
                                selectedSubcategory = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openManageCategories,
                              icon: const Icon(Icons.category_outlined),
                              label: Text(
                                I18n.tr(context, 'categories.manageTitle'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    // Account select
                    Text(
                      I18n.t(context, 'tx.account'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: accountId,
                      items:
                          accounts.map((a) {
                            final isInvestment =
                                (a.type ?? '').toLowerCase() == 'investment';
                            final label =
                                isInvestment
                                    ? '${a.name} (${I18n.t(context, 'accounts.type.investment')})'
                                    : a.name;
                            return DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(label),
                            );
                          }).toList(),
                      onChanged: (v) => setState(() => accountId = v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Project select optional
                    Text(
                      I18n.t(context, 'tx.projectOptional'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      value: projectId,
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(I18n.t(context, 'tx.noProject')),
                        ),
                        ...projects.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => projectId = v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
      actions: [
        if (!widget.forceCreate)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(I18n.tr(context, 'label.cancel')),
          ),
        FilledButton(
          onPressed:
              saving
                  ? null
                  : () async {
                    final amount = double.tryParse(amtCtrl.text) ?? 0;
                    if (accountId == null || descCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            I18n.tr(context, 'tx.validationDescAccount'),
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => saving = true);
                    try {
                      final manualCategory =
                          categories.isEmpty
                              ? (categoryCtrl.text.trim().isEmpty
                                  ? null
                                  : categoryCtrl.text.trim())
                              : null;
                      final selectedCatId =
                          categories.isEmpty ? null : selectedCategory?.id;
                      final selectedSubId =
                          categories.isEmpty ? null : selectedSubcategory?.id;
                      if (isEdit) {
                        await widget.data.updateTransaction(
                          id: widget.initial!.id,
                          accountId: accountId!,
                          date: date,
                          description: descCtrl.text.trim(),
                          amount: amount,
                          type: type,
                          category: manualCategory,
                          categoryId: selectedCatId,
                          subcategoryId: selectedSubId,
                          projectId: projectId,
                        );
                      } else {
                        await widget.data.createTransaction(
                          accountId: accountId!,
                          date: date,
                          description: descCtrl.text.trim(),
                          amount: amount,
                          type: type,
                          category: manualCategory,
                          categoryId: selectedCatId,
                          subcategoryId: selectedSubId,
                          projectId: projectId,
                        );
                      }
                      if (context.mounted) {
                        context.read<RefreshBus>().notifyTransactions();
                      }
                      if (mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              I18n.tr(context, 'label.failed') + ': $e',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
          child: Text(
            isEdit
                ? I18n.t(context, 'tx.saveChanges')
                : I18n.t(context, 'tx.create'),
          ),
        ),
      ],
    );
    if (!widget.forceCreate) return dialog;
    return WillPopScope(onWillPop: () async => false, child: dialog);
  }

  Future<void> _pickCategory(BuildContext context) async {
    final CategorySelection? result = await showCategoryPicker(
      context: context,
      data: widget.data,
      categories: categories,
      onCategoriesUpdated: (updated) {
        setState(() {
          categories = List<ExpenseCategory>.from(updated)..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          if (selectedCategory != null) {
            final catId = selectedCategory!.id;
            final found = categories.where((c) => c.id == catId);
            if (found.isNotEmpty) {
              selectedCategory = found.first;
            }
          }
          if (selectedSubcategory != null && selectedCategory != null) {
            final subId = selectedSubcategory!.id;
            final foundSub = selectedCategory!.subcategories.where(
              (s) => s.id == subId,
            );
            if (foundSub.isNotEmpty) {
              selectedSubcategory = foundSub.first;
            }
          }
        });
      },
      initialCategory: selectedCategory,
      initialSubcategory: selectedSubcategory,
    );

    if (result != null) {
      setState(() {
        selectedCategory = result.category;
        selectedSubcategory = result.subcategory;
        categoryCtrl.clear();
      });
    }
  }
}
