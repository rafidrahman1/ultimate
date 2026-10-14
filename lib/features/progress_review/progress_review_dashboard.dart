import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/progress_review/progress_review_status.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';
import 'package:personal/shared/widgets/app_card.dart';

part 'progress_review_domain_cards.dart';
part 'progress_review_matrix.dart';
part 'progress_review_metric_tiles.dart';
part 'progress_review_summary_cards.dart';
part 'score_ring_chart.dart';

/// Progress review page: header score, per-area breakdown, plan-vs-reality table.
class ProgressReviewDashboard extends StatelessWidget {
  const ProgressReviewDashboard({super.key, required this.data});

  final ProgressReviewViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(data: data),
        const SizedBox(height: 24),
        _SectionLabel(
          title: 'By area',
          icon: Icons.grid_view_rounded,
          accent: context.palette.accent,
        ),
        const SizedBox(height: 14),
        ...data.domains.map(
          (domain) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DomainCard(domain: domain),
          ),
        ),
        const SizedBox(height: 12),
        _SectionLabel(
          title: 'Plan vs. reality',
          icon: Icons.compare_arrows_rounded,
          accent: context.palette.warning,
        ),
        const SizedBox(height: 14),
        _DiscrepancyMatrix(rows: data.discrepancies),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------
