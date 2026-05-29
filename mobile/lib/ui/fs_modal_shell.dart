import 'package:flutter/material.dart';

import 'tokens.dart';

class FSBottomSheetShell extends StatelessWidget {
  const FSBottomSheetShell({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.footer,
    this.scrollable = true,
    this.maxHeightFactor = 0.88,
  });

  final String? title;
  final String? description;
  final Widget child;
  final Widget? footer;
  final bool scrollable;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FSRadius.xl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || description != null)
                _Header(title: title, description: description),
              Flexible(
                child:
                    scrollable
                        ? SingleChildScrollView(
                          padding: const EdgeInsets.all(FSSpacing.lg),
                          child: child,
                        )
                        : Padding(
                          padding: const EdgeInsets.all(FSSpacing.lg),
                          child: child,
                        ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FSSpacing.lg,
                    FSSpacing.sm,
                    FSSpacing.lg,
                    FSSpacing.lg,
                  ),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FSDialogShell extends StatelessWidget {
  const FSDialogShell({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.footer,
    this.maxWidth = 520,
  });

  final String? title;
  final String? description;
  final Widget child;
  final Widget? footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: FSSpacing.lg,
        vertical: FSSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || description != null)
              _Header(title: title, description: description),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(FSSpacing.lg),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FSSpacing.lg,
                  FSSpacing.sm,
                  FSSpacing.lg,
                  FSSpacing.lg,
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.title, this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FSSpacing.lg,
        FSSpacing.lg,
        FSSpacing.lg,
        FSSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          if (description != null) ...[
            const SizedBox(height: FSSpacing.xs),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: FSColors.mutedText(context),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
