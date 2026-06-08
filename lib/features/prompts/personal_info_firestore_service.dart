import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/prompts/prompt_config_service.dart';

const _personalInfoDocId = 'profile';

class CloudPersonalInfo {
  const CloudPersonalInfo({required this.data, this.updatedAt});

  final Map<String, dynamic> data;
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
    await ref.set(
      {...config.toPersonalInfoJson(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    final snapshot = await ref.get();
    return _timestampToDateTime(snapshot.data()?['updatedAt']);
  }

  DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

final personalInfoFirestoreServiceProvider = Provider<PersonalInfoFirestoreService>(
  (ref) => PersonalInfoFirestoreService(),
);
