/// Normalized activity type from the recognition layer.
enum PhysicalActivityType {
  inVehicle,
  still,
  walking,
  running,
  onBicycle,
  unknown,
}

enum ActivityConfidenceLevel {
  low,
  medium,
  high,
}

class PhysicalActivity {
  const PhysicalActivity({
    required this.type,
    required this.confidence,
  });

  final PhysicalActivityType type;
  final ActivityConfidenceLevel confidence;

  bool get isHighConfidence => confidence == ActivityConfidenceLevel.high;

  bool get isInVehicle => type == PhysicalActivityType.inVehicle;

  bool get isStill => type == PhysicalActivityType.still;
}
