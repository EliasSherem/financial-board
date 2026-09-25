import '../services/analytics_service.dart';
import '../momentum/widgets.dart';
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
import '../liquid_glass/liquid_glass.dart';
import '../widgets/non_pro_interstitial_ad_controller.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AnalyticsService.instance.screen('categories');
    });
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
    NonProInterstitialAdController.preloadIfEligible(context);
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    String iconKey = category?.icon ?? kCategoryIconOptions.first.key;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: LGColors.surfaceSolid(context),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LGRadius.xl),
                side: BorderSide(
                  color: LGColors.textSecondary(
                    context,
                  ).withValues(alpha: 0.14),
                ),
              ),
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
                    decoration: LGForm.solidInputDecoration(
                      context,
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
                LGButton(
                  label: I18n.tr(context, 'label.cancel'),
                  size: LGButtonSize.sm,
                  variant: LGButtonVariant.outline,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                LGButton(
                  label: I18n.tr(context, 'label.save'),
                  size: LGButtonSize.sm,
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
        await NonProInterstitialAdController.recordSuccessfulMutation(context);
      } else {
        final updated = await _data!.updateExpenseCategory(
          id: category.id,
          name: nameCtrl.text.trim(),
          icon: iconKey,
        );
        if (!mounted) return;
        _replaceCategory(updated);
        await NonProInterstitialAdController.recordSuccessfulMutation(context);
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
            backgroundColor: LGColors.surfaceSolid(context),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LGRadius.xl),
              side: BorderSide(
                color: LGColors.textSecondary(context).withValues(alpha: 0.14),
              ),
            ),
            title: Text(I18n.tr(context, 'categories.deleteCategory')),
            content: Text(I18n.tr(context, 'categories.deleteCategoryConfirm')),
            actions: [
              LGButton(
                label: I18n.tr(context, 'label.cancel'),
                size: LGButtonSize.sm,
                variant: LGButtonVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              _SoftDangerButton(
                label: I18n.tr(context, 'label.delete'),
                onPressed: () => Navigator.of(ctx).pop(true),
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
    NonProInterstitialAdController.preloadIfEligible(context);
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
                  backgroundColor: LGColors.surfaceSolid(context),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LGRadius.xl),
                    side: BorderSide(
                      color: LGColors.textSecondary(
                        context,
                      ).withValues(alpha: 0.14),
                    ),
                  ),
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
                        decoration: LGForm.solidInputDecoration(
                          context,
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
                        decoration: LGForm.solidInputDecoration(
                          context,
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
                    LGButton(
                      label: I18n.tr(context, 'label.cancel'),
                      size: LGButtonSize.sm,
                      variant: LGButtonVariant.outline,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    LGButton(
                      label: I18n.tr(context, 'label.save'),
                      size: LGButtonSize.sm,
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
      await NonProInterstitialAdController.recordSuccessfulMutation(context);
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
            backgroundColor: LGColors.surfaceSolid(context),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LGRadius.xl),
              side: BorderSide(
                color: LGColors.textSecondary(context).withValues(alpha: 0.14),
              ),
            ),
            title: Text(I18n.tr(context, 'categories.deleteSubcategory')),
            content: Text(
              I18n.tr(context, 'categories.deleteSubcategoryConfirm'),
            ),
            actions: [
              LGButton(
                label: I18n.tr(context, 'label.cancel'),
                size: LGButtonSize.sm,
                variant: LGButtonVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              _SoftDangerButton(
                label: I18n.tr(context, 'label.delete'),
                onPressed: () => Navigator.of(ctx).pop(true),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return LGBottomSheetShell(
          title: I18n.tr(context, 'categories.iconLabel'),
          scrollable: false,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: LGSpacing.sm,
              mainAxisSpacing: LGSpacing.sm,
            ),
            itemCount: kCategoryIconOptions.length,
            itemBuilder: (ctx, index) {
              final option = kCategoryIconOptions[index];
              final selected = option.key == initial;
              return _IconOptionTile(
                icon: option.icon,
                label: option.label,
                selected: selected,
                onTap: () => Navigator.of(ctx).pop(option.key),
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
    return LGSolidCard(
      tinted: true,
      padding: const EdgeInsets.all(LGSpacing.md),
      child: Row(
        children: [
          _CategoryIconBox(
            icon: Icons.flag_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          const SizedBox(width: LGSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LGColors.textPrimary(context),
                fontWeight: FontWeight.w700,
                height: 1.3,
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

  Widget _pageHeader() {
    return LGPageHeader(
      title: I18n.tr(context, 'categories.manageTitle'),
      leading: _CategoryIconBox(
        icon: Icons.category_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 52,
      ),
      action: LGButton(
        label: I18n.tr(context, 'categories.newCategory'),
        icon: Icons.add,
        onPressed: () => _openCategoryDialog(),
      ),
    );
  }

  Widget _categoryCard(ExpenseCategory category) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.md),
      child: LGSolidCard(
        variant: LGCardVariant.elevated,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(
              LGSpacing.lg,
              LGSpacing.md,
              LGSpacing.sm,
              LGSpacing.md,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              LGSpacing.lg,
              0,
              LGSpacing.lg,
              LGSpacing.lg,
            ),
            leading: _CategoryIconBox(
              icon: iconDataFromKey(category.icon),
              color: primary,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: LGColors.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: LGSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: LGStatusBadge(
                    label: category.subcategories.length.toString(),
                    icon: Icons.local_offer_outlined,
                    variant:
                        category.subcategories.isEmpty
                            ? LGStatusBadgeVariant.neutral
                            : LGStatusBadgeVariant.info,
                  ),
                ),
                _categoryMenu(category),
              ],
            ),
            children: [
              if (category.subcategories.isEmpty)
                _emptySubcategoryRow()
              else
                ...category.subcategories.map(
                  (sub) => _subcategoryRow(category, sub),
                ),
              const SizedBox(height: LGSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: LGButton(
                  label: I18n.tr(context, 'categories.addSubcategory'),
                  icon: Icons.add,
                  size: LGButtonSize.sm,
                  variant: LGButtonVariant.outline,
                  onPressed: () => _openSubcategoryDialog(category),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryMenu(ExpenseCategory category) {
    return PopupMenuButton<String>(
      tooltip: '',
      icon: Icon(
        Icons.more_vert_rounded,
        color: LGColors.textSecondary(context),
      ),
      color: LGColors.surfaceSolid(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        side: BorderSide(
          color: LGColors.textSecondary(context).withValues(alpha: 0.14),
        ),
      ),
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
      itemBuilder:
          (ctx) => [
            _menuItem(
              value: 'edit',
              icon: Icons.edit_outlined,
              label: I18n.tr(context, 'label.edit'),
              color: Theme.of(context).colorScheme.primary,
            ),
            _menuItem(
              value: 'delete',
              icon: Icons.delete_outline,
              label: I18n.tr(context, 'label.delete'),
              color: LGColors.danger,
            ),
          ],
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: LGSpacing.sm),
          Text(label),
        ],
      ),
    );
  }

  Widget _emptySubcategoryRow() {
    return LGSolidCard(
      tinted: true,
      padding: const EdgeInsets.all(LGSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: LGColors.textSecondary(context),
            size: 18,
          ),
          const SizedBox(width: LGSpacing.sm),
          Expanded(
            child: Text(
              I18n.tr(context, 'categories.noSubcategories'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subcategoryRow(
    ExpenseCategory category,
    ExpenseSubcategory subcategory,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: LGSpacing.sm),
      child: LGSolidCard(
        tinted: true,
        padding: const EdgeInsets.all(LGSpacing.md),
        child: Row(
          children: [
            _CategoryIconBox(
              icon: iconDataFromKey(subcategory.icon),
              color: primary,
              size: 40,
            ),
            const SizedBox(width: LGSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subcategory.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: LGColors.textPrimary(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subcategory.budget > 0) ...[
                    const SizedBox(height: LGSpacing.xs),
                    LGStatusBadge(
                      label: subcategory.budget.toStringAsFixed(2),
                      icon: Icons.account_balance_wallet_outlined,
                      variant: LGStatusBadgeVariant.info,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LGSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SoftIconButton(
                  tooltip: I18n.tr(context, 'label.edit'),
                  icon: Icons.edit_outlined,
                  color: primary,
                  onPressed:
                      () => _openSubcategoryDialog(
                        category,
                        subcategory: subcategory,
                      ),
                ),
                const SizedBox(width: LGSpacing.xs),
                _SoftIconButton(
                  tooltip: I18n.tr(context, 'label.delete'),
                  icon: Icons.delete_outline,
                  color: LGColors.danger,
                  onPressed: () => _deleteSubcategory(category, subcategory),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _buildOnboardingBanner();
    final content =
        _loading
            ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
              children: [
                _pageHeader(),
                const SizedBox(height: LGSpacing.md),
                const LGLoadingState(),
              ],
            )
            : RefreshIndicator(
              onRefresh: _load,
              child:
                  _categories.isEmpty
                      ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                        children: [
                          _pageHeader(),
                          const SizedBox(height: LGSpacing.md),
                          if (banner != null) ...[
                            banner,
                            const SizedBox(height: LGSpacing.md),
                          ],
                          LGEmptyState(
                            icon: Icons.category_outlined,
                            title: I18n.tr(context, 'categories.manageTitle'),
                            message: I18n.tr(context, 'categories.empty'),
                            action: LGEmptyAction(
                              label: I18n.tr(context, 'categories.newCategory'),
                              icon: Icons.add,
                              onPressed: () => _openCategoryDialog(),
                            ),
                          ),
                        ],
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                        itemCount:
                            _categories.length + (banner != null ? 1 : 0) + 1,
                        itemBuilder: (ctx, index) {
                          if (index == 0) {
                            return Column(
                              children: [
                                _pageHeader(),
                                const SizedBox(height: LGSpacing.md),
                              ],
                            );
                          }
                          if (banner != null && index == 1) {
                            return Column(
                              children: [
                                banner,
                                const SizedBox(height: LGSpacing.md),
                              ],
                            );
                          }
                          final categoryIndex =
                              index - (banner != null ? 2 : 1);
                          final category = _categories[categoryIndex];
                          return _categoryCard(category);
                        },
                      ),
            );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const MomentumContextStrip(feature: 'categories'),
              Expanded(child: content),
            ],
          ),
          if (widget.forceCreate) _buildOnboardingCoach(),
        ],
      ),
    );
  }
}

class _CategoryIconBox extends StatelessWidget {
  const _CategoryIconBox({
    required this.icon,
    required this.color,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(
          size >= 48 ? LGRadius.lg : LGRadius.md,
        ),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size >= 48 ? 25 : 20),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.md),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.09,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _IconPickerButton extends StatelessWidget {
  const _IconPickerButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: LGSpacing.md),
          foregroundColor: Theme.of(context).colorScheme.primary,
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.28),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LGRadius.pill),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(
            alpha: LGColors.isDark(context) ? 0.14 : 0.07,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: LGSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftDangerButton extends StatelessWidget {
  const _SoftDangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: LGSpacing.md),
        foregroundColor: LGColors.danger,
        backgroundColor: LGColors.danger.withValues(
          alpha: LGColors.isDark(context) ? 0.18 : 0.08,
        ),
        side: BorderSide(color: LGColors.danger.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.pill),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _IconOptionTile extends StatelessWidget {
  const _IconOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected
            ? Theme.of(context).colorScheme.primary
            : LGColors.textSecondary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LGRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(LGSpacing.sm),
          decoration: BoxDecoration(
            color:
                selected
                    ? Theme.of(context).colorScheme.primary.withValues(
                      alpha: LGColors.isDark(context) ? 0.18 : 0.09,
                    )
                    : LGColors.surfaceTinted(context),
            border: Border.all(
              color:
                  selected
                      ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.34)
                      : LGColors.textSecondary(context).withValues(alpha: 0.12),
            ),
            borderRadius: BorderRadius.circular(LGRadius.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: LGSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
