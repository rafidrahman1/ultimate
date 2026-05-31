import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'insight_dashboard_theme.dart';
import 'insight_rich_text.dart';

/// Shows full insight card content over a blurred scrim (long-press target).
Future<void> showInsightDetailOverlay(
  BuildContext context, {
  required String title,
  required String body,
  Color? accent,
  List<String> highlights = const [],
  IconData? icon,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss insight details',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _InsightDetailOverlay(
        title: title,
        body: body,
        accent: accent ?? InsightDashboardColors.accentBlue,
        highlights: highlights,
        icon: icon,
        animation: animation,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _InsightDetailOverlay extends StatelessWidget {
  const _InsightDetailOverlay({
    required this.title,
    required this.body,
    required this.accent,
    required this.highlights,
    required this.icon,
    required this.animation,
  });

  final String title;
  final String body;
  final Color accent;
  final List<String> highlights;
  final IconData? icon;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(scale),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: InsightDashboardColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, color: accent, size: 26),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: InsightDashboardColors.textPrimary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    color: InsightDashboardColors.textMuted,
                                    onPressed: () => Navigator.of(context).pop(),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              HighlightedInsightText(
                                text: body,
                                highlights: highlights,
                                highlightColor: accent,
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: InsightDashboardColors.textSecondary,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a card; long-press opens [showInsightDetailOverlay] when [detailBody] is non-empty.
class InsightLongPressCard extends StatelessWidget {
  const InsightLongPressCard({
    super.key,
    required this.child,
    required this.detailTitle,
    required this.detailBody,
    this.accent,
    this.highlights = const [],
    this.icon,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final String detailTitle;
  final String detailBody;
  final Color? accent;
  final List<String> highlights;
  final IconData? icon;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final body = detailBody.trim();
    if (body.isEmpty) return child;

    return GestureDetector(
      onLongPress: () => showInsightDetailOverlay(
        context,
        title: detailTitle,
        body: body,
        accent: accent,
        highlights: highlights,
        icon: icon,
      ),
      behavior: HitTestBehavior.deferToChild,
      child: child,
    );
  }
}
