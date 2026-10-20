import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/papers/paper_form.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/status_message.dart';

Color paperColor(BuildContext context, PaperLevel level) {
  final palette = context.palette;
  return switch (level) {
    PaperLevel.valid => palette.statusGood,
    PaperLevel.soon => palette.warning,
    PaperLevel.expired => palette.statusCritical,
  };
}

String paperText(Paper p, DateTime today) {
  final d = paperDaysLeft(p, today);
  if (d < 0) return 'Expired ${-d} ${d == -1 ? 'day' : 'days'} ago';
  if (d == 0) return 'Expires today';
  return 'Expires in $d ${d == 1 ? 'day' : 'days'}';
}

/// Registration, tax token, fitness, insurance and licence, with expiry dates.
class PapersScreen extends ConsumerWidget {
  const PapersScreen({super.key, required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final today = DateTime.now();
    final papers = [
      for (final p in data.papers)
        if (p.bikeId == bike.id) p,
    ]..sort((a, b) => a.expiry.compareTo(b.expiry));
    if (papers.isEmpty) {
      return const StatusMessage(
        icon: Icons.description_outlined,
        title: 'No papers yet',
        subtitle:
            'Add registration, tax token, fitness, insurance and licence with '
            'their expiry dates, and get reminded before they lapse.',
      );
    }
    final theme = Theme.of(context);
    final palette = context.palette;

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          180,
        ),
        children: [
          for (final p in papers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => showPaperForm(context, bike: bike, paper: p),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: paperColor(context, paperLevel(p, today)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.type.label, style: theme.textTheme.titleSmall),
                          Text(
                            '${DateFormat('d MMM yyyy').format(p.expiry)}'
                            '${p.number.isEmpty ? '' : ' · ${p.number}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      paperText(p, today),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: paperColor(context, paperLevel(p, today)),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
