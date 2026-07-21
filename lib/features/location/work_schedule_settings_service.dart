import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _workAddressKey = 'work_schedule_address_v1';
const _workHoursKey = 'work_schedule_hours_v1';

/// Work address + hours used only to compute late-arrival stats from location data.
class WorkScheduleSettings {
  const WorkScheduleSettings({this.workAddress = '', this.workHours = ''});

  final String workAddress;
  final String workHours;

  bool get isConfigured => workAddress.trim().isNotEmpty;
}

final workScheduleSettingsProvider =
    AsyncNotifierProvider<WorkScheduleSettingsNotifier, WorkScheduleSettings>(
      WorkScheduleSettingsNotifier.new,
    );

class WorkScheduleSettingsNotifier extends AsyncNotifier<WorkScheduleSettings> {
  @override
  Future<WorkScheduleSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkScheduleSettings(
      workAddress: prefs.getString(_workAddressKey) ?? '',
      workHours: prefs.getString(_workHoursKey) ?? '',
    );
  }

  Future<void> save({
    required String workAddress,
    required String workHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workAddressKey, workAddress);
    await prefs.setString(_workHoursKey, workHours);
    state = AsyncData(
      WorkScheduleSettings(workAddress: workAddress, workHours: workHours),
    );
  }
}
