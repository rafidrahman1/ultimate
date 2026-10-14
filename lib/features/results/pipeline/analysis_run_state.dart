part of 'analysis_service.dart';

/// What a running analysis is doing, for the progress sheet.
enum AnalysisStage {
  gatheringData('Gathering your data'),
  callingModel('Waiting for the AI response'),
  checkingReport('Checking the report format'),
  addingCalendarEvents('Adding upcoming calendar events'),
  saving('Saving the report');

  const AnalysisStage(this.label);

  final String label;
}

class AnalysisRunState {
  const AnalysisRunState({
    this.isRunning = false,
    this.stage,
    this.startedAt,
    this.lastError,
    this.lastRunAt,
  });

  final bool isRunning;
  final AnalysisStage? stage;
  final DateTime? startedAt;
  final String? lastError;
  final DateTime? lastRunAt;

  AnalysisRunState copyWith({
    bool? isRunning,
    AnalysisStage? stage,
    DateTime? startedAt,
    String? lastError,
    bool clearError = false,
    DateTime? lastRunAt,
  }) {
    final running = isRunning ?? this.isRunning;
    return AnalysisRunState(
      isRunning: running,
      // Stage and start time only mean something while a run is active.
      stage: running ? (stage ?? this.stage) : null,
      startedAt: running ? (startedAt ?? this.startedAt) : null,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

final analysisRunProvider =
    StateNotifierProvider<AnalysisRunController, AnalysisRunState>(
      (ref) => AnalysisRunController(ref),
    );
