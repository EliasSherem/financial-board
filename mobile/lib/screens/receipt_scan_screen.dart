import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../services/receipt_image_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../widgets/category_picker.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  late final DataService _data;
  late final Future<void> _metadataFuture;

  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  bool _metadataLoaded = false;
  bool _reading = false;
  bool _saving = false;
  bool _leaving = false;
  String? _error;
  String? _duplicateError;
  File? _selectedImage;
  TransactionDraft? _draft;

  List<Account> _accounts = [];
  List<Project> _projects = [];
  List<ExpenseCategory> _categories = [];
  ExpenseCategory? _selectedCategory;
  ExpenseSubcategory? _selectedSubcategory;

  int? _accountId;
  int? _projectId;
  DateTime? _date;
  String _type = 'Expense';

  @override
  void initState() {
    super.initState();
    _data = DataService(ApiClient()..setToken(context.read<AuthStore>().token));
    _metadataFuture = _loadMetadata();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final accounts = await _data.getAccounts();
      List<Project> projects = [];
      List<ExpenseCategory> categories = [];
      try {
        projects = await _data.getProjects();
      } catch (_) {
        projects = [];
      }
      try {
        categories = await _data.getExpenseCategories();
        categories.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      } catch (_) {
        categories = [];
      }
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _projects = projects;
        _categories = categories;
        _metadataLoaded = true;
        _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _metadataLoaded = true;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _selectFromCamera() async {
    await _selectAndUpload(pickReceiptFromCamera);
  }

  Future<void> _selectFromGallery() async {
    await _selectAndUpload(pickReceiptFromGallery);
  }

  Future<void> _selectAndUpload(Future<File?> Function() picker) async {
    if (!context.read<AuthStore>().isProOrExempt) {
      _showError(I18n.tr(context, 'receipt.proRequired'));
      return;
    }

    try {
      final image = await picker();
      if (image == null) return;
      await _uploadImage(image);
    } on ReceiptImageException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(_cleanError(e));
    }
  }

  Future<void> _uploadImage(File image) async {
    final uploadFailedLabel = I18n.tr(context, 'receipt.uploadFailed');
    setState(() {
      _reading = true;
      _error = null;
      _duplicateError = null;
      _selectedImage = image;
    });

    try {
      final upload = await _data.uploadReceiptDraft(image);
      if (upload.draftId <= 0) {
        throw Exception(upload.error ?? uploadFailedLabel);
      }
      final draft = await _data.getTransactionDraft(upload.draftId);
      await _metadataFuture;
      if (!mounted) return;
      _applyDraft(draft, upload);
      setState(() {
        _draft = draft;
        _error = upload.error ?? draft.errorMessage;
        _reading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _localizedReceiptError(e);
        _reading = false;
      });
    }
  }

  void _applyDraft(TransactionDraft draft, ReceiptUploadResponse upload) {
    final tx = upload.transaction;
    final detectedType = _normalizeType(draft.type ?? tx?.type) ?? 'Expense';
    final amount = draft.amount ?? tx?.amount;
    final description = draft.description ?? tx?.description ?? tx?.merchant;
    final category = draft.category ?? tx?.category;

    _date = draft.date ?? tx?.date ?? DateTime.now();
    _descriptionCtrl.text = description ?? '';
    _amountCtrl.text =
        amount == null || amount == 0 ? '' : amount.abs().toStringAsFixed(2);
    _type = detectedType;
    _accountId =
        draft.accountId ?? (_accounts.isNotEmpty ? _accounts.first.id : null);
    _projectId = draft.projectId;

    _selectedCategory = null;
    _selectedSubcategory = null;
    _categoryCtrl.text = category ?? '';

    if (draft.categoryId != null) {
      for (final cat in _categories) {
        if (cat.id == draft.categoryId) {
          _selectedCategory = cat;
          break;
        }
      }
    }
    if (draft.subcategoryId != null) {
      for (final cat in _categories) {
        for (final sub in cat.subcategories) {
          if (sub.id == draft.subcategoryId) {
            _selectedCategory = cat;
            _selectedSubcategory = sub;
            break;
          }
        }
        if (_selectedSubcategory != null) break;
      }
    }
    if (_selectedCategory == null && category != null) {
      final normalized = category.trim().toLowerCase();
      for (final cat in _categories) {
        if (cat.name.toLowerCase() == normalized) {
          _selectedCategory = cat;
          _categoryCtrl.clear();
          break;
        }
        for (final sub in cat.subcategories) {
          if (sub.name.toLowerCase() == normalized) {
            _selectedCategory = cat;
            _selectedSubcategory = sub;
            _categoryCtrl.clear();
            break;
          }
        }
        if (_selectedCategory != null) break;
      }
    }
  }

  Future<void> _retryUpload() async {
    final image = _selectedImage;
    if (image == null) return;
    await _uploadImage(image);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (_accountId == null ||
        _date == null ||
        _descriptionCtrl.text.trim().isEmpty ||
        amount == null ||
        amount <= 0) {
      _showError(I18n.tr(context, 'receipt.validationRequired'));
      return;
    }

    setState(() {
      _saving = true;
      _duplicateError = null;
    });

    final selectedCatId = _categories.isEmpty ? null : _selectedCategory?.id;
    final selectedSubId = _categories.isEmpty ? null : _selectedSubcategory?.id;
    final manualCategory =
        _categories.isEmpty && _categoryCtrl.text.trim().isNotEmpty
            ? _categoryCtrl.text.trim()
            : null;
    final normalizedAmount = amount.abs();

    try {
      await _data.updateTransactionDraft(draft.id, {
        'account_id': _accountId,
        'project_id': _projectId,
        'date': _dateToYmd(_date!),
        'description': _descriptionCtrl.text.trim(),
        'amount': normalizedAmount,
        'type': _type,
        'category': manualCategory,
        'category_id': selectedCatId,
        'subcategory_id': selectedSubId,
      });
      await _data.confirmTransactionDraft(draft.id);
      if (!mounted) return;
      context.read<RefreshBus>().notifyTransactions();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = _cleanError(e);
      if (_isDuplicateError(message)) {
        setState(() {
          _duplicateError = I18n.tr(context, 'receipt.duplicate');
        });
        _showError(I18n.tr(context, 'receipt.duplicate'));
      } else {
        _showError(message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    _leaving = true;
    final draft = _draft;
    if (draft != null && !draft.isConfirmed && !draft.isDiscarded) {
      try {
        await _data.discardTransactionDraft(draft.id);
      } catch (e) {
        debugPrint('Failed to discard receipt draft ${draft.id}: $e');
        if (mounted) _showError(I18n.tr(context, 'receipt.discardFailed'));
      }
    }
    if (mounted) Navigator.of(context).pop(false);
    _leaving = false;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final result = await showCategoryPicker(
      context: context,
      data: _data,
      categories: _categories,
      onCategoriesUpdated: (updated) {
        setState(() {
          _categories = List<ExpenseCategory>.from(updated)..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        });
      },
      initialCategory: _selectedCategory,
      initialSubcategory: _selectedSubcategory,
    );
    if (result == null) return;
    setState(() {
      _selectedCategory = result.category;
      _selectedSubcategory = result.subcategory;
      _categoryCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(I18n.tr(context, 'receipt.scanTitle')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancel,
          ),
        ),
        body: SafeArea(
          child:
              _reading
                  ? _buildReading()
                  : _draft == null
                  ? _buildChooser()
                  : _buildReview(),
        ),
      ),
    );
  }

  Widget _buildChooser() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LGSpacing.lg,
        LGSpacing.lg,
        LGSpacing.lg,
        96,
      ),
      children: [
        LGPageHeader(
          title: I18n.tr(context, 'receipt.scanTitle'),
          subtitle: I18n.tr(context, 'receipt.scanSubtitle'),
          leading: const _ReceiptHeaderIcon(),
        ),
        LGSolidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LGButton(
                label: I18n.tr(context, 'receipt.takePhoto'),
                icon: Icons.camera_alt_outlined,
                fullWidth: true,
                onPressed: _selectFromCamera,
              ),
              const SizedBox(height: LGSpacing.md),
              LGButton(
                label: I18n.tr(context, 'receipt.chooseGallery'),
                icon: Icons.photo_library_outlined,
                variant: LGButtonVariant.outline,
                fullWidth: true,
                onPressed: _selectFromGallery,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: LGSpacing.md),
          _MessageBox(
            icon: Icons.error_outline,
            message: _error!,
            tone: _MessageTone.error,
            action:
                _selectedImage == null
                    ? null
                    : LGButton(
                      label: I18n.tr(context, 'receipt.retry'),
                      icon: Icons.refresh,
                      size: LGButtonSize.sm,
                      onPressed: _retryUpload,
                    ),
          ),
        ],
      ],
    );
  }

  Widget _buildReading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LGSpacing.xl),
        child: LGLoadingState(label: I18n.tr(context, 'receipt.reading')),
      ),
    );
  }

  Widget _buildReview() {
    final draft = _draft!;
    final showUncertain =
        (draft.confidence != null && draft.confidence! < 0.75) ||
        draft.warningsJson.isNotEmpty ||
        (_error != null && _error!.trim().isNotEmpty);
    final categoryWidth = (MediaQuery.of(context).size.width * 0.7).clamp(
      200.0,
      360.0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LGSpacing.lg,
        LGSpacing.lg,
        LGSpacing.lg,
        120,
      ),
      children: [
        LGPageHeader(
          title: I18n.tr(context, 'receipt.reviewTitle'),
          subtitle: I18n.tr(context, 'receipt.reviewSubtitle'),
          leading: const _ReceiptHeaderIcon(),
        ),
        if (showUncertain) ...[
          _MessageBox(
            icon: Icons.warning_amber_rounded,
            message: I18n.tr(context, 'receipt.reviewCarefully'),
            tone: _MessageTone.warning,
            details: [
              if (_error != null && _error!.trim().isNotEmpty) _error!,
              ...draft.warningsJson,
            ],
          ),
          const SizedBox(height: LGSpacing.md),
        ],
        if (_duplicateError != null) ...[
          _MessageBox(
            icon: Icons.error_outline,
            message: _duplicateError!,
            tone: _MessageTone.error,
          ),
          const SizedBox(height: LGSpacing.md),
        ],
        LGSolidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(LGRadius.lg),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: LGForm.dateFieldDecoration(
                    context,
                    labelText: I18n.tr(context, 'tx.date'),
                    onCalendarTap: _pickDate,
                  ),
                  child: Text(
                    _date == null
                        ? I18n.tr(context, 'receipt.selectDate')
                        : formatDate(_date!),
                  ),
                ),
              ),
              const SizedBox(height: LGSpacing.md),
              TextField(
                controller: _descriptionCtrl,
                textInputAction: TextInputAction.next,
                decoration: LGForm.solidInputDecoration(
                  context,
                  labelText: I18n.tr(context, 'tx.description'),
                ),
              ),
              const SizedBox(height: LGSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      items:
                          const ['Expense', 'Income']
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    I18n.tr(
                                      context,
                                      t == 'Expense'
                                          ? 'tx.expense'
                                          : 'tx.income',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _type = v ?? 'Expense'),
                      decoration: LGForm.dropdownDecoration(
                        context,
                        labelText: I18n.tr(context, 'tx.type'),
                      ),
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: LGForm.solidInputDecoration(
                        context,
                        labelText: I18n.tr(context, 'tx.amount'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LGSpacing.md),
              if (_categories.isEmpty)
                TextField(
                  controller: _categoryCtrl,
                  decoration: LGForm.solidInputDecoration(
                    context,
                    labelText: I18n.tr(context, 'tx.category'),
                  ),
                )
              else
                CategorySelectorField(
                  width: categoryWidth,
                  selectedCategory: _selectedCategory,
                  selectedSubcategory: _selectedSubcategory,
                  onTap: _pickCategory,
                  onClear: () {
                    setState(() {
                      _selectedCategory = null;
                      _selectedSubcategory = null;
                    });
                  },
                  labelText: I18n.tr(context, 'tx.category'),
                ),
              const SizedBox(height: LGSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _metadataLoaded ? _accountId : null,
                items:
                    _accounts.map((a) {
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
                onChanged:
                    _metadataLoaded
                        ? (v) => setState(() => _accountId = v)
                        : null,
                decoration: LGForm.dropdownDecoration(
                  context,
                  labelText: I18n.tr(context, 'tx.account'),
                ),
              ),
              const SizedBox(height: LGSpacing.md),
              DropdownButtonFormField<int?>(
                initialValue: _projectId,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(I18n.tr(context, 'tx.noProject')),
                  ),
                  ..._projects.map(
                    (p) => DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _projectId = v),
                decoration: LGForm.dropdownDecoration(
                  context,
                  labelText: I18n.tr(context, 'tx.projectOptional'),
                ),
              ),
              const SizedBox(height: LGSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: LGButton(
                      label: I18n.tr(context, 'label.cancel'),
                      variant: LGButtonVariant.outline,
                      fullWidth: true,
                      onPressed: _saving ? null : _cancel,
                    ),
                  ),
                  const SizedBox(width: LGSpacing.md),
                  Expanded(
                    child: LGButton(
                      label: I18n.tr(context, 'label.save'),
                      icon: Icons.check,
                      loading: _saving,
                      fullWidth: true,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _normalizeType(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw == 'income') return 'Income';
    if (raw == 'expense') return 'Expense';
    return null;
  }

  String _dateToYmd(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  bool _isDuplicateError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('already registered') ||
        normalized.contains('already be registered') ||
        normalized.contains('receipt may already');
  }

  String _cleanError(Object error) {
    var message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    return message;
  }

  String _localizedReceiptError(Object error) {
    final message = _cleanError(error);
    final normalized = message.toLowerCase();
    if (normalized.contains(
          'receipt scanning is available with finsight pro',
        ) ||
        normalized.contains('feature available on pro plan')) {
      return I18n.tr(context, 'receipt.proRequired');
    }
    if (normalized.contains('receipt scanning is currently disabled')) {
      return I18n.tr(context, 'receipt.disabled');
    }
    return message;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReceiptHeaderIcon extends StatelessWidget {
  const _ReceiptHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: LGColors.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LGRadius.lg),
      ),
      child: const Icon(
        Icons.receipt_long_outlined,
        color: LGColors.primaryBlue,
      ),
    );
  }
}

enum _MessageTone { warning, error }

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.message,
    required this.tone,
    this.details = const [],
    this.action,
  });

  final IconData icon;
  final String message;
  final _MessageTone tone;
  final List<String> details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color =
        tone == _MessageTone.error ? LGColors.danger : LGColors.warning;
    return LGSolidCard(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: LGSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LGColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          for (final detail in details.where((d) => d.trim().isNotEmpty)) ...[
            const SizedBox(height: LGSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LGColors.textSecondary(context),
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: LGSpacing.md),
            Align(alignment: Alignment.centerRight, child: action!),
          ],
        ],
      ),
    );
  }
}
