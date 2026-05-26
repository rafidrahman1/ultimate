import '../value_objects/physical_activity.dart';

/// Platform-agnostic activity recognition (driven by native AR APIs).
abstract class ActivityRecognitionPort {
  Stream<PhysicalActivity> activityUpdates();

  Future<bool> hasPermission();

  Future<bool> requestPermission();
}
