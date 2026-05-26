import 'package:flutter_activity_recognition/flutter_activity_recognition.dart'
    as far;

import '../../domain/ports/activity_recognition_port.dart';
import '../../domain/value_objects/physical_activity.dart';

class FlutterActivityRecognitionAdapter implements ActivityRecognitionPort {
  FlutterActivityRecognitionAdapter({
    far.FlutterActivityRecognition? client,
  }) : _client = client ?? far.FlutterActivityRecognition.instance;

  final far.FlutterActivityRecognition _client;

  @override
  Stream<PhysicalActivity> activityUpdates() {
    return _client.activityStream.map(_mapActivity);
  }

  @override
  Future<bool> hasPermission() async {
    final result = await _client.checkPermission();
    return result == far.ActivityPermission.GRANTED;
  }

  @override
  Future<bool> requestPermission() async {
    final result = await _client.requestPermission();
    return result == far.ActivityPermission.GRANTED;
  }

  PhysicalActivity _mapActivity(far.Activity activity) {
    return PhysicalActivity(
      type: _mapType(activity.type),
      confidence: _mapConfidence(activity.confidence),
    );
  }

  PhysicalActivityType _mapType(far.ActivityType type) {
    return switch (type) {
      far.ActivityType.IN_VEHICLE => PhysicalActivityType.inVehicle,
      far.ActivityType.STILL => PhysicalActivityType.still,
      far.ActivityType.WALKING => PhysicalActivityType.walking,
      far.ActivityType.RUNNING => PhysicalActivityType.running,
      far.ActivityType.ON_BICYCLE => PhysicalActivityType.onBicycle,
      far.ActivityType.UNKNOWN => PhysicalActivityType.unknown,
    };
  }

  ActivityConfidenceLevel _mapConfidence(far.ActivityConfidence confidence) {
    return switch (confidence) {
      far.ActivityConfidence.HIGH => ActivityConfidenceLevel.high,
      far.ActivityConfidence.MEDIUM => ActivityConfidenceLevel.medium,
      far.ActivityConfidence.LOW => ActivityConfidenceLevel.low,
    };
  }
}
