import 'package:flutter/material.dart';

import 'tokens.dart';

class FSLoadingState extends StatelessWidget {
  const FSLoadingState({super.key, this.label, this.compact = false});

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 20.0 : 32.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? FSSpacing.md : FSSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2.6),
            ),
            if (label != null) ...[
              const SizedBox(height: FSSpacing.md),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FSColors.mutedText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
