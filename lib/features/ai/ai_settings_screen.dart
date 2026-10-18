import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/shared/widgets/content_width.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  AiSettings? _draft;
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _load(AiSettings s) {
    _draft = s;
    _syncFields();
  }

  void _syncFields() {
    final s = _draft!;
    _key.text = s.keyOf(s.provider);
    _model.text = s.models[s.provider] ?? '';
  }

  AiSettings _withFields() {
    final s = _draft!;
    return s.copyWith(
      keys: {...s.keys, s.provider: _key.text.trim()},
      models: {...s.models, s.provider: _model.text.trim()},
    );
  }

  Future<void> _save() async {
    final next = _withFields();
    await ref.read(aiSettingsProvider.notifier).save(next);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiSettingsProvider);
    if (_draft == null && async.hasValue) _load(async.requireValue);
    final draft = _draft;
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('AI settings')),
      body: draft == null
          ? const Center(child: CircularProgressIndicator())
          : ContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  Text(
                    'MotoHealth works fully offline. AI features send your '
                    "bike's records (never your name or location) to the "
                    'provider you choose, using your own API key. The key is '
                    'kept in the phone\'s secure storage.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedButton<AiProvider>(
                    segments: [
                      for (final p in AiProvider.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {draft.provider},
                    onSelectionChanged: (s) => setState(() {
                      _draft = _withFields().copyWith(provider: s.first);
                      _syncFields();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _key,
                    obscureText: _hidden,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: '${draft.provider.label} API key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _model,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      hintText: draft.provider.defaultModel,
                      helperText:
                          'Leave empty for ${draft.provider.defaultModel}. '
                          'A stronger model gives a more accurate schedule.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Look the bike up on the web'),
                    subtitle: const Text(
                      'Claude and Gemini check published service schedules '
                      'while answering. Recommended for accuracy. OpenAI '
                      'does not use this.',
                    ),
                    value: draft.webSearch,
                    onChanged: (v) => setState(
                      () => _draft = _withFields().copyWith(webSearch: v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
    );
  }
}
