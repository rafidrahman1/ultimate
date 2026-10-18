import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/ai/ai_client.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/ai_settings_screen.dart';
import 'package:motohealth/features/ai/analysis_kinds.dart';
import 'package:motohealth/features/ai/bike_snapshot.dart';
import 'package:motohealth/features/ai/reports_store.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/report_text.dart';

/// Pick an analysis; each one reads the bike's records and writes a report.
class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key, required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider).valueOrNull ?? const {};
    final settings = ref.watch(aiSettingsProvider).valueOrNull;
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI analysis'),
        actions: [
          IconButton(
            tooltip: 'AI settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            if (settings != null && !settings.isConfigured)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppCard(
                  tier: AppCardTier.hero,
                  accent: palette.warning,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AiSettingsScreen(),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Add an API key to use AI analysis.',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            for (final kind in AnalysisKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AnalysisResultScreen(bike: bike, kind: kind),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(kind.icon, color: palette.accent),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.title, style: theme.textTheme.titleSmall),
                            Text(
                              _subtitle(
                                kind,
                                reports[ReportsStore.keyFor(
                                  bike.id,
                                  kind.name,
                                )],
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _subtitle(AnalysisKind kind, SavedReport? last) => last == null
    ? kind.subtitle
    : 'Last run ${DateFormat('d MMM, HH:mm').format(last.at)}';

class AnalysisResultScreen extends ConsumerStatefulWidget {
  const AnalysisResultScreen({
    super.key,
    required this.bike,
    required this.kind,
  });

  final Bike bike;
  final AnalysisKind kind;

  @override
  ConsumerState<AnalysisResultScreen> createState() =>
      _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends ConsumerState<AnalysisResultScreen> {
  final _question = TextEditingController();
  AiCancelToken? _token;
  bool _loading = false;
  String? _error;

  String get _key => ReportsStore.keyFor(widget.bike.id, widget.kind.name);
  bool get _isAsk => widget.kind == AnalysisKind.ask;

  @override
  void dispose() {
    _token?.cancel();
    _question.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_isAsk && _question.text.trim().isEmpty) {
      setState(() => _error = 'Type your question first.');
      return;
    }
    final settings = await ref.read(aiSettingsProvider.future);
    if (!settings.isConfigured) {
      if (!mounted) return;
      setState(() => _error = 'Add an API key in AI settings first.');
      return;
    }
    final data = ref.read(motoStoreProvider).requireValue;
    final bike = data.bikes.firstWhere((b) => b.id == widget.bike.id);
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = _token = AiCancelToken();
    try {
      final text = await aiClient.generate(
        settings: settings,
        system: analysisSystemPrompt,
        prompt: buildAnalysisPrompt(
          widget.kind,
          buildBikeSnapshot(data, bike, DateTime.now()),
          question: _question.text,
        ),
        webSearch: widget.kind == AnalysisKind.maintenance || _isAsk,
        cancelToken: token,
      );
      await ref
          .read(reportsProvider.notifier)
          .save(
            bike.id,
            widget.kind.name,
            SavedReport(text, DateTime.now(), question: _question.text.trim()),
          );
    } on AiCancelledException {
      return;
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(reportsProvider).valueOrNull?[_key];
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.title),
        actions: [
          if (saved != null)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: saved.text));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            if (_isAsk) ...[
              TextField(
                controller: _question,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Your question',
                  hintText:
                      'e.g. Is my mileage normal for this bike? Should I '
                      'change the chain now?',
                  helperText: saved?.question.isEmpty ?? true
                      ? null
                      : 'Last asked: ${saved!.question}',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _run,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading
                          ? 'Analyzing…'
                          : saved == null
                          ? (_isAsk ? 'Ask' : 'Analyze')
                          : (_isAsk ? 'Ask again' : 'Run again'),
                    ),
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => _token?.cancel(),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (saved != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Generated ${DateFormat('d MMM yyyy, HH:mm').format(saved.at)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: ReportText(saved.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI can make mistakes. Check safety-critical advice against '
                "your owner's manual.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ] else if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: Text(
                  widget.kind.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
