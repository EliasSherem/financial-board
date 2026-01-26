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
import '../widgets/category_picker.dart';
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

  @override
  Widget build(BuildContext context) {
    final api = ApiClient()..setToken(context.watch<AuthStore>().token);
    final data = DataService(api);
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t(context, 'title.recurringPayments'))),
      body: FutureBuilder<List<PaymentItem>>(
        future: data.getPayments(),
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError)
              return Center(child: Text('Error: ${snap.error}'));
            return const Center(child: CircularProgressIndicator());
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

          Widget smallKpi(
            IconData ic,
            String label,
            String value, {
            Color? iconColor,
          }) {
            return SizedBox(
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
                          color: (iconColor ??
                                  Theme.of(context).colorScheme.primary)
                              .withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          ic,
                          color:
                              iconColor ??
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
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
          }

          String _dueLabel(int diff) {
            if (diff == 0) return I18n.t(context, 'payments.today');
            if (diff == 1) return I18n.t(context, 'payments.tomorrow');
            if (diff < 0) return I18n.t(context, 'payments.overdue');
            final tmpl = I18n.t(context, 'payments.inDays');
            return tmpl.replaceAll('{days}', diff.toString());
          }

          Widget chip(
            String text, {
            Color bg = const Color(0xFFE5F0FF),
            Color fg = const Color(0xFF2563EB),
          }) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

          List<Widget> paymentCards() =>
              items.map((p) {
                final due = _daysUntil(p.nextDate);
                final chipColor =
                    p.isActive
                        ? const Color(0xFFE6F7EC)
                        : const Color(0xFFFFF7E6);
                final chipTextColor =
                    p.isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFB45309);
                final bool isDark =
                    Theme.of(context).brightness == Brightness.dark;
                // Status colors: green = active/upcoming, yellow = due this week, red = past due
                final Color statusColor =
                    (due <= 0)
                        ? const Color(0xFFEF4444)
                        : (due <= 7
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF16A34A));
                final Color cardBg =
                    isDark
                        ? statusColor.withOpacity(0.18)
                        : ((due < 0)
                            ? Colors.red.shade50
                            : (due <= 7
                                ? Colors.yellow.shade50
                                : Colors.green.shade50));
                return Card(
                  color: cardBg,
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DefaultTextStyle.merge(
                      style:
                          isDark
                              ? const TextStyle(color: Colors.white)
                              : const TextStyle(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  p.isActive
                                      ? I18n.t(context, 'status.active')
                                      : I18n.t(context, 'status.paused'),
                                  style: TextStyle(color: chipTextColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (p.isActive && due <= 0)
                                IconButton(
                                  tooltip: I18n.t(context, 'label.process'),
                                  icon: const Icon(
                                    Icons.play_circle_outline,
                                    color: Color(0xFF16A34A),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await data.processPayment(p.id);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            I18n.tr(context, 'label.processed'),
                                          ),
                                        ),
                                      );
                                      setState(() {});
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              I18n.tr(context, 'label.failed') +
                                                  ': $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              IconButton(
                                tooltip: I18n.t(context, 'label.edit'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed:
                                    () => _openPaymentDialog(
                                      context,
                                      data,
                                      initial: p,
                                    ),
                              ),
                              IconButton(
                                tooltip: I18n.t(context, 'label.delete'),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (_) => AlertDialog(
                                          title: Text(
                                            I18n.t(context, 'label.delete') +
                                                '?',
                                          ),
                                          content: Text(
                                            I18n.t(context, 'label.delete') +
                                                ' ${p.name}?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: Text(
                                                I18n.t(context, 'label.cancel'),
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                              child: Text(
                                                I18n.t(context, 'label.delete'),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                  if (yes == true) {
                                    await data.deletePayment(p.id);
                                    if (context.mounted) {
                                      context.read<RefreshBus>().notifyPayments();
                                      setState(() {});
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 8),
                            child: Builder(
                              builder: (context) {
                                final displayCategory =
                                    p.subcategoryName ??
                                    p.categoryName ??
                                    p.category;
                                return Row(
                                  children: [
                                    if (((displayCategory ?? '')).isNotEmpty)
                                      Text(
                                        displayCategory!,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                    if (p.installmentsTotal != null &&
                                        p.installmentsRemaining != null) ...[
                                      const SizedBox(width: 8),
                                      chip(
                                        '${p.installmentsRemaining} / ${p.installmentsTotal} left',
                                        bg: const Color(0xFFEDE7F6),
                                        fg: const Color(0xFF6A1B9A),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _kv(
                                  context,
                                  I18n.t(context, 'payments.amount'),
                                  money(p.amount),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      I18n.t(context, 'payments.frequency'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    chip(p.frequency),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _kv(
                                      context,
                                      I18n.t(context, 'payments.nextPayment'),
                                      formatYmd(p.nextDate),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _dueLabel(due),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _kv(
                                  context,
                                  I18n.t(context, 'payments.account'),
                                  p.accountName ??
                                      I18n.t(context, 'payments.account'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _kv(
                                  context,
                                  I18n.t(context, 'payments.project'),
                                  p.projectName ??
                                      I18n.t(context, 'tx.noProject'),
                                ),
                              ),
                              Expanded(
                                child: _kv(
                                  context,
                                  I18n.t(context, 'payments.dueIn'),
                                  due >= 0
                                      ? I18n.t(
                                        context,
                                        'payments.inDays',
                                      ).replaceAll('{days}', due.toString())
                                      : I18n.t(context, 'payments.pastDue'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final res = await data.processOverduePayments();
                          final cnt = res['processed_count'] ?? 0;
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Processed $cnt')),
                          );
                          setState(
                            () {},
                          ); // refresh list without replacing route
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
                        }
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        I18n.t(context, 'label.process') ?? 'Process',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openPaymentDialog(context, data),
                      icon: const Icon(Icons.add),
                      label: Text(I18n.t(context, 'label.add')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // KPI grid (2 columns; if odd, last full width)
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    const gap = 12.0;
                    final cards = <Widget>[
                      smallKpi(
                        Icons.play_arrow_rounded,
                        I18n.t(context, 'payments.kpi.active'),
                        active.length.toString(),
                        iconColor: const Color(0xFF16A34A),
                      ),
                      smallKpi(
                        Icons.pause_circle_outline,
                        I18n.t(context, 'payments.kpi.paused'),
                        paused.length.toString(),
                        iconColor: const Color(0xFFB45309),
                      ),
                      smallKpi(
                        Icons.attach_money,
                        I18n.t(context, 'payments.kpi.monthly'),
                        NumberFormat.currency(
                          locale: 'en_US',
                          symbol: '\$',
                        ).format(monthlyTotal),
                      ),
                      smallKpi(
                        Icons.event_available_outlined,
                        I18n.t(context, 'payments.kpi.dueWeek'),
                        dueThisWeek().toString(),
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
                Text(
                  I18n.t(context, 'payments.scheduled'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...paymentCards(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      // No FAB; Add button at top
    );
  }

  void _openPaymentDialog(
    BuildContext context,
    DataService data, {
    PaymentItem? initial,
  }) async {
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          I18n.t(context, 'tx.category'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
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
  }
}

Widget _kv(BuildContext context, String k, String v) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        k,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      Text(
        v,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : null,
        ),
      ),
    ],
  );
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
