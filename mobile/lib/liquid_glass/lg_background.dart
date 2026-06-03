import 'package:flutter/material.dart';

import 'lg_tokens.dart';

class LGBackground extends StatelessWidget {
  const LGBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: LGColors.background(context)),
      child: Padding(padding: padding, child: child),
    );
  }
}
