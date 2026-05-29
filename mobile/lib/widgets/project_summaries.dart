import 'package:flutter/material.dart';
import '../models.dart';
import '../ui/finsight_ui.dart';
import '../utils/format.dart';
import '../i18n.dart';

class ProjectSummaries extends StatelessWidget {
  const ProjectSummaries({super.key, required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final items = projects.take(3).toList();
    return FSCard(
      variant: FSCardVariant.elevated,
      padding: const EdgeInsets.all(FSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectHeader(title: I18n.t(context, 'title.projects')),
          const SizedBox(height: FSSpacing.md),
          if (items.isEmpty)
            FSEmptyState(
              icon: Icons.folder_open_outlined,
              title: I18n.t(context, 'home.noProjects'),
            )
          else
            ...items.map((p) => _ProjectRow(project: p)),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FSColors.intentContainer(context, FSIntent.primary),
            borderRadius: BorderRadius.circular(FSRadius.md),
            border: Border.all(
              color: FSColors.intentBorder(context, FSIntent.primary),
            ),
          ),
          child: const Icon(
            Icons.folder_open_outlined,
            size: 20,
            color: FSColors.primary,
          ),
        ),
        const SizedBox(width: FSSpacing.md),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final progress =
        project.budget == 0
            ? 0.0
            : (project.spent / project.budget).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: FSSpacing.sm),
      padding: const EdgeInsets.all(FSSpacing.md),
      decoration: BoxDecoration(
        color: FSColors.surface(context),
        borderRadius: BorderRadius.circular(FSRadius.lg),
        border: Border.all(color: FSColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: FSSpacing.sm),
              FSStatusBadge(
                label: project.status,
                variant: FSStatusBadgeVariant.info,
              ),
            ],
          ),
          const SizedBox(height: FSSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(FSRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: FSColors.primary,
              backgroundColor: FSColors.intentContainer(
                context,
                FSIntent.primary,
              ),
            ),
          ),
          const SizedBox(height: FSSpacing.sm),
          Text(
            '${I18n.t(context, 'home.spent')} ${money(project.spent)} / ${money(project.budget)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: FSColors.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
