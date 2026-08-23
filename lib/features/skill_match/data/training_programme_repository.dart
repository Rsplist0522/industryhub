// Supabase access for the curated IndustryHub SkillMatch programme catalogue.
// Supabase-backed training programme records used by SkillMatch.

import 'package:supabase_flutter/supabase_flutter.dart';

class TrainingProgramme {
  const TrainingProgramme({
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

  factory TrainingProgramme.fromSupabase(Map<String, dynamic> data) {
    final rawSkills = data['skills'];
    final rawDuration = data['duration_days'] ?? data['durationDays'];
    return TrainingProgramme(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? data['title'] as String? ?? 'Unnamed programme',
      provider: data['provider'] as String? ?? 'Unspecified provider',
      skills: rawSkills is List ? rawSkills.map((skill) => '$skill').toList() : const [],
      level: data['level'] as String? ?? 'Unspecified level',
      durationDays: rawDuration is num ? rawDuration.toInt() : int.tryParse('$rawDuration') ?? 0,
      sourceName: data['source_name'] as String? ?? data['sourceName'] as String? ?? 'Supabase programme catalogue',
      sourceUrl: data['source_url'] as String? ?? data['sourceUrl'] as String? ?? '',
      credential: data['credential'] as String? ?? '',
      summary: data['summary'] as String? ?? data['description'] as String? ?? '',
    );
  }
}

class TrainingProgrammeRepository {
  TrainingProgrammeRepository({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<TrainingProgramme>> fetchActiveProgrammes() async {
    final rows = await _supabase.from('training_programmes').select().eq('is_active', true);
    return (rows as List)
        .map((row) => TrainingProgramme.fromSupabase(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
