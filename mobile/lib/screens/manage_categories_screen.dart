import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../utils/category_icons.dart';
import '../widgets/pro_widgets.dart';
import '../i18n.dart';
import '../widgets/onboarding_coach.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({
    super.key,
    this.forceCreate = false,
    this.onCategoryCreated,
    this.onSubcategoryCreated,
  });

  final bool forceCreate;
  final VoidCallback? onCategoryCreated;
  final VoidCallback? onSubcategoryCreated;

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  DataService? _data;
  bool _loading = true;
  bool _initialized = false;
  List<ExpenseCategory> _categories = [];
  bool _dismissedCoach = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final token = context.read<AuthStore>().token;
    _data = DataService(ApiClient()..setToken(token));
    _load();
  }

  Future<void> _load() async {
    if (_data == null) return;
    setState(() => _loading = true);
    try {
      final categories = await _data!.getExpenseCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replaceCategory(ExpenseCategory category) {
    setState(() {
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        _categories[index] = category;
      } else {
        _categories = [..._categories, category];
      }
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  Future<void> _openCategoryDialog({ExpenseCategory? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    String iconKey = category?.icon ?? kCategoryIconOptions.first.key;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(category == null
                  ? I18n.tr(context, 'categories.newCategory')
                  : I18n.tr(context, 'categories.editCategory')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: I18n.tr(context, 'label.name'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(I18n.tr(context, 'categories.iconLabel'), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickIcon(initial: iconKey);
                      if (picked != null) {
                        setState(() => iconKey = picked);
                      }
                    },
                    icon: Icon(iconDataFromKey(iconKey)),
                    label: Text(categoryIconByKey(iconKey).label),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(I18n.tr(context, 'label.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(I18n.tr(context, 'categories.validationName'))),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(I18n.tr(context, 'label.save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || _data == null) return;
    try {
      if (category == null) {
        final created = await _data!.createExpenseCategory(name: nameCtrl.text.trim(), icon: iconKey);
        if (!mounted) return;
        _replaceCategory(created);
        widget.onCategoryCreated?.call();
      } else {
        final updated = await _data!.updateExpenseCategory(id: category.id, name: nameCtrl.text.trim(), icon: iconKey);
        if (!mounted) return;
        _replaceCategory(updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    }
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    if (_data == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.tr(context, 'categories.deleteCategory')),
        content: Text(I18n.tr(context, 'categories.deleteCategoryConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(I18n.tr(context, 'label.cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(I18n.tr(context, 'label.delete'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _data!.deleteExpenseCategory(category.id);
      if (!mounted) return;
      setState(() => _categories = _categories.where((c) => c.id != category.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    }
  }

  Future<void> _openSubcategoryDialog(ExpenseCategory category, {ExpenseSubcategory? subcategory}) async {
    if (_data == null) return;
    final nameCtrl = TextEditingController(text: subcategory?.name ?? '');
    String iconKey = subcategory?.icon ?? kCategoryIconOptions.first.key;
    final isPro = context.read<AuthStore>().isProOrExempt;
    final initialBudget = subcategory?.budget ?? 0;
    final budgetCtrl = TextEditingController(
      text: initialBudget > 0 ? initialBudget.toStringAsFixed(2) : '',
    );

    double? parseBudget(String raw) {
      final cleaned = raw.trim().replaceAll(',', '');
      if (cleaned.isEmpty) return 0;
      return double.tryParse(cleaned);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(subcategory == null
              ? I18n.tr(context, 'categories.newSubcategory')
              : I18n.tr(context, 'categories.editSubcategory')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: I18n.tr(context, 'label.name')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    I18n.tr(context, 'categories.monthlyBudget'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!isPro) ...[
                    const SizedBox(width: 6),
                    const ProMiniChip(),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: budgetCtrl,
                enabled: isPro,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: I18n.tr(context, 'categories.monthlyBudgetHint'),
                ),
              ),
              if (!isPro) ...[
                const SizedBox(height: 6),
                Text(
                  I18n.tr(context, 'categories.budgetProOnly'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(I18n.tr(context, 'categories.iconLabel'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickIcon(initial: iconKey);
                  if (picked != null) setState(() => iconKey = picked);
                },
                icon: Icon(iconDataFromKey(iconKey)),
                label: Text(categoryIconByKey(iconKey).label),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(I18n.tr(context, 'label.cancel'))),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(I18n.tr(context, 'categories.validationName'))),
                  );
                  return;
                }
                final parsedBudget = parseBudget(budgetCtrl.text);
                if (parsedBudget == null || parsedBudget < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(I18n.tr(context, 'categories.validationBudget'))),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(I18n.tr(context, 'label.save')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      final double parsedBudget = parseBudget(budgetCtrl.text) ?? 0.0;
      final double budgetValue = isPro ? parsedBudget : 0.0;
      ExpenseCategory updated;
      if (subcategory == null) {
        updated = await _data!.createExpenseSubcategory(
          categoryId: category.id,
          name: nameCtrl.text.trim(),
          icon: iconKey,
          budget: budgetValue,
        );
        widget.onSubcategoryCreated?.call();
      } else {
        updated = await _data!.updateExpenseSubcategory(
          id: subcategory.id,
          name: nameCtrl.text.trim(),
          icon: iconKey,
          budget: budgetValue,
        );
      }
      if (!mounted) return;
      _replaceCategory(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    }
  }

  Future<void> _deleteSubcategory(ExpenseCategory category, ExpenseSubcategory subcategory) async {
    if (_data == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.tr(context, 'categories.deleteSubcategory')),
        content: Text(I18n.tr(context, 'categories.deleteSubcategoryConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(I18n.tr(context, 'label.cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(I18n.tr(context, 'label.delete'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final updated = await _data!.deleteExpenseSubcategory(subcategory.id);
      if (!mounted) return;
      if (updated != null) {
        _replaceCategory(updated);
      } else {
        // Fallback: remove from local list
        _replaceCategory(
          ExpenseCategory(
            id: category.id,
            name: category.name,
            icon: category.icon,
            subcategories: category.subcategories.where((s) => s.id != subcategory.id).toList(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    }
  }

  Future<String?> _pickIcon({String? initial}) async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: kCategoryIconOptions.length,
            itemBuilder: (ctx, index) {
              final option = kCategoryIconOptions[index];
              final selected = option.key == initial;
              return InkWell(
                onTap: () => Navigator.of(ctx).pop(option.key),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(option.icon, color: selected ? Theme.of(context).colorScheme.primary : null),
                      const SizedBox(height: 8),
                      Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget? _buildOnboardingBanner() {
    if (!widget.forceCreate || _loading) return null;
    final hasCategory = _categories.isNotEmpty;
    final hasSubcategory =
        _categories.any((c) => c.subcategories.isNotEmpty);
    if (hasSubcategory) return null;
    final message =
        hasCategory
            ? I18n.tr(context, 'onboarding.createFirstSubcategory')
            : I18n.tr(context, 'onboarding.createFirstCategory');
    return Card(
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
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _onboardingMessage() {
    if (!widget.forceCreate || _loading) return null;
    final hasCategory = _categories.isNotEmpty;
    final hasSubcategory =
        _categories.any((c) => c.subcategories.isNotEmpty);
    if (hasSubcategory) return null;
    return hasCategory
        ? I18n.tr(context, 'onboarding.createFirstSubcategory')
        : I18n.tr(context, 'onboarding.createFirstCategory');
  }

  Widget _buildOnboardingCoach() {
    final message = _onboardingMessage();
    if (message == null || _dismissedCoach) return const SizedBox.shrink();
    return OnboardingCoach(
      message: message,
      onOk: () => setState(() => _dismissedCoach = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _buildOnboardingBanner();
    final content =
        _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: _load,
              child: _categories.isEmpty
                  ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (banner != null) ...[
                        banner,
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Text(I18n.tr(context, 'categories.empty')),
                        ),
                      ),
                    ],
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length + (banner != null ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      if (banner != null && index == 0) {
                        return Column(
                          children: [banner, const SizedBox(height: 12)],
                        );
                      }
                      final categoryIndex = index - (banner != null ? 1 : 0);
                      final category = _categories[categoryIndex];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Icon(iconDataFromKey(category.icon)),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Row(
                            children: [
                              Expanded(child: Text(category.name)),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _openCategoryDialog(category: category);
                                      break;
                                    case 'delete':
                                      _deleteCategory(category);
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(I18n.tr(context, 'label.edit')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(I18n.tr(context, 'label.delete')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            if (category.subcategories.isEmpty)
                              ListTile(
                                title: Text(
                                  I18n.tr(context, 'categories.noSubcategories'),
                                ),
                              ),
                            ...category.subcategories.map(
                              (sub) => ListTile(
                                leading: Icon(iconDataFromKey(sub.icon)),
                                title: Text(sub.name),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed:
                                          () => _openSubcategoryDialog(
                                            category,
                                            subcategory: sub,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed:
                                          () => _deleteSubcategory(
                                            category,
                                            sub,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _openSubcategoryDialog(category),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  I18n.tr(context, 'categories.addSubcategory'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
            );
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(context, 'categories.manageTitle')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          content,
          if (widget.forceCreate) _buildOnboardingCoach(),
        ],
      ),
    );
  }
}
