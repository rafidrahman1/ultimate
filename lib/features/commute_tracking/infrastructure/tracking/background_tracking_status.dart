enum BackgroundTrackingPhase {
  idle,
  monitoring,
  tripActive,
  saving,
  error,
}

class BackgroundTrackingStatus {
  const BackgroundTrackingStatus({
    required this.phase,
    this.message,
    this.activeDistanceKm,
    this.lastSavedTripId,
  });

  final BackgroundTrackingPhase phase;
  final String? message;
  final double? activeDistanceKm;
  final String? lastSavedTripId;

  BackgroundTrackingStatus copyWith({
    BackgroundTrackingPhase? phase,
    String? message,
    double? activeDistanceKm,
    String? lastSavedTripId,
    bool clearMessage = false,
    bool clearLastSavedTripId = false,
  }) {
    return BackgroundTrackingStatus(
      phase: phase ?? this.phase,
      message: clearMessage ? null : (message ?? this.message),
      activeDistanceKm: activeDistanceKm ?? this.activeDistanceKm,
      lastSavedTripId: clearLastSavedTripId
          ? null
          : (lastSavedTripId ?? this.lastSavedTripId),
    );
  }
}
