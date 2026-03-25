import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/pro_widgets.dart';
import 'dart:math' as math;

import '../models.dart';
import '../utils/format.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../i18n.dart';
import '../utils/invoice_pdf.dart';

Future<Map<String, dynamic>> _emailInvoicePdf({
  required BuildContext context,
  required DataService data,
  required InvoiceDetail detail,
}) async {
  final senderName = context.read<AuthStore>().userName;
  final pdfBytes = await buildInvoicePdf(context, detail, senderName);
  return data.emailInvoice(
    id: detail.invoice.id,
    filename: invoicePdfFilename(detail.invoice),
    pdfBytes: pdfBytes,
  );
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    this.autoOpenInvoice = false,
    this.autoOpenCustomer = false,
  });
  final bool autoOpenInvoice;
  final bool autoOpenCustomer;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late final DataService _data;
  bool _loading = true;
  List<InvoiceSummary> _invoices = [];
  List<Customer> _customers = [];
  List<Account> _accounts = [];
  List<Project> _projects = [];
  late final RefreshBus _refreshBus;
  int _invoicesTick = 0;
  int _customersTick = 0;
  int _projectsTick = 0;
  int? _sharingInvoiceId;

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _invoicesTick = _refreshBus.invoices;
    _customersTick = _refreshBus.customers;
    _projectsTick = _refreshBus.projects;
    _refreshBus.addListener(_handleRefresh);
    final store = context.read<AuthStore>();
    final api = ApiClient()..setToken(store.token);
    _data = DataService(api);
    if (store.isProOrExempt) {
      _load();
    } else {
      _loading = false;
    }
    // Optional auto-open of dialogs after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!store.isProOrExempt) return;
      if (widget.autoOpenInvoice) {
        if (_customers.isEmpty || _projects.isEmpty) {
          try {
            await _load();
          } catch (_) {}
        }
        try {
          _showAddInvoice();
        } catch (_) {}
      } else if (widget.autoOpenCustomer) {
        try {
          _showAddCustomer();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _data.getInvoices(),
        _data.getCustomers(),
        _data.getAccounts(),
        _data.getProjects(),
      ]);
      _invoices = res[0] as List<InvoiceSummary>;
      _customers = res[1] as List<Customer>;
      _accounts = res[2] as List<Account>;
      _projects = res[3] as List<Project>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleRefresh() {
    if (!mounted) return;
    var shouldRefresh = false;
    if (_refreshBus.invoices != _invoicesTick) {
      _invoicesTick = _refreshBus.invoices;
      shouldRefresh = true;
    }
    if (_refreshBus.customers != _customersTick) {
      _customersTick = _refreshBus.customers;
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

  String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return Scaffold(
        appBar: AppBar(title: Text(I18n.t(context, 'title.invoices'))),
        body: const ProBlock(feature: 'Invoices'),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    // Two tabs: Invoices and Customers
    Widget invoicesTab() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _showAddInvoice,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(I18n.t(context, 'invoices.add')),
            ),
          ),
          const SizedBox(height: 16),
          ..._invoices
              .map(
                (inv) => _InvoiceCard(
                  inv: inv,
                  onOpen: () => _openInvoice(inv),
                  onPay: () => _markPaid(inv),
                  onShare:
                      (inv.customerEmail ?? '').trim().isEmpty
                          ? null
                          : () => _shareInvoice(inv),
                  isSharing: _sharingInvoiceId == inv.id,
                ),
              )
              .toList(),
        ],
      ),
    );

    Widget customersTab() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _showAddCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(I18n.t(context, 'invoices.addCustomer')),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children:
                    _customers
                        .map(
                          (c) => _CustomerRow(
                            customer: c,
                            onEdit: () => _editCustomer(c),
                            onDelete: () => _deleteCustomer(c),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
        ],
      ),
    );

    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: cs.surface,
            child: TabBar(
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              tabs: [
                Tab(text: I18n.t(context, 'title.invoices')),
                Tab(text: I18n.t(context, 'title.customers')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [invoicesTab(), customersTab()]),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCustomer() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(I18n.t(context, 'invoices.newCustomer')),
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
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(I18n.t(context, 'label.save')),
              ),
            ],
          ),
    );
    if (!mounted || ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(context, 'validation.nameRequired'))),
      );
      return;
    }
    try {
      await _data.createCustomer(
        name: name,
        email: _trimToNull(emailCtrl.text),
      );
      if (!mounted) return;
      context.read<RefreshBus>().notifyCustomers();
      await _load();
    } catch (e, st) {
      debugPrint('Failed to create customer: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.tr(context, 'invoices.customerSaveFailed')),
        ),
      );
    }
  }

  Future<void> _editCustomer(Customer c) async {
    final nameCtrl = TextEditingController(text: c.name);
    final emailCtrl = TextEditingController(text: c.email ?? '');
    final companyCtrl = TextEditingController(text: c.company ?? '');
    final taxCtrl = TextEditingController(text: c.taxId ?? '');
    final addrCtrl = TextEditingController(text: c.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(I18n.t(context, 'invoices.editCustomer')),
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
                      labelText: I18n.t(context, 'profile.email'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: companyCtrl,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'forms.company'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: taxCtrl,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'forms.taxId'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addrCtrl,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'forms.address'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(I18n.t(context, 'label.save')),
              ),
            ],
          ),
    );
    if (!mounted || ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(context, 'validation.nameRequired'))),
      );
      return;
    }
    try {
      await _data.updateCustomer(
        id: c.id,
        name: name,
        email: _trimToNull(emailCtrl.text),
        company: _trimToNull(companyCtrl.text),
        taxId: _trimToNull(taxCtrl.text),
        address: _trimToNull(addrCtrl.text),
      );
      if (!mounted) return;
      context.read<RefreshBus>().notifyCustomers();
      await _load();
    } catch (e, st) {
      debugPrint('Failed to update customer ${c.id}: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.tr(context, 'invoices.customerSaveFailed')),
        ),
      );
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(I18n.t(context, 'invoices.deleteCustomerTitle')),
            content: Text(
              '${I18n.t(context, 'invoices.deleteCustomerPrefix')} ${c.name}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(I18n.t(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(I18n.t(context, 'label.delete')),
              ),
            ],
          ),
    );
    if (!mounted || yes != true) return;
    try {
      await _data.deleteCustomer(c.id);
      if (!mounted) return;
      context.read<RefreshBus>().notifyCustomers();
      await _load();
    } catch (e, st) {
      debugPrint('Failed to delete customer ${c.id}: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.tr(context, 'invoices.customerDeleteFailed')),
        ),
      );
    }
  }

  void _showAddInvoice() async {
    int? customerId = _customers.isNotEmpty ? _customers.first.id : null;
    int? projectId;
    final issueCtrl = TextEditingController(text: formatDate(DateTime.now()));
    final dueCtrl = TextEditingController(
      text: formatDate(DateTime.now().add(const Duration(days: 7))),
    );
    final discountCtrl = TextEditingController(text: '');
    final taxCtrl = TextEditingController(text: '');
    final customerCtrl = TextEditingController(
      text: () {
        try {
          final c = _customers.firstWhere((c) => c.id == customerId);
          return c.name;
        } catch (_) {
          return '';
        }
      }(),
    );

    List<Map<String, dynamic>> items = [
      {'description': '', 'quantity': 1.0, 'unit_price': 0.0},
    ];

    double _subtotal() => items.fold<double>(0.0, (s, it) {
      final q = (it['quantity'] as num?)?.toDouble() ?? 0.0;
      final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
      return s + (q * p);
    });
    double _parseNum(String s) => double.tryParse(s.replaceAll(',', '')) ?? 0.0;
    double _percentValue(String s, {double? max}) {
      final raw = _parseNum(s);
      if (!raw.isFinite) return 0.0;
      double val = raw;
      if (val < 0) val = 0;
      if (max != null && val > max) val = max;
      return val;
    }

    Map<String, double> _computeTotals() {
      final subtotal = double.parse(_subtotal().toStringAsFixed(2));
      final discountPercent = _percentValue(discountCtrl.text, max: 100);
      final taxPercent = _percentValue(taxCtrl.text);
      final discountAmount = double.parse(
        (subtotal * (discountPercent / 100)).toStringAsFixed(2),
      );
      final taxableBaseRaw = math.max(subtotal - discountAmount, 0.0);
      final taxableBase = double.parse(taxableBaseRaw.toStringAsFixed(2));
      final taxAmount = double.parse(
        (taxableBase * (taxPercent / 100)).toStringAsFixed(2),
      );
      final total = double.parse((taxableBase + taxAmount).toStringAsFixed(2));
      return <String, double>{
        'subtotal': subtotal,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'taxPercent': taxPercent,
        'taxAmount': taxAmount,
        'taxableBase': taxableBase,
        'total': total,
      };
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (ctx, setLocal) {
              // Responsive helpers using Wrap + SizedBox and MediaQuery (no LayoutBuilder),
              // to avoid intrinsic dimension issues inside AlertDialog.
              final screenW = MediaQuery.of(ctx).size.width;
              double contentW(double columns) {
                // Roughly match AlertDialog max width by subtracting insets.
                final inset = 48.0; // default dialog horizontal inset
                final w = (screenW - inset).clamp(280.0, 800.0);
                return (w - (columns - 1) * 8) / columns;
              }

              Widget twoUp(Widget left, Widget right) {
                final twoCols =
                    screenW >= 720; // phones stack; tablets two columns
                final colW = contentW(twoCols ? 2 : 1);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: colW, child: left),
                    SizedBox(width: colW, child: right),
                  ],
                );
              }

              Widget threeUp(Widget a, Widget b, Widget c) {
                if (screenW >= 900) {
                  final w = contentW(3);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: w, child: a),
                      SizedBox(width: w, child: b),
                      SizedBox(width: w, child: c),
                    ],
                  );
                } else if (screenW >= 720) {
                  final half = contentW(2);
                  final full = contentW(1);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: half, child: a),
                      SizedBox(width: half, child: b),
                      SizedBox(width: full, child: c),
                    ],
                  );
                } else {
                  final full = contentW(1);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: full, child: a),
                      SizedBox(width: full, child: b),
                      SizedBox(width: full, child: c),
                    ],
                  );
                }
              }

              final totals = _computeTotals();
              final subtotal = totals['subtotal']!;
              final discountPercent = totals['discountPercent']!;
              final discountAmount = totals['discountAmount']!;
              final taxPercent = totals['taxPercent']!;
              final taxAmount = totals['taxAmount']!;
              final total = totals['total']!;

              final maxDialogH = MediaQuery.of(ctx).size.height * 0.85;
              // Helper: searchable customer picker bottom sheet
              Future<void> _pickCustomer() async {
                final picked = await showModalBottomSheet<Customer>(
                  context: ctx,
                  isScrollControlled: true,
                  useSafeArea: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (bctx) {
                    String q = '';
                    final search = TextEditingController();
                    return SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(bctx).viewInsets.bottom,
                        ),
                        child: StatefulBuilder(
                          builder: (bctx, setSB) {
                            final filtered =
                                _customers.where((c) {
                                  final s = q.trim().toLowerCase();
                                  if (s.isEmpty) return true;
                                  final n = c.name.toLowerCase();
                                  final e = (c.email ?? '').toLowerCase();
                                  return n.contains(s) || e.contains(s);
                                }).toList();
                            final double h = math.min(
                              380,
                              MediaQuery.of(bctx).size.height * 0.55,
                            );
                            return SizedBox(
                              height: h,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: TextField(
                                      controller: search,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        labelText: I18n.t(
                                          context,
                                          'invoices.searchCustomers',
                                        ),
                                        prefixIcon: const Icon(Icons.search),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (v) => setSB(() => q = v),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: filtered.length,
                                      itemBuilder: (_, i) {
                                        final c = filtered[i];
                                        return ListTile(
                                          title: Text(c.name),
                                          subtitle:
                                              c.email != null
                                                  ? Text(c.email!)
                                                  : null,
                                          onTap: () => Navigator.pop(bctx, c),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
                if (picked != null) {
                  setLocal(() {
                    customerId = picked.id;
                    customerCtrl.text = picked.name;
                  });
                }
              }

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: maxDialogH,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                I18n.t(context, 'add.newInvoice'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer & Project
                              twoUp(
                                TextField(
                                  controller: customerCtrl,
                                  readOnly: true,
                                  onTap: _pickCustomer,
                                  decoration: InputDecoration(
                                    labelText: I18n.t(
                                      context,
                                      'invoices.customer',
                                    ),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: const Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                  ),
                                ),
                                DropdownButtonFormField<int?>(
                                  value: projectId,
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        I18n.t(context, 'tx.noProject'),
                                      ),
                                    ),
                                    ..._projects.map(
                                      (p) => DropdownMenuItem<int?>(
                                        value: p.id,
                                        child: Text(p.name),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      (v) => setLocal(() => projectId = v),
                                  decoration: InputDecoration(
                                    labelText: I18n.t(
                                      context,
                                      'tx.projectOptional',
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Dates
                              twoUp(
                                TextField(
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
                                            () =>
                                                issueCtrl.text = formatDate(p),
                                          );
                                      },
                                    ),
                                  ),
                                ),
                                TextField(
                                  readOnly: true,
                                  controller: dueCtrl,
                                  decoration: InputDecoration(
                                    labelText: I18n.t(
                                      context,
                                      'invoices.dueDate',
                                    ),
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

                              const SizedBox(height: 12),
                              // Items header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    I18n.t(context, 'invoices.items'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => setLocal(
                                          () => items.add({
                                            'description': '',
                                            'quantity': 1.0,
                                            'unit_price': 0.0,
                                          }),
                                        ),
                                    child: Text(
                                      I18n.t(context, 'invoices.addItem'),
                                    ),
                                  ),
                                ],
                              ),

                              // Items list
                              Column(
                                children: [
                                  for (int i = 0; i < items.length; i++) ...[
                                    LayoutBuilder(
                                      builder: (ctx, constraints) {
                                        final isNarrow =
                                            constraints.maxWidth < 520;
                                        Widget descField() => TextFormField(
                                          key: ValueKey('desc_$i'),
                                          initialValue:
                                              (items[i]['description']
                                                  as String?) ??
                                              '',
                                          onChanged:
                                              (v) =>
                                                  items[i]['description'] = v,
                                          decoration: InputDecoration(
                                            labelText: I18n.t(
                                              context,
                                              'invoices.description',
                                            ),
                                            border: const OutlineInputBorder(),
                                          ),
                                        );
                                        Widget qtyField() => TextFormField(
                                          key: ValueKey('qty_$i'),
                                          initialValue:
                                              ((items[i]['quantity'] as num?)
                                                      ?.toString() ??
                                                  '1'),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged:
                                              (v) => setLocal(
                                                () =>
                                                    items[i]['quantity'] =
                                                        double.tryParse(v) ??
                                                        0.0,
                                              ),
                                          decoration: InputDecoration(
                                            labelText: I18n.t(
                                              context,
                                              'invoices.qty',
                                            ),
                                            border: const OutlineInputBorder(),
                                          ),
                                        );
                                        Widget priceField() => TextFormField(
                                          key: ValueKey('price_$i'),
                                          initialValue:
                                              ((items[i]['unit_price'] as num?)
                                                      ?.toString() ??
                                                  '0'),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged:
                                              (v) => setLocal(
                                                () =>
                                                    items[i]['unit_price'] =
                                                        double.tryParse(v) ??
                                                        0.0,
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
                                          tooltip: I18n.t(
                                            context,
                                            'label.remove',
                                          ),
                                          icon: const Icon(Icons.close),
                                          onPressed:
                                              () => setLocal(
                                                () => items.removeAt(i),
                                              ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              descField(),
                                              const SizedBox(height: 8),
                                              qtyPriceRow,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: descField(),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: qtyField()),
                                            const SizedBox(width: 8),
                                            Expanded(child: priceField()),
                                            if (items.length > 1) ...[
                                              const SizedBox(width: 8),
                                              removeBtn,
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 8),
                              // Discount / Tax and totals (responsive)
                              threeUp(
                                TextFormField(
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
                                  onChanged: (_) => setLocal(() {}),
                                ),
                                TextFormField(
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
                                  onChanged: (_) => setLocal(() {}),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant
                                        .withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DefaultTextStyle(
                                    style:
                                        Theme.of(context).textTheme.bodySmall!,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              I18n.t(
                                                context,
                                                'invoices.subtotal',
                                              ),
                                            ),
                                            Text(money(subtotal)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${I18n.t(context, 'invoices.discount')} (${discountPercent.toStringAsFixed(2)}%)',
                                            ),
                                            Text('-' + money(discountAmount)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${I18n.t(context, 'invoices.tax')} (${taxPercent.toStringAsFixed(2)}%)',
                                            ),
                                            Text('+' + money(taxAmount)),
                                          ],
                                        ),
                                        const Divider(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              I18n.t(context, 'invoices.total'),
                                            ),
                                            Text(
                                              money(total),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(I18n.t(context, 'label.cancel')),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                if (customerId == null) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.tr(
                                            context,
                                            'invoices.selectCustomer',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                try {
                                  final itemsBody =
                                      items
                                          .map(
                                            (it) => {
                                              'description':
                                                  (it['description'] as String?)
                                                      ?.trim() ??
                                                  I18n.tr(
                                                    context,
                                                    'invoices.itemFallback',
                                                  ),
                                              'quantity':
                                                  ((it['quantity'] as num?) ??
                                                          0)
                                                      .toDouble(),
                                              'unit_price':
                                                  ((it['unit_price'] as num?) ??
                                                          0)
                                                      .toDouble(),
                                            },
                                          )
                                          .toList();
                                  final totalsSnapshot = _computeTotals();
                                  await _data.createInvoice(
                                    customerId: customerId!,
                                    projectId: projectId,
                                    accountId: null,
                                    number: null,
                                    issueDate: ddMmYyyyToYmd(
                                      issueCtrl.text.trim(),
                                    ),
                                    dueDate: ddMmYyyyToYmd(dueCtrl.text.trim()),
                                    discount: totalsSnapshot['discountAmount'],
                                    tax: totalsSnapshot['taxAmount'],
                                    items: itemsBody,
                                  );
                                  if (mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${I18n.tr(context, 'invoices.createFailed')}: $e',
                                        ),
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
                    ],
                  ),
                ),
              );
            },
          ),
    );

    if (ok == true && mounted) {
      context.read<RefreshBus>().notifyInvoices();
      await _load();
    }
  }

  void _openInvoice(InvoiceSummary inv) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => InvoiceDetailScreen(id: inv.id)));
  }

  void _markPaid(InvoiceSummary inv) async {
    if (inv.amountDue <= 0) return;
    int? accountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    final dateCtrl = TextEditingController(text: formatDate(DateTime.now()));
    final amountCtrl = TextEditingController(
      text: inv.amountDue.toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setLocal) => AlertDialog(
                  title: Text(
                    '${I18n.t(context, 'invoices.recordPaymentFor')} ${inv.number.isEmpty ? '#' + inv.id.toString() : inv.number}',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: accountId,
                        items:
                            _accounts
                                .map(
                                  (a) => DropdownMenuItem<int>(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setLocal(() => accountId = v),
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'payments.account'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        readOnly: true,
                        controller: dateCtrl,
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'invoices.date'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined),
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (p != null)
                                setLocal(() => dateCtrl.text = formatDate(p));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: I18n.t(context, 'invoices.amount'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${I18n.t(context, 'invoices.dueAmount')}: ${money(inv.amountDue)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(I18n.t(context, 'label.cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(I18n.t(context, 'invoices.recordPayment')),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true && accountId != null) {
      final amt =
          double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? inv.amountDue;
      await _data.payInvoice(
        id: inv.id,
        date: ddMmYyyyToYmd(dateCtrl.text.trim()),
        amount: amt,
        accountId: accountId!,
      );
      if (mounted) {
        context.read<RefreshBus>().notifyInvoices();
        await _load();
      }
    }
  }

  Future<void> _shareInvoice(InvoiceSummary inv) async {
    final customerEmail = (inv.customerEmail ?? '').trim();
    if (customerEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.tr(context, 'invoices.customerEmailMissing')),
        ),
      );
      return;
    }
    if (_sharingInvoiceId == inv.id) return;

    setState(() => _sharingInvoiceId = inv.id);
    try {
      final detail = await _data.getInvoice(inv.id);
      if (!mounted) return;
      final result = await _emailInvoicePdf(
        context: context,
        data: _data,
        detail: detail,
      );
      if (!mounted) return;
      final emailedTo =
          (result['emailed_to'] as String?)?.trim().isNotEmpty == true
              ? result['emailed_to'] as String
              : customerEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.tr(context, 'invoices.emailSent')} $emailedTo'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.tr(context, 'invoices.emailFailed')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingInvoiceId = null);
      }
    }
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.inv,
    required this.onOpen,
    required this.onPay,
    this.onShare,
    this.isSharing = false,
  });
  final InvoiceSummary inv;
  final VoidCallback onOpen;
  final VoidCallback onPay;
  final VoidCallback? onShare;
  final bool isSharing;
  @override
  Widget build(BuildContext context) {
    final isPaid = inv.amountDue <= 0 || inv.status.toLowerCase() == 'paid';
    final now = DateTime.now();
    final isOverdue =
        inv.dueDate.isBefore(DateTime(now.year, now.month, now.day)) && !isPaid;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark
            ? (isPaid
                ? const Color(0xFF103521)
                : isOverdue
                ? const Color(0xFF3A1C1C)
                : const Color(0xFF3A3618))
            : (isPaid
                ? Colors.green.shade50
                : isOverdue
                ? Colors.red.shade50
                : Colors.yellow.shade50);
    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final raw = inv.number.trim();
                      final label =
                          (raw.isEmpty || raw == '#')
                              ? '#${inv.id}'
                              : (raw.startsWith('#') ? raw : '#$raw');
                      return Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isPaid
                              ? const Color(0xFFE6F7EC)
                              : const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPaid ? I18n.t(context, 'invoices.paid') : inv.status,
                      style: TextStyle(
                        color:
                            isPaid
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onShare != null)
                    isSharing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : IconButton(
                          tooltip: I18n.t(context, 'invoices.share'),
                          icon: const Icon(Icons.ios_share_outlined),
                          onPressed: onShare,
                        ),
                  if (!isPaid)
                    IconButton(
                      tooltip: I18n.t(context, 'invoices.markPaid'),
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: onPay,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${I18n.t(context, 'invoices.customer')}: ${inv.customerName}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'invoices.date'),
                      formatDate(inv.issueDate),
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'invoices.due'),
                      formatDate(inv.dueDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'invoices.total'),
                      money(inv.total),
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'invoices.dueAmount'),
                      money(inv.amountDue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: Theme.of(context).textTheme.bodySmall),
      Text(
        v,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(customer.name),
      subtitle: Text(customer.email ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// Simple invoice detail view (read-only)
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  int _reload = 0;
  bool _sharing = false;
  void _refresh() => setState(() => _reload++);

  Future<void> _shareInvoice(DataService data, InvoiceDetail detail) async {
    final customerEmail = (detail.invoice.customerEmail ?? '').trim();
    if (customerEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.tr(context, 'invoices.customerEmailMissing')),
        ),
      );
      return;
    }
    if (_sharing) return;

    setState(() => _sharing = true);
    try {
      if (!mounted) return;
      final result = await _emailInvoicePdf(
        context: context,
        data: data,
        detail: detail,
      );
      if (!mounted) return;
      final emailedTo =
          (result['emailed_to'] as String?)?.trim().isNotEmpty == true
              ? result['emailed_to'] as String
              : customerEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.tr(context, 'invoices.emailSent')} $emailedTo'),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.tr(context, 'invoices.emailFailed')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return Scaffold(
        appBar: AppBar(title: Text(I18n.t(context, 'title.invoices'))),
        body: const ProBlock(feature: 'Invoices'),
      );
    }
    final api = ApiClient()..setToken(store.token);
    final data = DataService(api);
    return FutureBuilder<InvoiceDetail>(
      key: ValueKey(_reload),
      future: data.getInvoice(widget.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Error: ${snap.error}')),
            );
          }
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final d = snap.data!;
        final inv = d.invoice;
        final subtotalAmount = inv.subtotal;
        final discountAmount = inv.discount;
        final taxableBaseAmount = math.max(subtotalAmount - discountAmount, 0);
        final taxAmount = inv.tax;
        final discountPercentDisplay =
            subtotalAmount > 0 ? (discountAmount / subtotalAmount) * 100 : 0;
        final taxPercentDisplay =
            taxableBaseAmount > 0 ? (taxAmount / taxableBaseAmount) * 100 : 0;
        final label = invoiceDisplayNumber(inv);

        return Scaffold(
          appBar: AppBar(
            title: Text('${I18n.t(context, 'invoices.invoice')} $label'),
            actions: [
              if ((inv.customerEmail ?? '').trim().isNotEmpty)
                _sharing
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : IconButton(
                      tooltip: I18n.t(context, 'invoices.share'),
                      icon: const Icon(Icons.ios_share_outlined),
                      onPressed: () => _shareInvoice(data, d),
                    ),
              if (inv.status.toLowerCase() != 'paid' &&
                  inv.status.toLowerCase() != 'void')
                IconButton(
                  tooltip: I18n.t(context, 'invoices.editInvoice'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditInvoiceScreen(detail: d),
                      ),
                    );
                    if (saved == true) _refresh();
                  },
                ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final itemsCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        I18n.t(context, 'invoices.items'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                I18n.t(context, 'invoices.description'),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(I18n.t(context, 'invoices.qty')),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                I18n.t(context, 'invoices.unitPrice'),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(I18n.t(context, 'invoices.amount')),
                            ),
                          ],
                        ),
                      ),
                      ...d.items.map(
                        (it) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 5, child: Text(it.description)),
                              Expanded(
                                flex: 2,
                                child: Text(it.quantity.toStringAsFixed(0)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(money(it.unitPrice)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(money(it.amount)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _kvRow(
                                context,
                                I18n.t(context, 'invoices.subtotal'),
                                money(inv.subtotal),
                              ),
                              _kvRow(
                                context,
                                '${I18n.t(context, 'invoices.discount')} (${discountPercentDisplay.toStringAsFixed(2)}%)',
                                '-${money(inv.discount)}',
                              ),
                              _kvRow(
                                context,
                                '${I18n.t(context, 'invoices.tax')} (${taxPercentDisplay.toStringAsFixed(2)}%)',
                                '+${money(inv.tax)}',
                              ),
                              const Divider(height: 12),
                              _kvRow(
                                context,
                                I18n.t(context, 'invoices.total'),
                                money(inv.total),
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final sidebar = Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Details',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      inv.status.toLowerCase() == 'paid'
                                          ? const Color(0xFFE6F7EC)
                                          : const Color(0xFFE5F0FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  inv.status,
                                  style: TextStyle(
                                    color:
                                        inv.status.toLowerCase() == 'paid'
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Customer: ${inv.customerName}'),
                          const SizedBox(height: 6),
                          Text(
                            'Issue: ${formatDate(inv.issueDate)}  |  Due: ${formatDate(inv.dueDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          _kvRow(
                            context,
                            I18n.t(context, 'invoices.total'),
                            money(inv.total),
                            isBold: true,
                          ),
                          _kvRow(
                            context,
                            I18n.t(context, 'invoices.dueAmount'),
                            money(inv.amountDue),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder:
                                    (dialogCtx) => AlertDialog(
                                      title: Text(
                                        I18n.t(
                                          context,
                                          'invoices.deleteInvoiceTitle',
                                        ),
                                      ),
                                      content: Text(
                                        I18n.t(
                                          context,
                                          'invoices.deleteInvoiceNotice',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                dialogCtx,
                                              ).pop(false),
                                          child: Text(
                                            I18n.t(context, 'label.cancel'),
                                          ),
                                        ),
                                        FilledButton(
                                          onPressed:
                                              () => Navigator.of(
                                                dialogCtx,
                                              ).pop(true),
                                          child: Text(
                                            I18n.t(context, 'label.delete'),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (yes == true) {
                                await data.deleteInvoice(inv.id);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${I18n.t(context, 'label.delete')} ${I18n.t(context, 'invoices.invoice')}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            I18n.t(context, 'nav.payments'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (d.payments.isEmpty)
                            Text(I18n.t(context, 'invoices.noPayments'))
                          else
                            ...d.payments.map(
                              (p) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(formatYmd(p.date)),
                                          if (p.accountName != null)
                                            Text(
                                              'Deposited to: ${p.accountName}',
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      money(p.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: itemsCard),
                      const SizedBox(width: 12),
                      Expanded(flex: 1, child: sidebar),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Invoice $label',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      inv.status.toLowerCase() == 'paid'
                                          ? const Color(0xFFE6F7EC)
                                          : const Color(0xFFE5F0FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  inv.status,
                                  style: TextStyle(
                                    color:
                                        inv.status.toLowerCase() == 'paid'
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Issue: ${formatDate(inv.issueDate)}  •  Due: ${formatDate(inv.dueDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Total: ',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                money(inv.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Amount Due: ',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(money(inv.amountDue)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  itemsCard,
                  const SizedBox(height: 12),
                  sidebar,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

Widget _kvRow(BuildContext context, String k, String v, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        Text(
          v,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// --- Edit Invoice Screen ---
class EditInvoiceScreen extends StatefulWidget {
  const EditInvoiceScreen({super.key, required this.detail});
  final InvoiceDetail detail;

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  late final DataService _data;
  List<Customer> _customers = [];
  List<Project> _projects = [];

  late int _customerId;
  int? _projectId;
  late TextEditingController _issueCtrl;
  late TextEditingController _dueCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _taxCtrl;
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    final api = ApiClient()..setToken(context.read<AuthStore>().token);
    _data = DataService(api);
    final inv = widget.detail.invoice;
    _customerId = _findCustomerIdFromName(inv.customerName);
    _projectId = null; // not shown in detail; keep null
    _issueCtrl = TextEditingController(text: formatDate(inv.issueDate));
    _dueCtrl = TextEditingController(text: formatDate(inv.dueDate));
    final subtotal = inv.subtotal;
    final discountPercent = subtotal > 0 ? (inv.discount / subtotal) * 100 : 0;
    final subtotalAfterDiscount = math.max(subtotal - inv.discount, 0);
    final taxPercent =
        subtotalAfterDiscount > 0 ? (inv.tax / subtotalAfterDiscount) * 100 : 0;
    _discountCtrl = TextEditingController(
      text: discountPercent.isFinite ? discountPercent.toStringAsFixed(2) : '0',
    );
    _taxCtrl = TextEditingController(
      text: taxPercent.isFinite ? taxPercent.toStringAsFixed(2) : '0',
    );
    _items =
        widget.detail.items
            .map(
              (e) => {
                'description': e.description,
                'quantity': e.quantity,
                'unit_price': e.unitPrice,
              },
            )
            .toList();
    _loadLists();
  }

  int _findCustomerIdFromName(String name) {
    // will be updated after customers are fetched
    return 0;
  }

  Future<void> _loadLists() async {
    final res = await Future.wait([_data.getCustomers(), _data.getProjects()]);
    setState(() {
      _customers = res[0] as List<Customer>;
      _projects = res[1] as List<Project>;
      if (_customerId == 0 && _customers.isNotEmpty) {
        final match = _customers.firstWhere(
          (c) => c.name == widget.detail.invoice.customerName,
          orElse: () => _customers.first,
        );
        _customerId = match.id;
      }
    });
  }

  double get _subtotal => _items.fold<double>(0.0, (s, it) {
    final q = (it['quantity'] as num?)?.toDouble() ?? 0.0;
    final p = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
    return s + (q * p);
  });

  double get _discountPercent {
    final raw = double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (!raw.isFinite) return 0.0;
    return raw.clamp(0, 100).toDouble();
  }

  double get _taxPercent {
    final raw = double.tryParse(_taxCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (!raw.isFinite) return 0.0;
    return raw < 0 ? 0.0 : raw;
  }

  double get _discountAmount =>
      double.parse((_subtotal * (_discountPercent / 100)).toStringAsFixed(2));

  double get _taxableBase => math.max(_subtotal - _discountAmount, 0);

  double get _taxAmount =>
      double.parse((_taxableBase * (_taxPercent / 100)).toStringAsFixed(2));

  double get _total =>
      double.parse((_taxableBase + _taxAmount).toStringAsFixed(2));

  Future<void> _save() async {
    final cleanItems =
        _items
            .map(
              (it) => {
                'description':
                    (it['description'] as String?)?.trim().isEmpty == true
                        ? I18n.tr(context, 'invoices.itemFallback')
                        : (it['description'] as String?)?.trim() ??
                            I18n.tr(context, 'invoices.itemFallback'),
                'quantity': (it['quantity'] as num?)?.toDouble() ?? 0.0,
                'unit_price': (it['unit_price'] as num?)?.toDouble() ?? 0.0,
              },
            )
            .where(
              (it) =>
                  ((it['quantity'] as double) > 0) ||
                  ((it['unit_price'] as double) > 0),
            )
            .toList();
    if (cleanItems.isEmpty) {
      cleanItems.add({
        'description': I18n.tr(context, 'invoices.itemFallback'),
        'quantity': 1.0,
        'unit_price': 0.0,
      });
    }
    await _data.updateInvoice(
      id: widget.detail.invoice.id,
      customerId: _customerId,
      projectId: _projectId,
      issueDate: ddMmYyyyToYmd(_issueCtrl.text.trim()),
      dueDate: ddMmYyyyToYmd(_dueCtrl.text.trim()),
      items: cleanItems,
      discount: _discountAmount,
      tax: _taxAmount,
    );
    if (mounted) {
      context.read<RefreshBus>().notifyInvoices();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.detail.invoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${I18n.t(context, 'invoices.editInvoice')} ${inv.number.isEmpty ? '#' + inv.id.toString() : inv.number}',
        ),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value:
                _customerId == 0 && _customers.isNotEmpty
                    ? _customers.first.id
                    : _customerId,
            items:
                _customers
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _customerId = v ?? _customerId),
            decoration: InputDecoration(
              labelText: I18n.t(context, 'invoices.customer'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _projectId,
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(I18n.t(context, 'tx.noProject')),
              ),
              ..._projects.map(
                (p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
              ),
            ],
            onChanged: (v) => setState(() => _projectId = v),
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
                  controller: _issueCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'invoices.issueDate'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: inv.issueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null)
                          setState(() => _issueCtrl.text = formatDate(p));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dueCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: I18n.t(context, 'invoices.dueDate'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: inv.dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null)
                          setState(() => _dueCtrl.text = formatDate(p));
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.t(context, 'invoices.items'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed:
                    () => setState(
                      () => _items.add({
                        'description': '',
                        'quantity': 1.0,
                        'unit_price': 0.0,
                      }),
                    ),
                child: Text(I18n.t(context, 'invoices.addItem')),
              ),
            ],
          ),
          ...List.generate(
            _items.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  Widget descField() => TextFormField(
                    initialValue: (_items[i]['description'] as String?) ?? '',
                    onChanged: (v) => _items[i]['description'] = v,
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invoices.description'),
                      border: const OutlineInputBorder(),
                    ),
                  );
                  Widget qtyField() => TextFormField(
                    initialValue:
                        (_items[i]['quantity'] as num?)?.toString() ?? '1',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged:
                        (v) => setState(
                          () =>
                              _items[i]['quantity'] = double.tryParse(v) ?? 0.0,
                        ),
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invoices.qty'),
                      border: const OutlineInputBorder(),
                    ),
                  );
                  Widget priceField() => TextFormField(
                    initialValue:
                        (_items[i]['unit_price'] as num?)?.toString() ?? '0',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged:
                        (v) => setState(
                          () =>
                              _items[i]['unit_price'] =
                                  double.tryParse(v) ?? 0.0,
                        ),
                    decoration: InputDecoration(
                      labelText: I18n.t(context, 'invoices.unitPrice'),
                      border: const OutlineInputBorder(),
                    ),
                  );
                  final removeBtn = IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  );
                  final qtyPriceRow = Row(
                    children: [
                      Expanded(child: qtyField()),
                      const SizedBox(width: 8),
                      Expanded(child: priceField()),
                      if (_items.length > 1) ...[
                        const SizedBox(width: 6),
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
                      if (_items.length > 1) ...[
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
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${I18n.t(context, 'invoices.discount')} (%)',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _taxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${I18n.t(context, 'invoices.tax')} (%)',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _kvRow(
                    context,
                    I18n.t(context, 'invoices.subtotal'),
                    money(_subtotal),
                  ),
                  _kvRow(
                    context,
                    '${I18n.t(context, 'invoices.discount')} (${_discountPercent.toStringAsFixed(2)}%)',
                    '-${money(_discountAmount)}',
                  ),
                  _kvRow(
                    context,
                    '${I18n.t(context, 'invoices.tax')} (${_taxPercent.toStringAsFixed(2)}%)',
                    '+${money(_taxAmount)}',
                  ),
                  const Divider(height: 12),
                  _kvRow(
                    context,
                    I18n.t(context, 'invoices.total'),
                    money(_total),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(I18n.t(context, 'tx.saveChanges')),
          ),
        ],
      ),
    );
  }
}
