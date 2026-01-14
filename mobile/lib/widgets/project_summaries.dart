import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/format.dart';
import '../i18n.dart';

class ProjectSummaries extends StatelessWidget {
  const ProjectSummaries({super.key, required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final items = projects.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.blue.shade50,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(I18n.t(context, 'title.projects'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(I18n.t(context, 'home.noProjects'))
            else
              ...items.map((p) {
                final progress = p.budget == 0 ? 0.0 : (p.spent / p.budget).clamp(0.0, 1.0).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: progress, minHeight: 8),
                      ),
                      const SizedBox(height: 4),
                      Text(I18n.t(context, 'home.spent') + ' • ${p.status}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

