import 'package:flutter/material.dart';

import '../i18n.dart';
import '../liquid_glass/liquid_glass.dart';
import '../models.dart';

class ProjectSummaries extends StatelessWidget {
  const ProjectSummaries({super.key, required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final items = projects.take(3).toList();
    final theme = Theme.of(context);
    return LGSolidCard(
      variant: LGCardVariant.elevated,
      padding: const EdgeInsets.all(LGSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.t(context, 'title.projects'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: LGSpacing.sm),
          if (items.isEmpty)
            Text(
              I18n.t(context, 'home.noProjects'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
              ),
            )
          else
            ...items.map((project) {
              final progress =
                  project.budget == 0
                      ? 0.0
                      : (project.spent / project.budget)
                          .clamp(0.0, 1.0)
                          .toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: LGSpacing.sm),
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
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: LGSpacing.sm),
                        Text(
                          project.status,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: LGColors.textSecondary(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LGSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(LGRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor:
                            LGColors.isDark(context)
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(height: LGSpacing.xs),
                    Text(
                      '${I18n.t(context, 'home.spent')} • ${project.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LGColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
