import '../value_objects/tracking_readiness.dart';

/// Ensures activity + location permissions and services are ready.
abstract class TrackingReadinessPort {
  Future<TrackingReadiness> evaluate();

  Future<TrackingReadiness> ensureReady();
}
