import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/work_schedule_settings_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/data_folder_picker_section.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  final _workAddressController = TextEditingController();
  final _workHoursController = TextEditingController();

  bool _dirty = false;
  bool _initialized = false;

  @override
  void dispose() {
    _workAddressController.dispose();
    _workHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(workScheduleSettingsProvider);

    ref.listen(workScheduleSettingsProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _loadFromSettings(value);
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'General settings'),
      body: settingsAsync.when(
        data: (settings) {
          if (!_initialized) {
            _loadFromSettings(settings);
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DataFolderPickerSection(
                onFolderChanged: () {
                  ref
                      .read(locationSummaryProvider.notifier)
                      .loadFromConfiguredFolder();
                  ref
                      .read(gameActivitySummaryProvider.notifier)
                      .loadFromConfiguredFolder();
                },
              ),
              const SizedBox(height: 32),
              const SectionHeader(
                'Work schedule',
                subtitle:
                    'Used to compute late-arrival stats from your location timeline.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _workAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Work address',
                          hintText:
                              'Matches place names in your Timeline export',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _workHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Work hours',
                          hintText: 'e.g. 9:00 AM - 6:00 PM',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _dirty ? () => _saveWorkSchedule() : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save work schedule'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load settings',
          subtitle: error.toString(),
        ),
      ),
    );
  }

  Future<void> _saveWorkSchedule() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(workScheduleSettingsProvider.notifier)
        .save(
          workAddress: _workAddressController.text.trim(),
          workHours: _workHoursController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Work schedule saved')),
    );
  }

  void _loadFromSettings(WorkScheduleSettings value) {
    _workAddressController.text = value.workAddress;
    _workHoursController.text = value.workHours;
  }
}
