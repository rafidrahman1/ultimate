import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/recording/location_recorder.dart';
import 'package:personal/features/location/ui/recording_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Recording the timeline on the phone and saving it to Google Drive.
class LocationSettingsScreen extends ConsumerWidget {
  const LocationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationRecorderProvider).value;
    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Location timeline'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const SectionHeader(
              'Record my timeline',
              subtitle:
                  'Visits and trips detected on this phone, added after your '
                  'last Timeline export.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (status != null && !status.supported)
              const StatusMessage(
                icon: Icons.location_off_outlined,
                title: 'Recording the timeline is only available on Android.',
              )
            else
              const RecordingCard(),
          ],
        ),
      ),
    );
  }
}
