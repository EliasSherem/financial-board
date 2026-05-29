import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../widgets/pro_widgets.dart';
import '../i18n.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, this.openProjectId});
  final int? openProjectId;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _openedFromNotification = false;
  Future<List<Project>>? _future;
  String? _token;
  late final RefreshBus _refreshBus;
  int _projectsTick = 0;

  Future<List<Project>> _loadProjects(String? token) {
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    return data.getProjects();
  }

  Future<void> _refresh() async {
    final token = _token ?? context.read<AuthStore>().token;
    _token = token;
    final future = _loadProjects(token);
    setState(() => _future = future);
    await future;
  }

  @override
  void initState() {
    super.initState();
    _refreshBus = context.read<RefreshBus>();
    _projectsTick = _refreshBus.projects;
    _refreshBus.addListener(_handleRefresh);
  }

  @override
  void dispose() {
    _refreshBus.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    if (!mounted) return;
    if (_refreshBus.projects != _projectsTick) {
      _projectsTick = _refreshBus.projects;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return Scaffold(
        backgroundColor: FSColors.background(context),
        appBar: AppBar(title: Text(I18n.t(context, 'title.projects'))),
        body: const ProBlock(feature: 'Projects'),
      );
    }
    final token = store.token;
    if (_future == null || _token != token) {
      _token = token;
      _future = _loadProjects(token);
    }
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    return Scaffold(
      backgroundColor: FSColors.background(context),
      appBar: AppBar(title: Text(I18n.t(context, 'title.projects'))),
      body: FutureBuilder<List<Project>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(
                child: FSCard(
                  margin: const EdgeInsets.all(FSSpacing.lg),
                  variant: FSCardVariant.subtle,
                  child: FSEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error: ${snap.error}',
                  ),
                ),
              );
            }
            return const FSLoadingState();
          }
          final items = snap.data!;
          if (!_openedFromNotification && widget.openProjectId != null) {
            Project? target;
            for (final item in items) {
              if (item.id == widget.openProjectId) {
                target = item;
                break;
              }
            }
            _openedFromNotification = true;
            if (target != null) {
              final project = target;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(project: project),
                  ),
                );
              });
            }
          }
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FSSpacing.lg,
                FSSpacing.lg,
                FSSpacing.lg,
                FSSpacing.xxl,
              ),
              children: [
                FSPageHeader(
                  title: I18n.t(context, 'title.projects'),
                  subtitle: I18n.t(context, 'projects.subtitle'),
                  leading: const _ProjectsHeaderIcon(),
                  action: FSButton(
                    label: I18n.t(context, 'projects.add'),
                    icon: Icons.add_rounded,
                    size: FSButtonSize.sm,
                    onPressed: () => _showCreateProject(context, data),
                  ),
                ),
                if (items.isEmpty)
                  FSCard(
                    variant: FSCardVariant.elevated,
                    child: FSEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: I18n.t(context, 'projects.none'),
                      action: FSButton(
                        label: I18n.t(context, 'projects.add'),
                        icon: Icons.add_rounded,
                        onPressed: () => _showCreateProject(context, data),
                      ),
                    ),
                  )
                else ...[
                  for (final p in items) ...[
                    _ProjectCard(
                      project: p,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(project: p),
                          ),
                        );
                      },
                      onEdit: () => _showEditProject(context, data, p),
                      onDelete: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder:
                              (dialogCtx) => AlertDialog(
                                title: Text(
                                  I18n.t(context, 'projects.deleteTitle'),
                                ),
                                content: Text(
                                  '${I18n.t(context, 'projects.deletePrefix')} ${p.name}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () =>
                                            Navigator.of(dialogCtx).pop(false),
                                    child: Text(
                                      I18n.t(context, 'label.cancel'),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () => Navigator.of(dialogCtx).pop(true),
                                    child: Text(
                                      I18n.t(context, 'projects.delete'),
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (yes == true) {
                          try {
                            await data.deleteProject(p.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    I18n.tr(context, 'projects.deleted'),
                                  ),
                                ),
                              );
                              context.read<RefreshBus>().notifyProjects();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${I18n.tr(context, 'projects.deleteFailed')}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateProject(BuildContext context, DataService data) {
    _openProjectDialog(
      context,
      onSubmit: (name, desc, budget, spent, status, startDate, endDate) async {
        await data.createProject(
          name: name,
          description: desc,
          budget: budget,
          spent: spent,
          status: status,
          startDate: startDate,
          endDate: endDate,
        );
      },
    );
  }

  void _showEditProject(BuildContext context, DataService data, Project p) {
    _openProjectDialog(
      context,
      initial: p,
      onSubmit: (name, desc, budget, spent, status, startDate, endDate) async {
        await data.updateProject(
          id: p.id,
          name: name,
          description: desc,
          budget: budget,
          spent: spent,
          status: status,
          startDate: startDate,
          endDate: endDate,
        );
      },
    );
  }

  Future<void> _openProjectDialog(
    BuildContext context, {
    Project? initial,
    required Future<void> Function(
      String name,
      String? desc,
      double budget,
      double spent,
      String status,
      String startDate,
      String endDate,
    )
    onSubmit,
  }) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final initialBudget = initial?.budget;
    final budgetCtrl = TextEditingController(
      text: initialBudget == null ? '' : initialBudget.toStringAsFixed(2),
    );
    final initialSpent = initial?.spent;
    final spentCtrl = TextEditingController(
      text: initialSpent == null ? '' : initialSpent.toStringAsFixed(2),
    );
    final startCtrl = TextEditingController(
      text: initial?.startDate != null ? formatYmd(initial!.startDate!) : '',
    );
    final endCtrl = TextEditingController(
      text: initial?.endDate != null ? formatYmd(initial!.endDate!) : '',
    );
    String status = initial?.status ?? 'Active';
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    initial == null ? 'Add New Project' : 'Edit Project',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: budgetCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Budget',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: spentCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Spent',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'On Hold',
                              child: Text('On Hold'),
                            ),
                            DropdownMenuItem(
                              value: 'Completed',
                              child: Text('Completed'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => status = v ?? 'Active'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startCtrl,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Start Date',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: now,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        startCtrl.text = formatDate(picked);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: endCtrl,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'End Date',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: now,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        endCtrl.text = formatDate(picked);
                                      }
                                    },
                                  ),
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
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          if (startCtrl.text.trim().isEmpty ||
                              endCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select start and end dates',
                                ),
                              ),
                            );
                            return;
                          }
                          await onSubmit(
                            nameCtrl.text.trim(),
                            descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            double.tryParse(budgetCtrl.text) ?? 0,
                            double.tryParse(spentCtrl.text) ??
                                (initial?.spent ?? 0),
                            status,
                            ddMmYyyyToYmd(startCtrl.text.trim()),
                            ddMmYyyyToYmd(endCtrl.text.trim()),
                          );
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    if (saved == true && context.mounted) {
      context.read<RefreshBus>().notifyProjects();
    }
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final budget = project.budget;
    final spent = project.spent;
    final remaining = budget - spent;
    final progress =
        budget == 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).toStringAsFixed(0);
    final onBudget = remaining >= 0;
    final progressIntent =
        !onBudget
            ? FSIntent.danger
            : (progress >= 0.8 ? FSIntent.warning : FSIntent.success);
    final progressColor = FSColors.intent(progressIntent);

    return FSCard(
      variant: FSCardVariant.interactive,
      onTap: onTap,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FSColors.intentContainer(context, progressIntent),
                  borderRadius: BorderRadius.circular(FSRadius.md),
                  border: Border.all(
                    color: FSColors.intentBorder(context, progressIntent),
                  ),
                ),
                child: Icon(
                  onBudget
                      ? Icons.folder_open_outlined
                      : Icons.warning_amber_rounded,
                  color: progressColor,
                ),
              ),
              const SizedBox(width: FSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((project.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: FSSpacing.xs),
                      Text(
                        project.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FSColors.mutedText(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: FSSpacing.sm),
                    Wrap(
                      spacing: FSSpacing.sm,
                      runSpacing: FSSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _statusChip(context, project.status),
                        FSStatusBadge(
                          label: '$percent%',
                          variant: _badgeVariantForIntent(progressIntent),
                          icon: Icons.timeline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FSSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProjectActionButton(
                    tooltip: I18n.t(context, 'projects.edit'),
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                  ),
                  const SizedBox(height: FSSpacing.xs),
                  _ProjectActionButton(
                    tooltip: I18n.t(context, 'projects.delete'),
                    icon: Icons.delete_outline_rounded,
                    onPressed: onDelete,
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 320;
              final width =
                  twoColumns
                      ? (constraints.maxWidth - FSSpacing.sm) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: FSSpacing.sm,
                runSpacing: FSSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _ProjectValueTile(
                      label: I18n.t(context, 'projects.budget'),
                      value: money(budget),
                      icon: Icons.account_balance_wallet_outlined,
                      intent: FSIntent.primary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ProjectValueTile(
                      label: I18n.t(context, 'home.spent'),
                      value: money(spent),
                      icon: Icons.payments_outlined,
                      intent: FSIntent.info,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: FSSpacing.lg),
          Row(
            children: [
              Text(
                I18n.t(context, 'projects.progress'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(FSRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: FSColors.alpha(progressColor, 0.12),
              color: progressColor,
            ),
          ),
          const SizedBox(height: FSSpacing.md),
          if (project.startDate != null && project.endDate != null) ...[
            _ProjectMetadataRow(
              icon: Icons.date_range_outlined,
              text:
                  '${I18n.t(context, 'projects.period')}: '
                  '${formatYmd(project.startDate!)} '
                  '${I18n.t(context, 'projects.to')} '
                  '${formatYmd(project.endDate!)}',
            ),
            const SizedBox(height: FSSpacing.sm),
          ],
          _ProjectMetadataRow(
            icon:
                remaining >= 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
            text:
                '${I18n.t(context, 'projects.remaining')}: ${money(remaining)}',
            color: remaining >= 0 ? FSColors.success : FSColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final lower = status.toLowerCase();
    if (lower.contains('active')) {
      return FSStatusBadge(label: lower, variant: FSStatusBadgeVariant.active);
    } else if (lower.contains('hold')) {
      return FSStatusBadge(label: lower, variant: FSStatusBadgeVariant.paused);
    }
    return FSStatusBadge(label: lower, variant: FSStatusBadgeVariant.completed);
  }

  FSStatusBadgeVariant _badgeVariantForIntent(FSIntent intent) {
    switch (intent) {
      case FSIntent.success:
        return FSStatusBadgeVariant.success;
      case FSIntent.warning:
        return FSStatusBadgeVariant.warning;
      case FSIntent.danger:
        return FSStatusBadgeVariant.danger;
      case FSIntent.info:
        return FSStatusBadgeVariant.info;
      case FSIntent.primary:
      case FSIntent.neutral:
        return FSStatusBadgeVariant.neutral;
    }
  }
}

class _ProjectsHeaderIcon extends StatelessWidget {
  const _ProjectsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FSColors.intentContainer(context, FSIntent.primary),
        borderRadius: BorderRadius.circular(FSRadius.md),
        border: Border.all(
          color: FSColors.intentBorder(context, FSIntent.primary),
        ),
      ),
      child: const Icon(Icons.folder_open_outlined, color: FSColors.primary),
    );
  }
}

class _ProjectActionButton extends StatelessWidget {
  const _ProjectActionButton({
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
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
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

class _ProjectValueTile extends StatelessWidget {
  const _ProjectValueTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.intent,
  });

  final String label;
  final String value;
  final IconData icon;
  final FSIntent intent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FSColors.intentContainer(context, intent),
              borderRadius: BorderRadius.circular(FSRadius.md),
            ),
            child: Icon(icon, size: 18, color: FSColors.intent(intent)),
          ),
          const SizedBox(width: FSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FSColors.mutedText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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

class _ProjectMetadataRow extends StatelessWidget {
  const _ProjectMetadataRow({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? FSColors.mutedText(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: foreground),
        const SizedBox(width: FSSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
