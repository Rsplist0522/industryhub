// Firestore access for the IndustryHub SkillMatch programme catalogue.
// This layer keeps Cloud Firestore document parsing outside the presentation UI.

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTrainingProgramme {
  const FirestoreTrainingProgramme({
    required this.id,
    required this.name,
    required this.provider,
    required this.skills,
    required this.level,
    required this.durationDays,
    required this.sourceName,
    required this.sourceUrl,
    required this.credential,
    required this.summary,
  });

  final String id;
  final String name;
  final String provider;
  final List<String> skills;
  final String level;
  final int durationDays;
  final String sourceName;
  final String sourceUrl;
  final String credential;
  final String summary;

  factory FirestoreTrainingProgramme.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawSkills = data['skills'];
    final rawDuration = data['durationDays'];

    return FirestoreTrainingProgramme(
      id: document.id,
      name: data['name'] as String? ?? 'Unnamed programme',
      provider: data['provider'] as String? ?? 'Unspecified provider',
      skills: rawSkills is List ? rawSkills.whereType<String>().toList() : const [],
      level: data['level'] as String? ?? 'Unspecified level',
      durationDays: rawDuration is num ? rawDuration.toInt() : 0,
      sourceName: data['sourceName'] as String? ?? 'Firestore programme catalogue',
      sourceUrl: data['sourceUrl'] as String? ?? '',
      credential: data['credential'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
    );
  }
}

class TrainingProgrammeRepository {
  TrainingProgrammeRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<FirestoreTrainingProgramme>> fetchActiveProgrammes() async {
    final snapshot = await _firestore.collection('training_programmes').where('active', isEqualTo: true).get();
    return snapshot.docs.map(FirestoreTrainingProgramme.fromDocument).toList();
  }
}
