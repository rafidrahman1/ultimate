import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/bike/odometer_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';

const _personalInfoDocId = 'profile';

class CloudPersonalInfo {
  const CloudPersonalInfo({required this.data, this.updatedAt});

  final Map<String, dynamic> data;
  final DateTime? updatedAt;
}

class CloudOdometer {
  const CloudOdometer({required this.readings, this.updatedAt});

  final List<OdometerReading> readings;
  final DateTime? updatedAt;
}

class PersonalInfoFirestoreService {
  PersonalInfoFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('personalInfo')
        .doc(_personalInfoDocId);
  }

  Future<CloudPersonalInfo?> loadPersonalInfo(String uid) async {
    final snapshot = await _docRef(uid).get();
    if (!snapshot.exists) return null;

    final raw = snapshot.data();
    if (raw == null || raw.isEmpty) return null;

    final data = Map<String, dynamic>.from(raw);
    final updatedAt = _timestampToDateTime(data.remove('updatedAt'));
    return CloudPersonalInfo(data: data, updatedAt: updatedAt);
  }

  Future<DateTime?> savePersonalInfo(String uid, PromptConfig config) async {
    final ref = _docRef(uid);
    await ref.set({
      ...config.toPersonalInfoJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snapshot = await ref.get();
    return _timestampToDateTime(snapshot.data()?['updatedAt']);
  }

  /// Bike odometer readings, kept as extra fields on the same profile
  /// document as the personal information.
  Future<CloudOdometer?> loadOdometer(String uid) async {
    final data = (await _docRef(uid).get()).data();
    final raw = data?['bikeOdometer'];
    if (data == null || raw is! List) return null;
    return CloudOdometer(
      readings: [
        for (final j in raw)
          if (j is Map) OdometerReading.fromJson(Map<String, dynamic>.from(j)),
      ],
      updatedAt: _timestampToDateTime(data['bikeOdometerUpdatedAt']),
    );
  }

  /// Returns the server time of the write.
  Future<DateTime?> saveOdometer(
    String uid,
    List<OdometerReading> readings,
  ) async {
    final ref = _docRef(uid);
    await ref.set({
      'bikeOdometer': [for (final r in readings) r.toJson()],
      'bikeOdometerUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final snapshot = await ref.get();
    return _timestampToDateTime(snapshot.data()?['bikeOdometerUpdatedAt']);
  }

  DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

final personalInfoFirestoreServiceProvider =
    Provider<PersonalInfoFirestoreService>(
      (ref) => PersonalInfoFirestoreService(),
    );
