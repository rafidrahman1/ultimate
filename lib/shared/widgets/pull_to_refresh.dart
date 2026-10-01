import 'package:flutter/material.dart';

/// Pull-down-to-reload for data screens. Only scroll views that are actually
/// scrollable trigger it, so empty states (plain `StatusMessage`) are
/// unaffected. Passing a null [onRefresh] (e.g. not signed in) disables it.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function()? onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh;
    if (refresh == null) return child;
    return RefreshIndicator(onRefresh: refresh, child: child);
  }
}
