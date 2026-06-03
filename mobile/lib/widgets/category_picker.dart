import 'package:flutter/material.dart';

import '../models.dart';
import '../services/data_service.dart';
import '../utils/category_icons.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';

class CategorySelection {
  const CategorySelection(this.category, this.subcategory);
  final ExpenseCategory? category;
  final ExpenseSubcategory? subcategory;
}

class CategoryDialogResult {
  const CategoryDialogResult(this.name, this.iconKey);
  final String name;
  final String iconKey;
}

class CategorySelectorField extends StatelessWidget {
  const CategorySelectorField({
    super.key,
    required this.width,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onTap,
    required this.onClear,
    this.labelText,
  });

  final double width;
  final ExpenseCategory? selectedCategory;
  final ExpenseSubcategory? selectedSubcategory;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        selectedCategory != null || selectedSubcategory != null;
    final displayIconKey =
        selectedSubcategory?.icon ??
        selectedCategory?.icon ??
        kCategoryIconOptions.first.key;
    final displayLabel =
        selectedSubcategory?.name ??
        selectedCategory?.name ??
        I18n.tr(context, 'tx.selectCategory');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(LGRadius.lg),
          onTap: onTap,
          child: InputDecorator(
            isEmpty: !hasSelection,
            decoration: LGForm.dropdownDecoration(
              context,
              labelText: labelText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: SizedBox(
              width: width,
              child: Row(
                children: [
                  Icon(iconDataFromKey(displayIconKey), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasSelection)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClear,
              child: Text(I18n.tr(context, 'label.clear')),
            ),
          ),
      ],
    );
  }
}

class _CategoryPickerAction extends StatelessWidget {
  const _CategoryPickerAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(42),
        minimumSize: const Size.square(42),
        foregroundColor: LGColors.primaryBlue,
        backgroundColor: LGColors.intentContainer(context, LGIntent.primary),
        side: BorderSide(
          color: LGColors.intentStroke(context, LGIntent.primary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LGRadius.lg),
        ),
      ),
    );
  }
}

Future<CategorySelection?> showCategoryPicker({
  required BuildContext context,
  required DataService data,
  required List<ExpenseCategory> categories,
  required void Function(List<ExpenseCategory>) onCategoriesUpdated,
  ExpenseCategory? initialCategory,
  ExpenseSubcategory? initialSubcategory,
}) {
  return showModalBottomSheet<CategorySelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => LGBottomSheetShell(
          title: I18n.tr(context, 'categories.selectCategoryTitle'),
          scrollable: false,
          child: _CategoryPickerSheet(
            data: data,
            categories: List<ExpenseCategory>.from(categories),
            onCategoriesUpdated: onCategoriesUpdated,
            initialCategory: initialCategory,
            initialSubcategory: initialSubcategory,
          ),
        ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.data,
    required this.categories,
    required this.onCategoriesUpdated,
    this.initialCategory,
    this.initialSubcategory,
  });

  final DataService data;
  final List<ExpenseCategory> categories;
  final ExpenseCategory? initialCategory;
  final ExpenseSubcategory? initialSubcategory;
  final void Function(List<ExpenseCategory>) onCategoriesUpdated;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  int? selectedCategoryId;
  int? selectedSubcategoryId;
  late List<ExpenseCategory> categories;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    selectedCategoryId = widget.initialCategory?.id;
    selectedSubcategoryId = widget.initialSubcategory?.id;
    categories = List<ExpenseCategory>.from(widget.categories);
  }

  ExpenseCategory? _categoryById(int? id) {
    if (id == null) return null;
    for (final cat in categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  ExpenseSubcategory? _subcategoryById(ExpenseCategory category, int? id) {
    if (id == null) return null;
    for (final sub in category.subcategories) {
      if (sub.id == id) return sub;
    }
    return null;
  }

  void _notifyCategoriesChanged() {
    widget.onCategoriesUpdated(List<ExpenseCategory>.from(categories));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<CategoryDialogResult?> _showCategoryDialog({
    required String title,
    required String hint,
  }) {
    final nameCtrl = TextEditingController();
    String iconKey = kCategoryIconOptions.first.key;
    return showDialog<CategoryDialogResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder:
              (ctx, setLocal) => LGDialogShell(
                title: title,
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LGButton(
                      label: I18n.tr(context, 'label.cancel'),
                      variant: LGButtonVariant.glass,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: LGSpacing.sm),
                    LGButton(
                      label: I18n.tr(context, 'label.save'),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          _showError(
                            I18n.tr(context, 'categories.validationName'),
                          );
                          return;
                        }
                        Navigator.pop(ctx, CategoryDialogResult(name, iconKey));
                      },
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: LGForm.solidInputDecoration(
                        context,
                        labelText: hint,
                      ),
                    ),
                    const SizedBox(height: LGSpacing.lg),
                    Text(I18n.tr(context, 'categories.iconLabel')),
                    const SizedBox(height: LGSpacing.sm),
                    Wrap(
                      spacing: LGSpacing.sm,
                      runSpacing: LGSpacing.sm,
                      children:
                          kCategoryIconOptions
                              .map(
                                (option) => ChoiceChip(
                                  avatar: Icon(option.icon, size: 18),
                                  label: Text(option.label),
                                  selected: iconKey == option.key,
                                  onSelected:
                                      (_) =>
                                          setLocal(() => iconKey = option.key),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  Future<void> _createCategory() async {
    if (_saving) return;
    final result = await _showCategoryDialog(
      title: I18n.tr(context, 'categories.newCategory'),
      hint: I18n.tr(context, 'categories.newCategory'),
    );
    if (result == null) return;
    try {
      setState(() => _saving = true);
      final newCategory = await widget.data.createExpenseCategory(
        name: result.name,
        icon: result.iconKey,
      );
      setState(() {
        categories = [
          ...categories,
          newCategory,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        selectedCategoryId = newCategory.id;
        selectedSubcategoryId = null;
        _saving = false;
      });
      _notifyCategoriesChanged();
    } catch (e) {
      setState(() => _saving = false);
      _showError('${I18n.tr(context, "label.failed")}: $e');
    }
  }

  Future<void> _createSubcategory() async {
    if (_saving) return;
    final category = _categoryById(selectedCategoryId);
    if (category == null) {
      _showError(I18n.tr(context, 'categories.noneSelected'));
      return;
    }

    final result = await _showCategoryDialog(
      title: I18n.tr(context, 'categories.newSubcategory'),
      hint: I18n.tr(context, 'categories.newSubcategory'),
    );
    if (result == null) return;

    try {
      setState(() => _saving = true);
      final updatedCategory = await widget.data.createExpenseSubcategory(
        categoryId: category.id,
        name: result.name,
        icon: result.iconKey,
      );
      setState(() {
        categories =
            categories
                .map((c) => c.id == updatedCategory.id ? updatedCategory : c)
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        selectedCategoryId = updatedCategory.id;
        final newSub = updatedCategory.subcategories.firstWhere(
          (s) =>
              s.name.toLowerCase() == result.name.toLowerCase() &&
              s.icon == result.iconKey,
          orElse: () => updatedCategory.subcategories.last,
        );
        selectedSubcategoryId = newSub.id;
        _saving = false;
      });
      _notifyCategoriesChanged();
    } catch (e) {
      setState(() => _saving = false);
      _showError('${I18n.tr(context, "label.failed")}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;
    final selectedCategory = _categoryById(selectedCategoryId);
    final subcategories =
        selectedCategory?.subcategories ?? const <ExpenseSubcategory>[];

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Spacer(),
                  _CategoryPickerAction(
                    tooltip: I18n.tr(context, 'categories.newCategory'),
                    onPressed: _saving ? null : _createCategory,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  const SizedBox(width: LGSpacing.sm),
                  _CategoryPickerAction(
                    tooltip: I18n.tr(context, 'categories.newSubcategory'),
                    onPressed:
                        (_saving || selectedCategoryId == null)
                            ? null
                            : _createSubcategory,
                    icon: const Icon(Icons.post_add_outlined),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: ListView(
                      children: [
                        ListTile(
                          title: Text(I18n.tr(context, 'categories.none')),
                          selected: selectedCategoryId == null,
                          onTap: () {
                            setState(() {
                              selectedCategoryId = null;
                              selectedSubcategoryId = null;
                            });
                          },
                        ),
                        ...categories.map(
                          (cat) => ListTile(
                            leading: Icon(iconDataFromKey(cat.icon)),
                            title: Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: selectedCategoryId == cat.id,
                            onTap: () {
                              setState(() {
                                selectedCategoryId = cat.id;
                                selectedSubcategoryId = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child:
                        selectedCategoryId == null
                            ? Center(
                              child: Text(
                                I18n.tr(context, 'categories.noneSelected'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                            : subcategories.isEmpty
                            ? Center(
                              child: Text(
                                I18n.tr(context, 'categories.noSubcategories'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                            : ListView(
                              children: [
                                ListTile(
                                  title: Text(
                                    I18n.tr(
                                      context,
                                      'categories.useCategoryOnly',
                                    ),
                                  ),
                                  selected: selectedSubcategoryId == null,
                                  onTap:
                                      () => setState(
                                        () => selectedSubcategoryId = null,
                                      ),
                                ),
                                ...subcategories.map(
                                  (sub) => ListTile(
                                    leading: Icon(iconDataFromKey(sub.icon)),
                                    title: Text(
                                      sub.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: selectedSubcategoryId == sub.id,
                                    onTap:
                                        () => setState(
                                          () => selectedSubcategoryId = sub.id,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  LGButton(
                    label: I18n.tr(context, 'label.cancel'),
                    variant: LGButtonVariant.glass,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  LGButton(
                    label: I18n.tr(context, 'label.clear'),
                    variant: LGButtonVariant.ghost,
                    onPressed: () {
                      setState(() {
                        selectedCategoryId = null;
                        selectedSubcategoryId = null;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  LGButton(
                    label: I18n.tr(context, 'label.save'),
                    onPressed: () {
                      final category = _categoryById(selectedCategoryId);
                      final subcategory =
                          category == null
                              ? null
                              : _subcategoryById(
                                category,
                                selectedSubcategoryId,
                              );
                      Navigator.pop(
                        context,
                        CategorySelection(category, subcategory),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
