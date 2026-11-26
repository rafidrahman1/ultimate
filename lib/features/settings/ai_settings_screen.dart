import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/settings_kit.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Cloud AI: whether it is used at all, which provider, and each provider's
/// key and model. Edits are held until saved.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _ProviderForm {
  _ProviderForm(this.provider, this.icon, this.keyHint);

  final AiProvider provider;
  final IconData icon;
  final String keyHint;
  final key = TextEditingController();
  final model = TextEditingController();

  void dispose() {
    key.dispose();
    model.dispose();
  }
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _forms = {
    AiProvider.openai: _ProviderForm(
      AiProvider.openai,
      Icons.auto_awesome_outlined,
      'sk-...',
    ),
    AiProvider.gemini: _ProviderForm(
      AiProvider.gemini,
      Icons.diamond_outlined,
      'AIza...',
    ),
    AiProvider.anthropic: _ProviderForm(
      AiProvider.anthropic,
      Icons.psychology_alt_outlined,
      'sk-ant-...',
    ),
  };

  AiProvider _provider = AiProvider.openai;
  bool _enabled = true;
  bool _dirty = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final form in _forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  void _load(AiSettings value) {
    _provider = value.provider;
    _enabled = value.enableApiCalls;
    _forms[AiProvider.openai]!
      ..key.text = value.openAiApiKey
      ..model.text = value.openAiModel;
    _forms[AiProvider.gemini]!
      ..key.text = value.geminiApiKey
      ..model.text = value.geminiModel;
    _forms[AiProvider.anthropic]!
      ..key.text = value.anthropicApiKey
      ..model.text = value.anthropicModel;
  }

  String _keyOf(AiProvider p) => _forms[p]!.key.text.trim();
  String _modelOf(AiProvider p) => _forms[p]!.model.text.trim();

  /// The form as settings; blank models fall back to the defaults.
  AiSettings _current({AiProvider? provider, bool? enabled}) {
    final initial = AiSettings.initial();
    String model(AiProvider p, String fallback) =>
        _modelOf(p).isEmpty ? fallback : _modelOf(p);
    return AiSettings(
      provider: provider ?? _provider,
      openAiApiKey: _keyOf(AiProvider.openai),
      openAiModel: model(AiProvider.openai, initial.openAiModel),
      geminiApiKey: _keyOf(AiProvider.gemini),
      geminiModel: model(AiProvider.gemini, initial.geminiModel),
      anthropicApiKey: _keyOf(AiProvider.anthropic),
      anthropicModel: model(AiProvider.anthropic, initial.anthropicModel),
      enableApiCalls: enabled ?? _enabled,
    );
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_enabled && _keyOf(_provider).isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Add a ${_provider.label} API key first')),
      );
      return;
    }
    await ref.read(aiSettingsProvider.notifier).save(_current());
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(const SnackBar(content: Text('AI settings saved')));
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset AI settings?'),
        content: const Text(
          'Every saved API key is removed and models go back to their '
          'defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(aiSettingsProvider.notifier).reset();
    if (!mounted) return;
    setState(() {
      _load(AiSettings.initial());
      _dirty = false;
    });
  }

  /// Sends a tiny prompt with the values currently in the form.
  Future<String?> _test(AiProvider provider) async {
    if (_keyOf(provider).isEmpty) return 'Enter an API key first';
    try {
      await const AiClient(
        requestTimeout: Duration(seconds: 30),
        totalBudget: Duration(seconds: 40),
        maxAttempts: 1,
      ).generate(
        settings: _current(provider: provider, enabled: true),
        prompt: 'Reply with the single word OK.',
      );
      return null;
    } catch (error) {
      return humanizeError(error);
    }
  }

  Future<void> _confirmDiscard() async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your AI settings before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'save') await _save();
    if (!mounted) return;
    if (action == 'discard' || !_dirty) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiSettingsProvider);
    ref.listen(aiSettingsProvider, (_, next) {
      final value = next.value;
      if (value == null || _dirty) return;
      setState(() => _load(value));
    });

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppScreenAppBar.build(
          context,
          ref,
          title: 'AI',
          extraActions: [
            AppBarCircularAction(
              icon: Icons.restart_alt,
              tooltip: 'Reset AI settings',
              onPressed: _reset,
            ),
          ],
        ),
        bottomNavigationBar: _dirty ? _SaveBar(onSave: _save) : null,
        body: settingsAsync.when(
          data: (settings) {
            if (!_initialized) {
              _load(settings);
              _initialized = true;
            }
            return _body(context);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatusMessage(
            icon: Icons.error_outline,
            title: 'Could not load AI settings',
            subtitle: humanizeError(error),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final status = context.statusColors;
    final activeKey = _keyOf(_provider).isNotEmpty;
    final model = _current().activeModel;

    final (String headline, Color? tone) = !_enabled
        ? ('Off · on-device calculations only', null)
        : activeKey
        ? ('${_provider.label} · $model', status.good)
        : ('No ${_provider.label} key yet', status.warning);

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: [
          SettingsPageHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'Cloud AI',
            status: headline,
            statusColor: tone,
            description:
                'Optional. Refines predictions, names places and tidies '
                'exports. Data leaves the phone only while this is on, and '
                'only to the provider you pick.',
          ),
          SettingsGroup(
            label: 'Use',
            children: [
              SettingsSwitchTile(
                icon: Icons.cloud_outlined,
                title: 'Send requests to a provider',
                subtitle: _enabled
                    ? 'AI refinements are available across the app.'
                    : 'Everything is calculated on this phone.',
                value: _enabled,
                onChanged: (on) => setState(() {
                  _enabled = on;
                  _dirty = true;
                }),
              ),
            ],
          ),
          SettingsGroup(
            label: 'Provider',
            footer:
                'Keys stay in the Android Keystore on this phone. A Drive '
                'backup includes them in plain text.',
            children: [
              for (final form in _forms.values)
                _ProviderTile(
                  key: ValueKey(form.provider),
                  form: form,
                  selected: form.provider == _provider,
                  dimmed: !_enabled,
                  onSelect: () {
                    if (form.provider == _provider) return;
                    setState(() {
                      _provider = form.provider;
                      _dirty = true;
                    });
                  },
                  onChanged: _markDirty,
                  onTest: () => _test(form.provider),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Leave a model blank to use the default.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save changes'),
        ),
      ),
    );
  }
}

/// One provider: a selectable header with its key state, and, while
/// selected, its key and model fields and a connection test.
class _ProviderTile extends StatefulWidget {
  const _ProviderTile({
    super.key,
    required this.form,
    required this.selected,
    required this.dimmed,
    required this.onSelect,
    required this.onChanged,
    required this.onTest,
  });

  final _ProviderForm form;
  final bool selected;
  final bool dimmed;
  final VoidCallback onSelect;
  final VoidCallback onChanged;

  /// Returns null on success, or a short error message.
  final Future<String?> Function() onTest;

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  bool _obscure = true;
  bool _testing = false;
  String? _result;
  bool _ok = false;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final error = await widget.onTest();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = error == null;
      _result = error ?? 'Connection works';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = context.statusColors;
    final form = widget.form;
    final selected = widget.selected;
    final active = selected && !widget.dimmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: ListenableBuilder(
            listenable: form.key,
            builder: (context, _) {
              final hasKey = form.key.text.trim().isNotEmpty;
              return SettingsTile(
                icon: form.icon,
                iconColor: active ? palette.accent : palette.textMuted,
                title: form.provider.label,
                subtitle: hasKey ? 'Key saved' : 'No key',
                subtitleColor: hasKey ? status.good : null,
                onTap: widget.onSelect,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active)
                      SettingsBadge(
                        'In use',
                        palette.accent,
                        icon: Icons.bolt_rounded,
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? palette.accent : palette.textMuted,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !selected
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kSettingsRowInset,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: form.key,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (_) => widget.onChanged(),
                        decoration: InputDecoration(
                          labelText: 'API key',
                          hintText: form.keyHint,
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show key' : 'Hide key',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: form.model,
                        autocorrect: false,
                        onChanged: (_) => widget.onChanged(),
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _test,
                            icon: _testing
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.network_check_rounded,
                                    size: 18,
                                  ),
                            label: Text(_testing ? 'Testing…' : 'Test'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          if (_result != null)
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _result!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _ok
                                            ? status.good
                                            : status.critical,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
