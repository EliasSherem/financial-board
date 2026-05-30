import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../ui/finsight_ui.dart';
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
      _categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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
              title: Text(
                category == null
                    ? I18n.tr(context, 'categories.newCategory')
                    : I18n.tr(context, 'categories.editCategory'),
              ),
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
                  Text(
                    I18n.tr(context, 'categories.iconLabel'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _IconPickerButton(
                    onPressed: () async {
                      final picked = await _pickIcon(initial: iconKey);
                      if (picked != null) {
                        setState(() => iconKey = picked);
                      }
                    },
                    icon: Icon(iconDataFromKey(iconKey)),
                    label: categoryIconByKey(iconKey).label,
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
                        SnackBar(
                          content: Text(
                            I18n.tr(context, 'categories.validationName'),
                          ),
                        ),
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
        final created = await _data!.createExpenseCategory(
          name: nameCtrl.text.trim(),
          icon: iconKey,
        );
        if (!mounted) return;
        _replaceCategory(created);
        widget.onCategoryCreated?.call();
      } else {
        final updated = await _data!.updateExpenseCategory(
          id: category.id,
          name: nameCtrl.text.trim(),
          icon: iconKey,
        );
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
      builder:
          (ctx) => AlertDialog(
            title: Text(I18n.tr(context, 'categories.deleteCategory')),
            content: Text(I18n.tr(context, 'categories.deleteCategoryConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(I18n.tr(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: FSColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(I18n.tr(context, 'label.delete')),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      await _data!.deleteExpenseCategory(category.id);
      if (!mounted) return;
      setState(
        () =>
            _categories =
                _categories.where((c) => c.id != category.id).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(context, 'label.failed')}: $e')),
      );
    }
  }

  Future<void> _openSubcategoryDialog(
    ExpenseCategory category, {
    ExpenseSubcategory? subcategory,
  }) async {
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
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: Text(
                    subcategory == null
                        ? I18n.tr(context, 'categories.newSubcategory')
                        : I18n.tr(context, 'categories.editSubcategory'),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: I18n.tr(context, 'label.name'),
                        ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: I18n.tr(
                            context,
                            'categories.monthlyBudgetHint',
                          ),
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
                      Text(
                        I18n.tr(context, 'categories.iconLabel'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _IconPickerButton(
                        onPressed: () async {
                          final picked = await _pickIcon(initial: iconKey);
                          if (picked != null) setState(() => iconKey = picked);
                        },
                        icon: Icon(iconDataFromKey(iconKey)),
                        label: categoryIconByKey(iconKey).label,
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
                            SnackBar(
                              content: Text(
                                I18n.tr(context, 'categories.validationName'),
                              ),
                            ),
                          );
                          return;
                        }
                        final parsedBudget = parseBudget(budgetCtrl.text);
                        if (parsedBudget == null || parsedBudget < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                I18n.tr(context, 'categories.validationBudget'),
                              ),
                            ),
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

  Future<void> _deleteSubcategory(
    ExpenseCategory category,
    ExpenseSubcategory subcategory,
  ) async {
    if (_data == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(I18n.tr(context, 'categories.deleteSubcategory')),
            content: Text(
              I18n.tr(context, 'categories.deleteSubcategoryConfirm'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(I18n.tr(context, 'label.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: FSColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(I18n.tr(context, 'label.delete')),
              ),
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
            subcategories:
                category.subcategories
                    .where((s) => s.id != subcategory.id)
                    .toList(),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FSBottomSheetShell(
          title: I18n.tr(context, 'categories.iconLabel'),
          scrollable: false,
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: FSSpacing.md,
              mainAxisSpacing: FSSpacing.md,
            ),
            itemCount: kCategoryIconOptions.length,
            itemBuilder: (ctx, index) {
              final option = kCategoryIconOptions[index];
              final selected = option.key == initial;
              return InkWell(
                onTap: () => Navigator.of(ctx).pop(option.key),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? FSColors.intentContainer(
                              context,
                              FSIntent.primary,
                            )
                            : FSColors.surface(context),
                    border: Border.all(
                      color:
                          selected
                              ? FSColors.primary
                              : FSColors.border(context),
                    ),
                    borderRadius: BorderRadius.circular(FSRadius.lg),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option.icon,
                        color:
                            selected
                                ? FSColors.primary
                                : FSColors.mutedText(context),
                      ),
                      const SizedBox(height: FSSpacing.sm),
                      Text(
                        option.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : FSColors.mutedText(context),
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
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
    final hasSubcategory = _categories.any((c) => c.subcategories.isNotEmpty);
    if (hasSubcategory) return null;
    final message =
        hasCategory
            ? I18n.tr(context, 'onboarding.createFirstSubcategory')
            : I18n.tr(context, 'onboarding.createFirstCategory');
    return FSCard(
      variant: FSCardVariant.subtle,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, FSIntent.primary),
              borderRadius: BorderRadius.circular(FSRadius.md),
            ),
            child: const Icon(Icons.flag_outlined, color: FSColors.primary),
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _onboardingMessage() {
    if (!widget.forceCreate || _loading) return null;
    final hasCategory = _categories.isNotEmpty;
    final hasSubcategory = _categories.any((c) => c.subcategories.isNotEmpty);
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
            ? const FSLoadingState()
            : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  FSSpacing.lg,
                  FSSpacing.lg,
                  FSSpacing.lg,
                  FSSpacing.xxl,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FSButton(
                      label: I18n.tr(context, 'categories.newCategory'),
                      icon: Icons.add_rounded,
                      size: FSButtonSize.sm,
                      onPressed: () => _openCategoryDialog(),
                    ),
                  ),
                  const SizedBox(height: FSSpacing.md),
                  if (banner != null) ...[
                    banner,
                    const SizedBox(height: FSSpacing.md),
                  ],
                  if (_categories.isEmpty)
                    FSCard(
                      variant: FSCardVariant.elevated,
                      child: FSEmptyState(
                        icon: Icons.category_outlined,
                        title: I18n.tr(context, 'categories.empty'),
                        action: FSButton(
                          label: I18n.tr(context, 'categories.newCategory'),
                          icon: Icons.add_rounded,
                          onPressed: () => _openCategoryDialog(),
                        ),
                      ),
                    )
                  else
                    ..._categories.map(
                      (category) => _CategoryCard(
                        category: category,
                        onEditCategory:
                            () => _openCategoryDialog(category: category),
                        onDeleteCategory: () => _deleteCategory(category),
                        onAddSubcategory:
                            () => _openSubcategoryDialog(category),
                        onEditSubcategory:
                            (subcategory) => _openSubcategoryDialog(
                              category,
                              subcategory: subcategory,
                            ),
                        onDeleteSubcategory:
                            (subcategory) =>
                                _deleteSubcategory(category, subcategory),
                      ),
                    ),
                ],
              ),
            );
    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(
        title: Text(I18n.tr(context, 'categories.manageTitle')),
        backgroundColor: FSColors.background(context),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: Stack(
        children: [content, if (widget.forceCreate) _buildOnboardingCoach()],
      ),
    );
  }
}

class _IconPickerButton extends StatelessWidget {
  const _IconPickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FSCard(
      onTap: onPressed,
      variant: FSCardVariant.interactive,
      padding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.md,
        vertical: FSSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, FSIntent.primary),
              borderRadius: BorderRadius.circular(FSRadius.md),
              border: Border.all(
                color: FSColors.intentBorder(context, FSIntent.primary),
              ),
            ),
            child: IconTheme(
              data: const IconThemeData(color: FSColors.primary, size: 20),
              child: icon,
            ),
          ),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: FSColors.mutedText(context),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
  });

  final ExpenseCategory category;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddSubcategory;
  final ValueChanged<ExpenseSubcategory> onEditSubcategory;
  final ValueChanged<ExpenseSubcategory> onDeleteSubcategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.md),
      child: FSCard(
        padding: EdgeInsets.zero,
        variant: FSCardVariant.interactive,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(
              FSSpacing.lg,
              FSSpacing.sm,
              FSSpacing.sm,
              FSSpacing.sm,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              FSSpacing.lg,
              0,
              FSSpacing.lg,
              FSSpacing.lg,
            ),
            leading: _CategoryIconBadge(icon: iconDataFromKey(category.icon)),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: FSSpacing.sm),
                FSStatusBadge(
                  label: category.subcategories.length.toString(),
                  variant:
                      category.subcategories.isEmpty
                          ? FSStatusBadgeVariant.neutral
                          : FSStatusBadgeVariant.info,
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(width: FSSpacing.xs),
                PopupMenuButton<String>(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEditCategory();
                        break;
                      case 'delete':
                        onDeleteCategory();
                        break;
                    }
                  },
                  itemBuilder:
                      (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 18),
                              const SizedBox(width: FSSpacing.sm),
                              Text(I18n.tr(context, 'label.edit')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18),
                              const SizedBox(width: FSSpacing.sm),
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
                _EmptySubcategoriesCard(
                  message: I18n.tr(context, 'categories.noSubcategories'),
                )
              else
                ...category.subcategories.map(
                  (sub) => _SubcategoryRow(
                    subcategory: sub,
                    onEdit: () => onEditSubcategory(sub),
                    onDelete: () => onDeleteSubcategory(sub),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FSButton(
                  label: I18n.tr(context, 'categories.addSubcategory'),
                  icon: Icons.add_rounded,
                  variant: FSButtonVariant.outline,
                  size: FSButtonSize.sm,
                  onPressed: onAddSubcategory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.subcategory,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseSubcategory subcategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FSSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(FSSpacing.md),
        decoration: BoxDecoration(
          color:
              FSColors.isDark(context)
                  ? FSColors.alpha(FSColors.surfaceDark, 0.68)
                  : FSColors.backgroundLight,
          borderRadius: BorderRadius.circular(FSRadius.lg),
          border: Border.all(color: FSColors.border(context)),
        ),
        child: Row(
          children: [
            _CategoryIconBadge(
              icon: iconDataFromKey(subcategory.icon),
              size: 36,
              iconSize: 18,
              intent: FSIntent.info,
            ),
            const SizedBox(width: FSSpacing.md),
            Expanded(
              child: Text(
                subcategory.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: FSSpacing.sm),
            _CategoryActionButton(
              tooltip: I18n.tr(context, 'label.edit'),
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
            const SizedBox(width: FSSpacing.xs),
            _CategoryActionButton(
              tooltip: I18n.tr(context, 'label.delete'),
              icon: Icons.delete_outline,
              danger: true,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySubcategoriesCard extends StatelessWidget {
  const _EmptySubcategoriesCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: FSSpacing.md),
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.sell_outlined, color: FSColors.mutedText(context)),
          const SizedBox(width: FSSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FSColors.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  const _CategoryIconBadge({
    required this.icon,
    this.size = 42,
    this.iconSize = 21,
    this.intent = FSIntent.primary,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final FSIntent intent;

  @override
  Widget build(BuildContext context) {
    final color = FSColors.intent(intent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FSColors.intentContainer(context, intent),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(color: FSColors.intentBorder(context, intent)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _CategoryActionButton extends StatelessWidget {
  const _CategoryActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? FSColors.danger : Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(38),
        backgroundColor: FSColors.alpha(color, 0.10),
        foregroundColor: color,
        side: BorderSide(color: FSColors.alpha(color, 0.18)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FSRadius.md),
        ),
      ),
    );
  }
}
