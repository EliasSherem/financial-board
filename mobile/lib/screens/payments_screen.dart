import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../utils/format.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../widgets/category_picker.dart';
import '../widgets/non_pro_interstitial_ad_controller.dart';
import '../screens/manage_categories_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    this.autoOpenAdd = false,
    this.openPaymentId,
  });
  final bool autoOpenAdd;
  final int? openPaymentId;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _opened = false;
  bool _openedFromNotification = false;
  late final RefreshBus _refreshBus;
  int _paymentsTick = 0;
  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _paymentsTick = _refreshBus.payments;
    _refreshBus.addListener(_handleRefresh);
    if (widget.autoOpenAdd && widget.openPaymentId == null && !_opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final api = ApiClient()..setToken(context.read<AuthStore>().token);
          final ds = DataService(api);
          _openPaymentDialog(context, ds);
        } catch (_) {}
        _opened = true;
      });
    }
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    if (!mounted) return;
    if (_refreshBus.payments != _paymentsTick) {
      _paymentsTick = _refreshBus.payments;
      setState(() {});
    }
  }

  Future<void> _deletePayment(
    BuildContext screenContext,
    DataService data,
    PaymentItem payment,
  ) async {
    final deleteLabel = I18n.tr(screenContext, 'label.delete');
    final cancelLabel = I18n.tr(screenContext, 'label.cancel');
    final failedLabel = I18n.tr(screenContext, 'label.failed');
    final deletedLabel = I18n.tr(screenContext, 'projects.deleted');
    final messenger = ScaffoldMessenger.of(screenContext);
    final refreshBus = _refreshBus;

    final shouldDelete = await showDialog<bool>(
      context: screenContext,
      useRootNavigator: false,
      builder:
          (dialogContext) => LGDialogShell(
            title: '$deleteLabel?',
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LGButton(
                  label: cancelLabel,
                  variant: LGButtonVariant.glass,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                const SizedBox(width: LGSpacing.sm),
                _PaymentSoftDangerButton(
                  label: deleteLabel,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            ),
            child: Text(
              '$deleteLabel ${payment.name}?',
              style: TextStyle(color: LGColors.textSecondary(screenContext)),
            ),
          ),
    );

    if (shouldDelete != true) return;

    try {
      await data.deletePayment(payment.id);
      if (!mounted) return;
      refreshBus.notifyPayments();
      setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(deletedLabel)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$failedLabel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiClient()..setToken(context.watch<AuthStore>().token);
    final data = DataService(api);
    return Scaffold(
      body: FutureBuilder<List<PaymentItem>>(
        future: data.getPayments(),
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(LGSpacing.lg),
                  child: LGSolidCard(
                    tinted: true,
                    child: Text(
                      'Error: ${snap.error}',
                      style: TextStyle(color: LGColors.textSecondary(context)),
                    ),
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(LGSpacing.lg),
                child: LGLoadingState(
                  label: I18n.t(context, 'title.recurringPayments'),
                ),
              ),
            );
          }
          final items = snap.data!;
          if (!_openedFromNotification && widget.openPaymentId != null) {
            PaymentItem? target;
            for (final item in items) {
              if (item.id == widget.openPaymentId) {
                target = item;
                break;
              }
            }
            _openedFromNotification = true;
            if (target != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _openPaymentDialog(context, data, initial: target);
              });
            }
          }
          double monthlyEquivalent(PaymentItem p) {
            switch (p.frequency.toLowerCase()) {
              case 'weekly':
                return p.amount * 4.0; // simple approx
              case 'monthly':
                return p.amount;
              case 'quarterly':
                return p.amount / 3.0;
              case 'yearly':
                return p.amount / 12.0;
              default:
                return p.amount;
            }
          }

          final active = items.where((p) => p.isActive).toList();
          final paused = items.where((p) => !p.isActive).toList();
          final monthlyTotal = active.fold<double>(
            0,
            (s, p) => s + monthlyEquivalent(p),
          );
          int dueThisWeek() {
            int c = 0;
            final now = DateTime.now();
            for (final p in active) {
              final next = parseYmdLocal(p.nextDate) ?? now;
              final diff =
                  next
                      .difference(DateTime(now.year, now.month, now.day))
                      .inDays;
              if (diff >= 0 && diff <= 7) c++;
            }
            return c;
          }

          String dueLabel(int diff) {
            if (diff == 0) return I18n.t(context, 'payments.today');
            if (diff == 1) return I18n.t(context, 'payments.tomorrow');
            if (diff < 0) return I18n.t(context, 'payments.overdue');
            final tmpl = I18n.t(context, 'payments.inDays');
            return tmpl.replaceAll('{days}', diff.toString());
          }

          Future<void> processOverdue() async {
            final messenger = ScaffoldMessenger.of(context);
            final failedLabel = I18n.tr(context, 'label.failed');
            try {
              final res = await data.processOverduePayments();
              final cnt = res['processed_count'] ?? 0;
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text('Processed $cnt')));
              setState(() {}); // refresh list without replacing route
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$failedLabel: $e')),
                );
              }
            }
          }

          Future<void> processPayment(PaymentItem p) async {
            final messenger = ScaffoldMessenger.of(context);
            final processedLabel = I18n.tr(context, 'label.processed');
            final failedLabel = I18n.tr(context, 'label.failed');
            try {
              await data.processPayment(p.id);
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text(processedLabel)));
              setState(() {});
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('$failedLabel: $e')),
                );
              }
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                LGSpacing.lg,
                LGSpacing.lg,
                LGSpacing.lg,
                132,
              ),
              children: [
                LGPageHeader(
                  title: I18n.t(context, 'title.recurringPayments'),
                  leading: const _PaymentHeaderIcon(),
                  action: LGButton(
                    label: I18n.t(context, 'label.add'),
                    icon: Icons.add,
                    size: LGButtonSize.sm,
                    onPressed: () => _openPaymentDialog(context, data),
                  ),
                ),
                _PaymentsActionPanel(
                  itemCount: items.length,
                  dueThisWeek: dueThisWeek(),
                  onProcessOverdue: processOverdue,
                ),
                const SizedBox(height: LGSpacing.lg),
                LGMetricGrid(
                  minChildHeight: 132,
                  twoColumnBreakpoint: 300,
                  children: [
                    LGMetricCard(
                      title: I18n.t(context, 'payments.kpi.active'),
                      value: active.length.toString(),
                      icon: Icons.play_arrow_rounded,
                      accentColor: LGColors.success,
                    ),
                    LGMetricCard(
                      title: I18n.t(context, 'payments.kpi.paused'),
                      value: paused.length.toString(),
                      icon: Icons.pause_circle_outline,
                      accentColor: LGColors.warning,
                    ),
                    LGMetricCard(
                      title: I18n.t(context, 'payments.kpi.monthly'),
                      value: NumberFormat.currency(
                        locale: 'en_US',
                        symbol: '\$',
                      ).format(monthlyTotal),
                      icon: Icons.attach_money,
                      accentColor: LGColors.primaryBlue,
                    ),
                    LGMetricCard(
                      title: I18n.t(context, 'payments.kpi.dueWeek'),
                      value: dueThisWeek().toString(),
                      icon: Icons.event_available_outlined,
                      accentColor:
                          dueThisWeek() > 0
                              ? LGColors.warning
                              : LGColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: LGSpacing.xl),
                Text(
                  I18n.t(context, 'payments.scheduled'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: LGSpacing.md),
                if (items.isEmpty)
                  LGEmptyState(
                    icon: Icons.event_repeat_outlined,
                    title: I18n.t(context, 'payments.scheduled'),
                    message: I18n.t(context, 'label.add'),
                    action: LGButton(
                      label: I18n.t(context, 'label.add'),
                      icon: Icons.add,
                      onPressed: () => _openPaymentDialog(context, data),
                    ),
                  )
                else
                  ...items.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: LGSpacing.md),
                      child: _PaymentCard(
                        payment: p,
                        due: _daysUntil(p.nextDate),
                        dueLabel: dueLabel(_daysUntil(p.nextDate)),
                        onProcess: () => processPayment(p),
                        onEdit:
                            () => _openPaymentDialog(context, data, initial: p),
                        onDelete: () => _deletePayment(context, data, p),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openPaymentDialog(
    BuildContext context,
    DataService data, {
    PaymentItem? initial,
  }) async {
    final parentContext = context;
    var paymentMutationSucceeded = false;
    NonProInterstitialAdController.preloadIfEligible(parentContext);
    final accounts = await data.getAccounts();
    List<Project> projects = [];
    try {
      projects = await data.getProjects();
    } catch (_) {}

    List<ExpenseCategory> categories = [];
    ExpenseCategory? selectedCategory;
    ExpenseSubcategory? selectedSubcategory;

    ExpenseCategory? findCategoryByIdLocal(int id) {
      for (final c in categories) {
        if (c.id == id) return c;
      }
      return null;
    }

    ExpenseSubcategory? findSubcategoryByIdLocal(
      ExpenseCategory category,
      int id,
    ) {
      for (final s in category.subcategories) {
        if (s.id == id) return s;
      }
      return null;
    }

    try {
      categories = await data.getExpenseCategories();
      categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (initial != null) {
        if (initial.subcategoryId != null) {
          for (final cat in categories) {
            final sub = findSubcategoryByIdLocal(cat, initial.subcategoryId!);
            if (sub != null) {
              selectedCategory = cat;
              selectedSubcategory = sub;
              break;
            }
          }
        }
        if (selectedCategory == null && initial.categoryId != null) {
          selectedCategory = findCategoryByIdLocal(initial.categoryId!);
        }
      }
    } catch (_) {
      categories = [];
    }

    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final amountCtrl = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2),
    );
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final dateCtrl = TextEditingController(
      text:
          initial?.nextDate != null && initial!.nextDate.isNotEmpty
              ? formatYmd(initial.nextDate)
              : DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    final categoryCtrl = TextEditingController(
      text:
          categories.isEmpty
              ? (initial?.subcategoryName ??
                  initial?.categoryName ??
                  initial?.category ??
                  '')
              : '',
    );
    String frequency = initial?.frequency ?? 'Monthly';
    bool isActive = initial?.isActive ?? true;
    int? accountId =
        initial?.accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    int? projectId = initial?.projectId;
    bool createAsPlan = false;
    final totalCtrl = TextEditingController(text: '');
    final monthsCtrl = TextEditingController(text: '12');

    await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (context, setState) {
              Future<void> reloadCategories() async {
                try {
                  final updated = await data.getExpenseCategories();
                  setState(() {
                    categories = List<ExpenseCategory>.from(updated)..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );
                    if (selectedCategory != null) {
                      selectedCategory = findCategoryByIdLocal(
                        selectedCategory!.id,
                      );
                    }
                    if (selectedCategory == null) {
                      selectedSubcategory = null;
                    } else if (selectedSubcategory != null) {
                      selectedSubcategory = findSubcategoryByIdLocal(
                        selectedCategory!,
                        selectedSubcategory!.id,
                      );
                    }
                    if (categories.isNotEmpty) {
                      categoryCtrl.clear();
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
                    setState(() {
                      categories = List<ExpenseCategory>.from(updated)..sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        ),
                      );
                      if (selectedCategory != null) {
                        selectedCategory = findCategoryByIdLocal(
                          selectedCategory!.id,
                        );
                      }
                      if (selectedCategory == null) {
                        selectedSubcategory = null;
                      } else if (selectedSubcategory != null) {
                        selectedSubcategory = findSubcategoryByIdLocal(
                          selectedCategory!,
                          selectedSubcategory!.id,
                        );
                      }
                      if (categories.isNotEmpty) {
                        categoryCtrl.clear();
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

              final fieldWidth = MediaQuery.of(context).size.width;

              return AlertDialog(
                title: Text(
                  initial == null ? 'Add New Payment' : 'Edit Payment',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (initial == null) ...[
                        SwitchListTile(
                          value: createAsPlan,
                          onChanged: (v) => setState(() => createAsPlan = v),
                          title: const Text(
                            'Create as credit installment plan',
                          ),
                          subtitle: const Text(
                            'Split total into monthly installments',
                          ),
                        ),
                        if (createAsPlan)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 6, bottom: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: totalCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Total Amount',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: monthsCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Months',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (_) {
                                    final total =
                                        double.tryParse(
                                          totalCtrl.text.replaceAll(',', ''),
                                        ) ??
                                        0;
                                    final months =
                                        int.tryParse(monthsCtrl.text) ?? 1;
                                    final per = months > 0 ? total / months : 0;
                                    return Text(
                                      'Monthly charge is computed automatically. Approx: \\nThe last installment adjusts for rounding.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                      DropdownButtonFormField<int>(
                        value: accountId,
                        items: [
                          for (final a in accounts)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        onChanged: (v) => setState(() => accountId = v),
                        decoration: const InputDecoration(labelText: 'Account'),
                      ),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      if (!createAsPlan)
                        TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        onChanged:
                            (v) => setState(() => frequency = v ?? frequency),
                        items: const [
                          DropdownMenuItem(
                            value: 'Weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'Monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'Quarterly',
                            child: Text('Quarterly'),
                          ),
                          DropdownMenuItem(
                            value: 'Yearly',
                            child: Text('Yearly'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                        ),
                      ),
                      TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Next date (dd/mm/yyyy)',
                        ),
                        readOnly: true,
                        onTap: () async {
                          final initialDate =
                              parseDdMmYyyy(dateCtrl.text) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(
                              () =>
                                  dateCtrl.text = DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(picked),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (categories.isEmpty) ...[
                        TextField(
                          controller: categoryCtrl,
                          decoration: InputDecoration(
                            labelText: I18n.tr(context, 'tx.category'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        CategorySelectorField(
                          width: fieldWidth,
                          labelText: I18n.t(context, 'tx.category'),
                          selectedCategory: selectedCategory,
                          selectedSubcategory: selectedSubcategory,
                          onTap: pickCategory,
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
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => const ManageCategoriesScreen(),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: projectId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No project'),
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
                          labelText: 'Project (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (v) => setState(() => isActive = v),
                        title: Text(I18n.tr(context, 'status.active')),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(I18n.tr(context, 'label.cancel')),
                  ),
                  FilledButton(
                    onPressed:
                        accountId == null
                            ? null
                            : () async {
                              try {
                                final categoryLabel =
                                    categories.isEmpty
                                        ? (categoryCtrl.text.trim().isEmpty
                                            ? null
                                            : categoryCtrl.text.trim())
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

                                if (initial == null) {
                                  if (createAsPlan) {
                                    final total =
                                        double.tryParse(
                                          totalCtrl.text.replaceAll(',', ''),
                                        ) ??
                                        0;
                                    final months =
                                        int.tryParse(monthsCtrl.text) ?? 0;
                                    if (total <= 0 || months <= 0) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              I18n.tr(context, 'label.failed'),
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
                                              ? 'Installment'
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
                                    paymentMutationSucceeded = true;
                                  } else {
                                    await data.createPayment(
                                      accountId: accountId!,
                                      name: nameCtrl.text.trim(),
                                      amount:
                                          double.tryParse(amountCtrl.text) ?? 0,
                                      frequency: frequency,
                                      nextDate: ddMmYyyyToYmd(
                                        dateCtrl.text.trim(),
                                      ),
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
                                    paymentMutationSucceeded = true;
                                  }
                                } else {
                                  await data.updatePayment(
                                    id: initial.id,
                                    accountId: accountId!,
                                    name: nameCtrl.text.trim(),
                                    amount:
                                        double.tryParse(amountCtrl.text) ?? 0,
                                    frequency: frequency,
                                    nextDate: ddMmYyyyToYmd(
                                      dateCtrl.text.trim(),
                                    ),
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
                                  paymentMutationSucceeded = true;
                                }
                                if (context.mounted) {
                                  context.read<RefreshBus>().notifyPayments();
                                  Navigator.pop(context);
                                }
                                if (mounted) setState(() {});
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        I18n.tr(context, 'label.failed') + ': ',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    child: Text(I18n.tr(context, 'label.save')),
                  ),
                ],
              );
            },
          ),
    );
    if (paymentMutationSucceeded && parentContext.mounted) {
      await NonProInterstitialAdController.recordSuccessfulMutation(
        parentContext,
      );
    }
  }
}

class _PaymentsActionPanel extends StatelessWidget {
  const _PaymentsActionPanel({
    required this.itemCount,
    required this.dueThisWeek,
    required this.onProcessOverdue,
  });

  final int itemCount;
  final int dueThisWeek;
  final VoidCallback onProcessOverdue;

  @override
  Widget build(BuildContext context) {
    return LGGlassCard(
      variant: LGCardVariant.hero,
      child: Row(
        children: [
          _PaymentHeaderIcon(
            icon: Icons.event_repeat_outlined,
            intent: dueThisWeek > 0 ? LGIntent.warning : LGIntent.primary,
          ),
          const SizedBox(width: LGSpacing.md),
          Expanded(
            child: Wrap(
              spacing: LGSpacing.sm,
              runSpacing: LGSpacing.sm,
              children: [
                LGStatusBadge(
                  label: '${I18n.t(context, 'payments.scheduled')}: $itemCount',
                  variant: LGStatusBadgeVariant.info,
                  icon: Icons.receipt_long_outlined,
                ),
                LGStatusBadge(
                  label:
                      '${I18n.t(context, 'payments.kpi.dueWeek')}: $dueThisWeek',
                  variant:
                      dueThisWeek > 0
                          ? LGStatusBadgeVariant.warning
                          : LGStatusBadgeVariant.success,
                  icon: Icons.event_available_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(width: LGSpacing.sm),
          LGButton(
            label: I18n.t(context, 'label.process'),
            icon: Icons.play_circle_outline,
            variant: LGButtonVariant.glass,
            size: LGButtonSize.sm,
            onPressed: onProcessOverdue,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.due,
    required this.dueLabel,
    required this.onProcess,
    required this.onEdit,
    required this.onDelete,
  });

  final PaymentItem payment;
  final int due;
  final String dueLabel;
  final VoidCallback onProcess;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final displayCategory =
        payment.subcategoryName ?? payment.categoryName ?? payment.category;
    final dueIntent =
        due <= 0
            ? LGIntent.danger
            : (due <= 7 ? LGIntent.warning : LGIntent.success);
    final dueVariant =
        due <= 0
            ? LGStatusBadgeVariant.overdue
            : (due <= 7
                ? LGStatusBadgeVariant.warning
                : LGStatusBadgeVariant.success);

    return LGSolidCard(
      variant: LGCardVariant.interactive,
      tinted: true,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaymentHeaderIcon(
                icon: Icons.event_repeat_outlined,
                intent: payment.isActive ? dueIntent : LGIntent.neutral,
              ),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LGColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xs),
                    Wrap(
                      spacing: LGSpacing.sm,
                      runSpacing: LGSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LGStatusBadge(
                          label:
                              payment.isActive
                                  ? I18n.t(context, 'status.active')
                                  : I18n.t(context, 'status.paused'),
                          variant:
                              payment.isActive
                                  ? LGStatusBadgeVariant.active
                                  : LGStatusBadgeVariant.paused,
                        ),
                        LGStatusBadge(
                          label: payment.frequency,
                          variant: LGStatusBadgeVariant.info,
                          icon: Icons.sync_outlined,
                        ),
                        if (((displayCategory ?? '')).isNotEmpty)
                          LGStatusBadge(
                            label: displayCategory!,
                            variant: LGStatusBadgeVariant.neutral,
                            icon: Icons.sell_outlined,
                          ),
                        if (payment.installmentsTotal != null &&
                            payment.installmentsRemaining != null)
                          LGStatusBadge(
                            label:
                                '${payment.installmentsRemaining} / ${payment.installmentsTotal} left',
                            variant: LGStatusBadgeVariant.info,
                            icon: Icons.format_list_numbered_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Text(
                money(payment.amount),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: LGColors.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _PaymentInfoTile(
                  label: I18n.t(context, 'payments.nextPayment'),
                  value: formatYmd(payment.nextDate),
                  icon: Icons.calendar_today_outlined,
                  intent: dueIntent,
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Expanded(
                child: _PaymentInfoTile(
                  label: I18n.t(context, 'payments.dueIn'),
                  value:
                      due >= 0
                          ? I18n.t(
                            context,
                            'payments.inDays',
                          ).replaceAll('{days}', due.toString())
                          : I18n.t(context, 'payments.pastDue'),
                  icon: Icons.schedule_outlined,
                  intent: dueIntent,
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _PaymentInfoTile(
                  label: I18n.t(context, 'payments.account'),
                  value:
                      payment.accountName ??
                      I18n.t(context, 'payments.account'),
                  icon: Icons.account_balance_wallet_outlined,
                  intent: LGIntent.primary,
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Expanded(
                child: _PaymentInfoTile(
                  label: I18n.t(context, 'payments.project'),
                  value: payment.projectName ?? I18n.t(context, 'tx.noProject'),
                  icon: Icons.folder_open_outlined,
                  intent: LGIntent.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.md),
          Row(
            children: [
              LGStatusBadge(
                label: dueLabel,
                variant: dueVariant,
                icon: Icons.timelapse_outlined,
              ),
              const Spacer(),
              if (payment.isActive && due <= 0) ...[
                _PaymentIconAction(
                  tooltip: I18n.t(context, 'label.process'),
                  icon: Icons.play_circle_outline,
                  intent: LGIntent.success,
                  onPressed: onProcess,
                ),
                const SizedBox(width: LGSpacing.xs),
              ],
              _PaymentIconAction(
                tooltip: I18n.t(context, 'label.edit'),
                icon: Icons.edit_outlined,
                intent: LGIntent.primary,
                onPressed: onEdit,
              ),
              const SizedBox(width: LGSpacing.xs),
              _PaymentIconAction(
                tooltip: I18n.t(context, 'label.delete'),
                icon: Icons.delete_outline,
                intent: LGIntent.danger,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentInfoTile extends StatelessWidget {
  const _PaymentInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.intent,
  });

  final String label;
  final String value;
  final IconData icon;
  final LGIntent intent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LGSpacing.md),
      decoration: BoxDecoration(
        color: LGColors.surfaceSolid(context),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(
          color: LGColors.alpha(LGColors.textSecondary(context), 0.12),
        ),
      ),
      child: Row(
        children: [
          _PaymentMiniIcon(icon: icon, intent: intent),
          const SizedBox(width: LGSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: LGSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: FontWeight.w900,
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

class _PaymentHeaderIcon extends StatelessWidget {
  const _PaymentHeaderIcon({
    this.icon = Icons.payments_outlined,
    this.intent = LGIntent.primary,
  });

  final IconData icon;
  final LGIntent intent;

  @override
  Widget build(BuildContext context) {
    final color = LGColors.intentColor(intent);
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LGColors.intentContainer(context, intent),
        borderRadius: BorderRadius.circular(LGRadius.xl),
        border: Border.all(color: LGColors.intentStroke(context, intent)),
      ),
      child: Icon(icon, color: color, size: 27),
    );
  }
}

class _PaymentMiniIcon extends StatelessWidget {
  const _PaymentMiniIcon({required this.icon, required this.intent});

  final IconData icon;
  final LGIntent intent;

  @override
  Widget build(BuildContext context) {
    final color = LGColors.intentColor(intent);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LGColors.intentContainer(context, intent),
        borderRadius: BorderRadius.circular(LGRadius.md),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _PaymentIconAction extends StatelessWidget {
  const _PaymentIconAction({
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LGColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(LGRadius.pill),
              border: Border.all(color: LGColors.intentStroke(context, intent)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PaymentSoftDangerButton extends StatelessWidget {
  const _PaymentSoftDangerButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.pill),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: LGSpacing.lg),
          decoration: BoxDecoration(
            color: LGColors.intentContainer(context, LGIntent.danger),
            borderRadius: BorderRadius.circular(LGRadius.pill),
            border: Border.all(
              color: LGColors.intentStroke(context, LGIntent.danger),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.delete_outline,
                color: LGColors.danger,
                size: 18,
              ),
              const SizedBox(width: LGSpacing.sm),
              Flexible(
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
            ],
          ),
        ),
      ),
    );
  }
}

int _daysUntil(String ymd) {
  try {
    final asDate = parseYmdLocal(ymd) ?? parseDdMmYyyy(ymd);
    if (asDate == null) return 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return asDate.difference(start).inDays;
  } catch (_) {
    return 0;
  }
}
