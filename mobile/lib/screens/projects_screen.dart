import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/data_service.dart';
import '../state/auth_store.dart';
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

  Future<List<Project>> _loadProjects(String? token) {
    final api = ApiClient()..setToken(token);
    final data = DataService(api);
    return data.getProjects();
  }

  Future<void> _refresh() async {
    final future = _loadProjects(_token);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    if (!store.isProOrExempt) {
      return Scaffold(
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
      appBar: AppBar(title: Text(I18n.t(context, 'title.projects'))),
      body: FutureBuilder<List<Project>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError)
              return Center(child: Text('Error: ${snap.error}'));
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  I18n.t(context, 'projects.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateProject(context, data),
                    icon: const Icon(Icons.add),
                    label: Text(I18n.t(context, 'projects.add')),
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(I18n.t(context, 'projects.none')),
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
                                  I18n.t(context, 'projects.deletePrefix') +
                                      ' ${p.name}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialogCtx).pop(false),
                                    child: Text(I18n.t(context, 'label.cancel')),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(true),
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
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const ProjectsScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    I18n.tr(context, 'projects.deleteFailed') +
                                        ': $e',
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

  void _openProjectDialog(
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
  }) {
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
    showDialog(
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
                                      if (picked != null)
                                        startCtrl.text = formatDate(picked);
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
                                      if (picked != null)
                                        endCtrl.text = formatDate(picked);
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
                      onPressed: () => Navigator.pop(context),
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
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const ProjectsScreen(),
                              ),
                            );
                          }
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark
            ? (onBudget ? const Color(0xFF103521) : const Color(0xFF3A1C1C))
            : (onBudget ? Colors.green.shade50 : Colors.red.shade50);
    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if ((project.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            project.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _statusChip(context, project.status),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: I18n.t(context, 'projects.edit'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: I18n.t(context, 'projects.delete'),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'projects.budget'),
                      money(budget),
                      valueStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      context,
                      I18n.t(context, 'home.spent'),
                      money(spent),
                      valueStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    I18n.t(context, 'projects.progress'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text('$percent%'),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.outline.withOpacity(0.3),
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (project.startDate != null && project.endDate != null)
                Text(
                  I18n.t(context, 'projects.period') +
                      ': ' +
                      formatYmd(project.startDate!) +
                      ' ' +
                      I18n.t(context, 'projects.to') +
                      ' ' +
                      formatYmd(project.endDate!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                I18n.t(context, 'projects.remaining') + ': ${money(remaining)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: remaining >= 0 ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    TextStyle? valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          v,
          style: Theme.of(context).textTheme.bodyMedium?.merge(valueStyle),
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final lower = status.toLowerCase();
    Color? bg;
    Color? fg;
    OutlinedBorder? shape;
    if (lower.contains('active')) {
      bg = const Color(0xFFE6F7EC);
      fg = const Color(0xFF16A34A);
    } else if (lower.contains('hold')) {
      bg = const Color(0xFFFFFAE6);
      fg = const Color(0xFFB45309);
      shape = StadiumBorder(side: BorderSide(color: fg.withOpacity(0.5)));
    } else {
      bg = const Color(0xFFEAF2FF);
      fg = const Color(0xFF2563EB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: bg,
        shape: shape ?? const StadiumBorder(),
      ),
      child: Text(
        lower,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
