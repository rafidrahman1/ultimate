import 'package:health/health.dart';

/// Types the app does not read or display.
const List<HealthDataType> samsungHealthExcludedTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.RESTING_HEART_RATE,
];

/// Every [HealthDataType] the `health` plugin can read on Android (Health Connect).
///
/// Samsung Health syncs into Health Connect; this is the full read surface the app
/// requests and fetches.
final List<HealthDataType> samsungHealthReadTypes = dataTypeKeysAndroid
    .where((type) => !samsungHealthExcludedTypes.contains(type))
    .toList(growable: false);

/// Body metrics where the latest value may be older than the monthly analysis window.
const List<HealthDataType> samsungHealthLongHistoryTypes = [
  HealthDataType.WEIGHT,
  HealthDataType.HEIGHT,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.BODY_WATER_MASS,
  HealthDataType.BODY_TEMPERATURE,
];

/// Types fetched for the monthly window (everything except long-history body metrics).
final List<HealthDataType> samsungHealthMonthlyTypes = samsungHealthReadTypes
    .where((type) => !samsungHealthLongHistoryTypes.contains(type))
    .toList(growable: false);

List<HealthDataAccess> samsungHealthReadAccessList() =>
    List.filled(samsungHealthReadTypes.length, HealthDataAccess.READ);

/// Human-readable labels for Health settings and summaries.
const Map<HealthDataType, String> healthTypeLabels = {
  HealthDataType.ACTIVE_ENERGY_BURNED: 'Active calories',
  HealthDataType.BASAL_ENERGY_BURNED: 'Basal metabolic rate',
  HealthDataType.BLOOD_GLUCOSE: 'Blood glucose',
  HealthDataType.BLOOD_OXYGEN: 'Blood oxygen',
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'Blood pressure (diastolic)',
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'Blood pressure (systolic)',
  HealthDataType.BODY_FAT_PERCENTAGE: 'Body fat',
  HealthDataType.BODY_MASS_INDEX: 'BMI',
  HealthDataType.BODY_TEMPERATURE: 'Body temperature',
  HealthDataType.BODY_WATER_MASS: 'Body water',
  HealthDataType.DISTANCE_DELTA: 'Distance',
  HealthDataType.FLIGHTS_CLIMBED: 'Floors climbed',
  HealthDataType.HEIGHT: 'Height',
  HealthDataType.MENSTRUATION_FLOW: 'Menstruation',
  HealthDataType.NUTRITION: 'Nutrition',
  HealthDataType.RESPIRATORY_RATE: 'Respiratory rate',
  HealthDataType.SLEEP_ASLEEP: 'Sleep (asleep)',
  HealthDataType.SLEEP_AWAKE: 'Sleep (awake)',
  HealthDataType.SLEEP_AWAKE_IN_BED: 'Sleep (awake in bed)',
  HealthDataType.SLEEP_DEEP: 'Sleep (deep)',
  HealthDataType.SLEEP_LIGHT: 'Sleep (light)',
  HealthDataType.SLEEP_OUT_OF_BED: 'Sleep (out of bed)',
  HealthDataType.SLEEP_REM: 'Sleep (REM)',
  HealthDataType.SLEEP_SESSION: 'Sleep session',
  HealthDataType.SLEEP_UNKNOWN: 'Sleep (unknown)',
  HealthDataType.STEPS: 'Steps',
  HealthDataType.TOTAL_CALORIES_BURNED: 'Total calories burned',
  HealthDataType.WATER: 'Hydration',
  HealthDataType.WEIGHT: 'Weight',
  HealthDataType.WORKOUT: 'Workouts',
};

String labelForHealthType(HealthDataType type) =>
    healthTypeLabels[type] ?? type.name.replaceAll('_', ' ').toLowerCase();
