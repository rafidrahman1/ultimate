import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'insight_parser.dart';
import 'results_service.dart';

class ResultDetailScreen extends StatelessWidget {
  const ResultDetailScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, d MMM yyyy · HH:mm');
    final sections = parseInsightOutput(result.output);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insight report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy insights',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.output));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insights copied')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ReportHeader(
            title: result.title,
            dateLabel: dateFormat.format(result.createdAt.toLocal()),
          ),
          const SizedBox(height: 16),
          _DataSourcesRow(snapshot: result.dataSnapshot),
          const SizedBox(height: 20),
          if (sections.isEmpty)
            _InsightBodyCard(child: Text(result.output, style: theme.textTheme.bodyLarge))
          else
            ...sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionCard(section: section),
                )),
          const SizedBox(height: 8),
          _PromptPanel(prompt: result.prompt),
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.title, required this.dateLabel});

  final String title;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.result.withValues(alpha: 0.18),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: AppColors.result.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.result.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.result, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataSourcesRow extends StatelessWidget {
  const _DataSourcesRow({required this.snapshot});

  final Map<String, String> snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    void addChip(String key, String label, IconData icon, Color color) {
      final value = snapshot[key]?.trim() ?? '';
      if (value.isEmpty || value.toLowerCase().startsWith('no ')) return;
      chips.add(_SourceChip(label: label, icon: icon, color: color));
    }

    addChip('health', 'Health', Icons.favorite, AppColors.health);
    addChip('expenses', 'Expenses', Icons.account_balance_wallet, AppColors.expenses);
    addChip('location', 'Location', Icons.location_on, AppColors.location);
    addChip('chat', 'Chat', Icons.chat_bubble_outline, AppColors.chat);

    if (chips.isEmpty) {
      return Text(
        'No data sources attached to this run.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data included',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final InsightSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActions = section.title.toLowerCase().contains('action');

    return _InsightBodyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActions ? Icons.check_circle_outline : Icons.lightbulb_outline,
                size: 20,
                color: isActions ? AppColors.expenses : AppColors.result,
              ),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (section.paragraph != null) ...[
            const SizedBox(height: 10),
            Text(section.paragraph!, style: theme.textTheme.bodyLarge),
          ],
          if (section.hasBullets) ...[
            const SizedBox(height: 12),
            ...section.bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BulletRow(text: bullet, accent: isActions),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ? AppColors.expenses : AppColors.result;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _InsightBodyCard extends StatelessWidget {
  const _InsightBodyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.code, color: theme.colorScheme.onSurfaceVariant),
          title: const Text('Prompt used'),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SelectableText(
                prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
