import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

final healthServiceProvider = Provider((ref) => HealthService());

final healthAuthorizationProvider = FutureProvider<bool>((ref) async {
  final healthService = ref.watch(healthServiceProvider);
  return await healthService.authorize();
});

final healthDataProvider = FutureProvider<List<HealthDataPoint>>((ref) async {
  final isAuthorized = await ref.watch(healthAuthorizationProvider.future);
  if (!isAuthorized) return [];

  final healthService = ref.watch(healthServiceProvider);
  return await healthService.fetchHealthData();
});

class HealthService {
  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<bool> authorize() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    bool? hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);

    if (hasPermissions == false) {
      try {
        hasPermissions = await _health.requestAuthorization(_types, permissions: _permissions);
      } catch (e) {
        print("Error requesting health authorization: $e");
        return false;
      }
    }
    return hasPermissions ?? false;
  }

  Future<List<HealthDataPoint>> fetchHealthData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(startTime: yesterday, endTime: now, types: _types);

    return _health.removeDuplicates(healthData);
  }
}
