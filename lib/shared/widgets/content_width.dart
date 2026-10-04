import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Centers [child] and caps its width so layouts don't stretch on tablets
/// or in landscape.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: child,
      ),
    );
  }
}
