import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../utils/format.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/category_picker.dart';
import '../screens/manage_categories_screen.dart';

Future<DataService> _svc(BuildContext context) async {
  final api = ApiClient()..setToken(context.read<AuthStore>().token);
  return DataService(api);
}

Future<void> showQuickNewPaymentDialog(BuildContext context) async {
  final data = await _svc(context);
  List<Account> accounts = [];
  List<Project> projects = [];
  List<ExpenseCategory> categories = [];
  try {
    accounts = await data.getAccounts();
  } catch (_) {}
  try {
    projects = await data.getProjects();
  } catch (_) {}
  try {
    categories = await data.getExpenseCategories();
    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  } catch (_) {
    categories = [];
  }

  ExpenseCategory? findCategoryById(int id) {
    for (final cat in categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  ExpenseSubcategory? findSubcategoryById(ExpenseCategory category, int id) {
    for (final sub in category.subcategories) {
      if (sub.id == id) return sub;
    }
    return null;
  }

  int? accountId = accounts.isNotEmpty ? accounts.first.id : null;
  int? projectId;
  ExpenseCategory? selectedCategory;
  ExpenseSubcategory? selectedSubcategory;

  final nameCtrl = TextEditingController();
  final amtCtrl = TextEditingController(text: '');
  final dateCtrl = TextEditingController(text: formatDate(DateTime.now()));
  final descCtrl = TextEditingController();
  final catCtrl = TextEditingController();
  String frequency = 'Monthly';
  bool isActive = true;
  bool createAsPlan = false;
  final totalCtrl = TextEditingController(text: '');
  final monthsCtrl = TextEditingController(text: '12');

  await showDialog<void>(
    context: context,
    builder:
        (_) => StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> reloadCategories() async {
              try {
                final updated = await data.getExpenseCategories();
                setLocal(() {
                  categories = List<ExpenseCategory>.from(updated)..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                  if (selectedCategory != null) {
                    selectedCategory = findCategoryById(selectedCategory!.id);
                  }
                  if (selectedCategory == null) {
                    selectedSubcategory = null;
                  } else if (selectedSubcategory != null) {
                    selectedSubcategory = findSubcategoryById(
                      selectedCategory!,
                      selectedSubcategory!.id,
                    );
                  }
                  if (categories.isNotEmpty) {
                    catCtrl.clear();
                  }
                });
              } catch (_) {}
            }

            Future<void> pickCategory() async {
              final result = await showCategoryPicker(
                context: context,
                data: data,
                categories: categories,
                onCategoriesUpdated: (updated) {
                  setLocal(() {
                    categories = List<ExpenseCategory>.from(updated)..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );
                    if (selectedCategory != null) {
                      selectedCategory = findCategoryById(selectedCategory!.id);
                    }
                    if (selectedCategory == null) {
                      selectedSubcategory = null;
                    } else if (selectedSubcategory != null) {
                      selectedSubcategory = findSubcategoryById(
                        selectedCategory!,
                        selectedSubcategory!.id,
                      );
                    }
                    if (categories.isNotEmpty) {
                      catCtrl.clear();
                    }
                  });
                },
                initialCategory: selectedCategory,
                initialSubcategory: selectedSubcategory,
              );
              if (result != null) {
                setLocal(() {
                  selectedCategory = result.category;
                  selectedSubcategory = result.subcategory;
                  catCtrl.clear();
                });
              }
            }

            final fieldWidth = MediaQuery.of(ctx).size.width;

            return AlertDialog(
              title: Text(I18n.t(context, 'add.newRecurringPayment')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: createAsPlan,
                      onChanged: (v) => setLocal(() => createAsPlan = v),
                      title: Text(I18n.t(context, 'payments.createPlanTitle')),
                      subtitle: Text(
                        I18n.t(context, 'payments.createPlanSubtitle'),
                      ),
                    ),
                    if (createAsPlan) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: totalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setLocal(() {}),
                              decoration: InputDecoration(
                                labelText: I18n.t(
                                  context,
                                  'payments.totalAmount',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: monthsCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setLocal(() {}),
                              decoration: InputDecoration(
                                labelText: I18n.t(context, 'payments.months'),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (_) {
                          final total =
                              double.tryParse(
                                totalCtrl.text.replaceAll(',', ''),
                              ) ??
                              0;
                          final months = int.tryParse(monthsCtrl.text) ?? 0;
                          final per =
                              (months > 0 && total > 0) ? (total / months) : 0;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${I18n.t(context, 'payments.approxMonthly')}: ${money(per)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
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
                      onChanged: (v) => setLocal(() => accountId = v),
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'payments.account'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'label.name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!createAsPlan)
                      TextField(
                        controller: amtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'tx.amount'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      items:
                          const ['Weekly', 'Monthly', 'Quarterly', 'Yearly']
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    I18n.t(
                                      context,
                                      'payments.freq.${f.toLowerCase()}',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (v) => setLocal(() => frequency = v ?? 'Monthly'),
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'payments.frequency'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'payments.nextDate'),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocal(
                                () => dateCtrl.text = formatDate(picked),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      onChanged: (v) => setLocal(() => projectId = v),
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'tx.projectOptional'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (categories.isEmpty) ...[
                      TextField(
                        controller: catCtrl,
                        decoration: InputDecoration(
                          labelText: I18n.tr(context, 'tx.category'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      CategorySelectorField(
                        width: fieldWidth,
                        selectedCategory: selectedCategory,
                        selectedSubcategory: selectedSubcategory,
                        onTap: pickCategory,
                        onClear: () {
                          setLocal(() {
                            selectedCategory = null;
                            selectedSubcategory = null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => const ManageCategoriesScreen(),
                              ),
                            );
                            await reloadCategories();
                          },
                          icon: const Icon(Icons.settings_outlined),
                          label: Text(
                            I18n.tr(context, 'categories.manageTitle'),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: I18n.t(context, 'forms.descriptionOptional'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setLocal(() => isActive = v),
                      title: Text(I18n.t(context, 'label.active')),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(I18n.t(context, 'label.cancel')),
                ),
                FilledButton(
                  onPressed:
                      accountId == null
                          ? null
                          : () async {
                            final categoryLabel =
                                categories.isEmpty
                                    ? (catCtrl.text.trim().isEmpty
                                        ? null
                                        : catCtrl.text.trim())
                                    : (selectedSubcategory?.name ??
                                        selectedCategory?.name);
                            final categoryId =
                                categories.isEmpty
                                    ? null
                                    : selectedCategory?.id;
                            final subcategoryId =
                                categories.isEmpty
                                    ? null
                                    : selectedSubcategory?.id;

                            if (createAsPlan) {
                              final total =
                                  double.tryParse(
                                    totalCtrl.text.replaceAll(',', ''),
                                  ) ??
                                  0;
                              final months = int.tryParse(monthsCtrl.text) ?? 0;
                              if (total <= 0 || months <= 0) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        I18n.tr(
                                          context,
                                          'payments.validationTotalMonths',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              await data.createInstallmentPlan(
                                account_id: accountId!,
                                project_id: projectId,
                                name:
                                    nameCtrl.text.trim().isEmpty
                                        ? I18n.tr(
                                          context,
                                          'payments.planDefaultName',
                                        )
                                        : nameCtrl.text.trim(),
                                description:
                                    descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                total_amount: total,
                                months: months,
                                first_due_date: ddMmYyyyToYmd(
                                  dateCtrl.text.trim(),
                                ),
                                category: categoryLabel,
                                categoryId: categoryId,
                                subcategoryId: subcategoryId,
                              );
                            } else {
                              await data.createPayment(
                                accountId: accountId!,
                                name: nameCtrl.text.trim(),
                                amount: double.tryParse(amtCtrl.text) ?? 0,
                                frequency: frequency,
                                nextDate: ddMmYyyyToYmd(dateCtrl.text.trim()),
                                isActive: isActive,
                                description:
                                    descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                category: categoryLabel,
                                categoryId: categoryId,
                                subcategoryId: subcategoryId,
                                projectId: projectId,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                  child: Text(I18n.t(context, 'label.save')),
                ),
              ],
            );
          },
        ),
  );
}

Future<void> showQuickNewAccountDialog(BuildContext context) async {
  final data = await _svc(context);
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController(text: '');
  final bankCtrl = TextEditingController();
  final numberCtrl = TextEditingController();
  const types = ['Checking', 'Savings', 'Business', 'Investment', 'Credit'];
  String type = 'Checking';
  bool isActive = true;
  await showDialog<void>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(I18n.t(context, 'add.newAccount')),
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
                              child: Text(
                                I18n.t(
                                  context,
                                  'accounts.type.${t.toLowerCase()}',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => type = v ?? 'Checking',
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
                    labelText: I18n.t(context, 'accounts.initialBalance'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bankCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'accounts.bankNameOptional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: numberCtrl,
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
                  onChanged: (v) => isActive = v,
                  title: Text(I18n.t(context, 'accounts.active')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(I18n.t(context, 'label.cancel')),
            ),
            FilledButton(
              onPressed: () async {
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
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(I18n.t(context, 'label.save')),
            ),
          ],
        ),
  );
}

Future<void> showQuickNewCustomerDialog(BuildContext context) async {
  final data = await _svc(context);
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(I18n.t(context, 'invoices.addCustomer')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'label.name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'forms.emailOptional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(I18n.t(context, 'label.cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await data.createCustomer(
                  name: nameCtrl.text.trim(),
                  email:
                      emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(I18n.t(context, 'label.save')),
            ),
          ],
        ),
  );
}

Future<void> showQuickNewProjectDialog(BuildContext context) async {
  final data = await _svc(context);
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final budgetCtrl = TextEditingController(text: '');
  final startCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  String status = 'Active';
  await showDialog<void>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(I18n.t(context, 'add.newProject')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'label.name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'forms.descriptionOptional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'projects.budget'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  items:
                      const ['Active', 'On hold']
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                I18n.t(
                                  context,
                                  s == 'Active'
                                      ? 'projects.statusActive'
                                      : 'projects.statusOnHold',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => status = v ?? 'Active',
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'projects.status'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'projects.startOptional'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) startCtrl.text = formatDate(p);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: endCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'projects.endOptional'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) endCtrl.text = formatDate(p);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(I18n.t(context, 'label.cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await data.createProject(
                  name: nameCtrl.text.trim(),
                  description:
                      descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                  budget: double.tryParse(budgetCtrl.text) ?? 0,
                  spent: 0,
                  status: status,
                  startDate:
                      startCtrl.text.trim().isEmpty
                          ? null
                          : ddMmYyyyToYmd(startCtrl.text.trim()),
                  endDate:
                      endCtrl.text.trim().isEmpty
                          ? null
                          : ddMmYyyyToYmd(endCtrl.text.trim()),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(I18n.t(context, 'label.save')),
            ),
          ],
        ),
  );
}

Future<void> showQuickNewInvoiceDialog(BuildContext context) async {
  final data = await _svc(context);
  List<Customer> customers = [];
  List<Project> projects = [];
  try {
    customers = await data.getCustomers();
  } catch (_) {}
  try {
    projects = await data.getProjects();
  } catch (_) {}
  int? customerId = customers.isNotEmpty ? customers.first.id : null;
  int? projectId;
  final issueCtrl = TextEditingController(text: formatDate(DateTime.now()));
  final dueCtrl = TextEditingController(
    text: formatDate(DateTime.now().add(const Duration(days: 7))),
  );
  final discountCtrl = TextEditingController(text: '');
  final taxCtrl = TextEditingController(text: '');
  List<Map<String, dynamic>> items = [
    {'description': '', 'quantity': null, 'unit_price': null},
  ];

  await showDialog<void>(
    context: context,
    builder:
        (_) => StatefulBuilder(
          builder:
              (ctx, setLocal) => AlertDialog(
                title: Text(I18n.t(context, 'add.newInvoice')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: customerId,
                        items:
                            customers
                                .map(
                                  (c) => DropdownMenuItem<int>(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setLocal(() => customerId = v),
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'invoices.customer'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        onChanged: (v) => setLocal(() => projectId = v),
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'tx.projectOptional'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              controller: issueCtrl,
                              decoration: InputDecoration(
                                labelText: I18n.t(
                                  context,
                                  'invoices.issueDate',
                                ),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  onPressed: () async {
                                    final p = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (p != null)
                                      setLocal(
                                        () => issueCtrl.text = formatDate(p),
                                      );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              controller: dueCtrl,
                              decoration: InputDecoration(
                                labelText: I18n.t(context, 'invoices.dueDate'),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  onPressed: () async {
                                    final p = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 7),
                                      ),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (p != null)
                                      setLocal(
                                        () => dueCtrl.text = formatDate(p),
                                      );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            I18n.t(context, 'invoices.items'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextButton(
                            onPressed:
                                () => setLocal(
                                  () => items.add({
                                    'description': '',
                                    'quantity': null,
                                    'unit_price': null,
                                  }),
                                ),
                            child: Text(I18n.t(context, 'invoices.addItem')),
                          ),
                        ],
                      ),
                      ...List.generate(
                        items.length,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final isNarrow = constraints.maxWidth < 520;
                              Widget descField() => TextFormField(
                                initialValue:
                                    (items[i]['description'] as String?) ?? '',
                                onChanged: (v) => items[i]['description'] = v,
                                decoration: InputDecoration(
                                  labelText: I18n.t(
                                    context,
                                    'invoices.description',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              );
                              Widget qtyField() => TextFormField(
                                initialValue:
                                    (items[i]['quantity'] as num?)
                                        ?.toString() ??
                                    '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged:
                                    (v) => setLocal(
                                      () =>
                                          items[i]['quantity'] =
                                              double.tryParse(v) ?? 0.0,
                                    ),
                                decoration: InputDecoration(
                                  labelText: I18n.t(context, 'invoices.qty'),
                                  border: const OutlineInputBorder(),
                                ),
                              );
                              Widget priceField() => TextFormField(
                                initialValue:
                                    (items[i]['unit_price'] as num?)
                                        ?.toString() ??
                                    '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged:
                                    (v) => setLocal(
                                      () =>
                                          items[i]['unit_price'] =
                                              double.tryParse(v) ?? 0.0,
                                    ),
                                decoration: InputDecoration(
                                  labelText: I18n.t(
                                    context,
                                    'invoices.unitPrice',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              );
                              final removeBtn = IconButton(
                                icon: const Icon(Icons.close),
                                onPressed:
                                    () => setLocal(() => items.removeAt(i)),
                              );
                              final qtyPriceRow = Row(
                                children: [
                                  Expanded(child: qtyField()),
                                  const SizedBox(width: 8),
                                  Expanded(child: priceField()),
                                  if (items.length > 1) ...[
                                    const SizedBox(width: 8),
                                    removeBtn,
                                  ],
                                ],
                              );
                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    descField(),
                                    const SizedBox(height: 8),
                                    qtyPriceRow,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(flex: 3, child: descField()),
                                  const SizedBox(width: 8),
                                  Expanded(child: qtyField()),
                                  const SizedBox(width: 8),
                                  Expanded(child: priceField()),
                                  if (items.length > 1) ...[
                                    const SizedBox(width: 6),
                                    removeBtn,
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: discountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    '${I18n.t(context, 'invoices.discount')} (%)',
                                border: const OutlineInputBorder(),
                                suffixText: '%',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: taxCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    '${I18n.t(context, 'invoices.tax')} (%)',
                                border: const OutlineInputBorder(),
                                suffixText: '%',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(I18n.t(context, 'label.cancel')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (customerId == null) return;
                      final mappedItems =
                          items
                              .map(
                                (it) => {
                                  'description':
                                      (it['description'] as String?)?.trim() ??
                                      I18n.tr(context, 'invoices.itemFallback'),
                                  'quantity':
                                      ((it['quantity'] as num?) ?? 0)
                                          .toDouble(),
                                  'unit_price':
                                      ((it['unit_price'] as num?) ?? 0)
                                          .toDouble(),
                                },
                              )
                              .toList();
                      double subtotal = mappedItems.fold<double>(0.0, (s, it) {
                        final q = (it['quantity'] as num?)?.toDouble() ?? 0.0;
                        final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                        return s + (q * p);
                      });
                      subtotal = double.parse(subtotal.toStringAsFixed(2));
                      final rawDiscount =
                          double.tryParse(
                            discountCtrl.text.replaceAll(',', ''),
                          ) ??
                          0.0;
                      final discountPercent =
                          rawDiscount.isFinite
                              ? math.max(math.min(rawDiscount, 100), 0)
                              : 0.0;
                      final discountAmount = double.parse(
                        (subtotal * (discountPercent / 100)).toStringAsFixed(2),
                      );
                      final taxableBaseRaw = math.max(
                        subtotal - discountAmount,
                        0.0,
                      );
                      final taxableBase = double.parse(
                        taxableBaseRaw.toStringAsFixed(2),
                      );
                      final rawTax =
                          double.tryParse(taxCtrl.text.replaceAll(',', '')) ??
                          0.0;
                      final taxPercent =
                          rawTax.isFinite ? math.max(rawTax, 0) : 0.0;
                      final taxAmount = double.parse(
                        (taxableBase * (taxPercent / 100)).toStringAsFixed(2),
                      );
                      await data.createInvoice(
                        customerId: customerId!,
                        projectId: projectId,
                        accountId: null,
                        number: null,
                        issueDate: ddMmYyyyToYmd(issueCtrl.text.trim()),
                        dueDate: ddMmYyyyToYmd(dueCtrl.text.trim()),
                        discount: discountAmount,
                        tax: taxAmount,
                        items: mappedItems,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(I18n.t(context, 'label.save')),
                  ),
                ],
              ),
        ),
  );
}
