import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/status_message.dart';
import 'prompt_config_service.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends ConsumerState<PersonalInformationScreen> {
  final _professionController = TextEditingController();
  final _incomeController = TextEditingController();
  final _financialController = TextEditingController();
  final _fitnessController = TextEditingController();
  final _lifestyleController = TextEditingController();
  final _decisionSupportController = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _professionController.dispose();
    _incomeController.dispose();
    _financialController.dispose();
    _fitnessController.dispose();
    _lifestyleController.dispose();
    _decisionSupportController.dispose();
    super.dispose();
  }

  void _syncFromConfig(PromptConfig config) {
    _professionController.text = config.professionAndSchedule;
    _incomeController.text = config.monthlyIncomeBdt;
    _financialController.text = config.financialInstruction;
    _fitnessController.text = config.fitnessGoal;
    _lifestyleController.text = config.householdLifestyle;
    _decisionSupportController.text = config.decisionSupportRule;
  }

  PromptConfig _draftFromControllers(PromptConfig base) {
    return base.copyWith(
      professionAndSchedule: _professionController.text.trim(),
      monthlyIncomeBdt: _incomeController.text.trim(),
      financialInstruction: _financialController.text.trim(),
      fitnessGoal: _fitnessController.text.trim(),
      householdLifestyle: _lifestyleController.text.trim(),
      decisionSupportRule: _decisionSupportController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(promptConfigProvider);
    final theme = Theme.of(context);

    ref.listen(promptConfigProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _syncFromConfig(value);
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Personal information',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.restart_alt,
            onPressed: () async {
              final current = ref.read(promptConfigProvider).valueOrNull;
              if (current == null) return;
              final cleared = current.copyWith(
                professionAndSchedule: '',
                monthlyIncomeBdt: '',
                financialInstruction: '',
                fitnessGoal: '',
                householdLifestyle: '',
                decisionSupportRule: '',
              );
              await ref.read(promptConfigProvider.notifier).save(cleared);
              if (!mounted) return;
              setState(() => _dirty = false);
            },
          ),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          if (_professionController.text.isEmpty && !_dirty) {
            _syncFromConfig(config);
          }

          final draft = _draftFromControllers(config);
          final isComplete = draft.isPersonalInfoComplete;
          final missing = draft.missingPersonalInfoLabels;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Tell the assistant about you',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'These details are injected into every analysis run. '
                'Analysis stays disabled until all fields below are filled in.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _CompletionBanner(isComplete: isComplete, missing: missing),
              const SizedBox(height: 16),
              TextField(
                controller: _professionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Profession and schedule',
                  hintText: 'Job title, employer, and typical work hours',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly income (BDT)',
                  hintText: 'e.g. 80000',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _financialController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Financial rules',
                  hintText: 'Budget constraints and spending expectations',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fitnessController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Fitness goal',
                  hintText: 'Body goal, activity target, recovery requirements',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lifestyleController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Household and lifestyle',
                  hintText: 'Personal context that affects recommendations',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _decisionSupportController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Decision support rule',
                  hintText: 'How Buy/Skip or other verdicts should be handled',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final next = _draftFromControllers(config);
                  await ref.read(promptConfigProvider.notifier).save(next);
                  if (!mounted) return;
                  setState(() => _dirty = false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        next.isPersonalInfoComplete
                            ? 'Personal information saved'
                            : 'Saved — fill remaining fields to enable analysis',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save personal information'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load personal information',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.isComplete, required this.missing});

  final bool isComplete;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isComplete) {
      return Card(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
          title: const Text('Ready for analysis'),
          subtitle: const Text('All personal information fields are complete.'),
        ),
      );
    }

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Incomplete profile',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Still needed:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            ...missing.map(
              (label) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
