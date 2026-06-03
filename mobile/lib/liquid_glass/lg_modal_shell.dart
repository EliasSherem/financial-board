import 'package:flutter/material.dart';

import 'lg_card.dart';
import 'lg_glass.dart';
import 'lg_tokens.dart';

class LGBottomSheetShell extends StatelessWidget {
  const LGBottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.footer,
    this.scrollable = true,
    this.maxHeightFactor = 0.88,
    this.solidContent = false,
  });

  final Widget child;
  final String? title;
  final String? description;
  final Widget? footer;
  final bool scrollable;
  final double maxHeightFactor;
  final bool solidContent;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LGGlassSurface(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(LGRadius.xxl),
          ),
          blur: LGBlur.medium,
          intensity: LGGlassIntensity.strong,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || description != null)
                _LGModalHeader(title: title, description: description),
              Flexible(
                child:
                    scrollable
                        ? SingleChildScrollView(
                          padding: const EdgeInsets.all(LGSpacing.lg),
                          child: _content(context),
                        )
                        : Padding(
                          padding: const EdgeInsets.all(LGSpacing.lg),
                          child: _content(context),
                        ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LGSpacing.lg,
                    LGSpacing.sm,
                    LGSpacing.lg,
                    LGSpacing.lg,
                  ),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (!solidContent) return child;
    return LGSolidCard(
      padding: const EdgeInsets.all(LGSpacing.lg),
      variant: LGCardVariant.standard,
      child: child,
    );
  }
}

class LGDialogShell extends StatelessWidget {
  const LGDialogShell({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.footer,
    this.maxWidth = 520,
    this.solidContent = false,
  });

  final Widget child;
  final String? title;
  final String? description;
  final Widget? footer;
  final double maxWidth;
  final bool solidContent;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: LGSpacing.lg,
        vertical: LGSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LGGlassSurface(
          blur: LGBlur.medium,
          intensity: LGGlassIntensity.strong,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || description != null)
                _LGModalHeader(title: title, description: description),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(LGSpacing.lg),
                  child: solidContent ? LGSolidCard(child: child) : child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LGSpacing.lg,
                    LGSpacing.sm,
                    LGSpacing.lg,
                    LGSpacing.lg,
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

class _LGModalHeader extends StatelessWidget {
  const _LGModalHeader({this.title, this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LGSpacing.lg,
        LGSpacing.lg,
        LGSpacing.lg,
        LGSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                color: LGColors.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          if (description != null) ...[
            const SizedBox(height: LGSpacing.xs),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: LGColors.textSecondary(context),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
