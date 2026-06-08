import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
import '../state/refresh_bus.dart';
import '../utils/format.dart';
import '../widgets/pro_widgets.dart';
import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../widgets/non_pro_interstitial_ad_controller.dart';
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
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
          children: [
            LGPageHeader(
              title: I18n.t(context, 'title.projects'),
              subtitle: I18n.t(context, 'projects.subtitle'),
              leading: const _ProjectsHeaderIcon(),
            ),
            const ProBlock(feature: 'Projects'),
          ],
        ),
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
      body: FutureBuilder<List<Project>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                children: [
                  LGPageHeader(
                    title: I18n.t(context, 'title.projects'),
                    subtitle: I18n.t(context, 'projects.subtitle'),
                    leading: const _ProjectsHeaderIcon(),
                    action: LGButton(
                      label: I18n.t(context, 'projects.add'),
                      icon: Icons.add,
                      onPressed: () => _showCreateProject(context, data),
                    ),
                  ),
                  LGSolidCard(
                    tinted: true,
                    child: Text(
                      'Error: ${snap.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LGColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const Center(child: LGLoadingState());
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
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
              children: [
                LGPageHeader(
                  title: I18n.t(context, 'title.projects'),
                  subtitle: I18n.t(context, 'projects.subtitle'),
                  leading: const _ProjectsHeaderIcon(),
                  action: LGButton(
                    label: I18n.t(context, 'projects.add'),
                    icon: Icons.add,
                    onPressed: () => _showCreateProject(context, data),
                  ),
                ),
                const SizedBox(height: LGSpacing.sm),
                if (items.isEmpty)
                  LGEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: I18n.t(context, 'projects.none'),
                    message: I18n.t(context, 'projects.subtitle'),
                    action: LGEmptyAction(
                      label: I18n.t(context, 'projects.add'),
                      icon: Icons.add,
                      onPressed: () => _showCreateProject(context, data),
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
                    const SizedBox(height: LGSpacing.md),
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
    NonProInterstitialAdController.preloadIfEligible(context);
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
      await NonProInterstitialAdController.recordSuccessfulMutation(context);
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
    final progressColor = _progressColor(progress, onBudget);
    final primary = Theme.of(context).colorScheme.primary;

    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(
                    alpha: LGColors.isDark(context) ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(LGRadius.lg),
                  border: Border.all(color: primary.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.folder_outlined, color: primary),
              ),
              const SizedBox(width: LGSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LGColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((project.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: LGSpacing.xs),
                      Text(
                        project.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: LGColors.textSecondary(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: LGSpacing.sm),
                    Wrap(
                      spacing: LGSpacing.sm,
                      runSpacing: LGSpacing.xs,
                      children: [
                        _statusChip(context, project.status),
                        if (project.startDate != null &&
                            project.endDate != null)
                          _metaPill(
                            context,
                            Icons.calendar_today_outlined,
                            '${formatYmd(project.startDate!)} ${I18n.t(context, 'projects.to')} ${formatYmd(project.endDate!)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LGSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProjectActionButton(
                    tooltip: I18n.t(context, 'projects.edit'),
                    icon: Icons.edit_outlined,
                    color: primary,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: LGSpacing.xs),
                  _ProjectActionButton(
                    tooltip: I18n.t(context, 'projects.delete'),
                    icon: Icons.delete_outline,
                    color: LGColors.danger,
                    onPressed: () {
                      onDelete();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.lg),
          LGMetricGrid(
            runGap: LGSpacing.sm,
            expandLastOdd: false,
            children: [
              _kv(
                context,
                I18n.t(context, 'projects.budget'),
                money(budget),
                Icons.account_balance_wallet_outlined,
                primary,
              ),
              _kv(
                context,
                I18n.t(context, 'home.spent'),
                money(spent),
                Icons.payments_outlined,
                LGColors.info,
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.lg),
          Row(
            children: [
              Text(
                I18n.t(context, 'projects.progress'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: LGColors.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: LGSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(LGRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: LGColors.textSecondary(
                context,
              ).withValues(alpha: LGColors.isDark(context) ? 0.22 : 0.14),
              color: progressColor,
            ),
          ),
          const SizedBox(height: LGSpacing.md),
          _remainingRow(context, remaining),
        ],
      ),
    );
  }

  Color _progressColor(double progress, bool onBudget) {
    if (!onBudget) return LGColors.danger;
    if (progress >= 0.8) return LGColors.warning;
    return LGColors.success;
  }

  Widget _remainingRow(BuildContext context, double remaining) {
    final color = remaining >= 0 ? LGColors.success : LGColors.danger;
    return Row(
      children: [
        Icon(
          remaining >= 0
              ? Icons.check_circle_outline_rounded
              : Icons.warning_amber_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: LGSpacing.sm),
        Expanded(
          child: Text(
            '${I18n.t(context, 'projects.remaining')}: ${money(remaining)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(LGSpacing.md),
      decoration: BoxDecoration(
        color: LGColors.surfaceTinted(context),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(
          color: LGColors.textSecondary(context).withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: LGSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LGColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    v,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: LGColors.textPrimary(context),
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

  Widget _metaPill(BuildContext context, IconData icon, String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 96,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LGSpacing.sm,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: LGColors.surfaceTinted(context),
          borderRadius: BorderRadius.circular(LGRadius.pill),
          border: Border.all(
            color: LGColors.textSecondary(context).withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: LGColors.textSecondary(context)),
            const SizedBox(width: LGSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: LGColors.textSecondary(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final lower = status.toLowerCase();
    LGStatusBadgeVariant variant;
    IconData icon;
    if (lower.contains('active')) {
      variant = LGStatusBadgeVariant.active;
      icon = Icons.bolt_rounded;
    } else if (lower.contains('hold')) {
      variant = LGStatusBadgeVariant.paused;
      icon = Icons.pause_rounded;
    } else {
      variant = LGStatusBadgeVariant.completed;
      icon = Icons.check_rounded;
    }
    return LGStatusBadge(label: lower, variant: variant, icon: icon);
  }
}

class _ProjectsHeaderIcon extends StatelessWidget {
  const _ProjectsHeaderIcon();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: LGColors.isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(LGRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(Icons.folder_outlined, color: color, size: 25),
    );
  }
}

class _ProjectActionButton extends StatelessWidget {
  const _ProjectActionButton({
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: LGColors.isDark(context) ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(LGRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}
