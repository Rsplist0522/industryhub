// Supabase access for the live IndustryHub SkillMatch programme catalogue.
// Records are populated from the Dart live-data importer and ranked by SkillMatch.

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
      name:
          data['name'] as String? ??
          data['title'] as String? ??
          'Unnamed programme',
      provider: data['provider'] as String? ?? 'Unspecified provider',
      skills: rawSkills is List
          ? rawSkills.map((skill) => '$skill').toList()
          : const [],
      level: data['level'] as String? ?? 'Unspecified level',
      durationDays: rawDuration is num
          ? rawDuration.toInt()
          : int.tryParse('$rawDuration') ?? 0,
      sourceName:
          data['source_name'] as String? ??
          data['sourceName'] as String? ??
          'Supabase programme catalogue',
      sourceUrl:
          data['source_url'] as String? ?? data['sourceUrl'] as String? ?? '',
      credential: data['credential'] as String? ?? '',
      summary:
          data['summary'] as String? ?? data['description'] as String? ?? '',
    );
  }
}

class WorkforceSkillSignal {
  const WorkforceSkillSignal({
    required this.variable,
    required this.ageGroup,
    required this.observedOn,
    required this.value,
    required this.unit,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String variable;
  final String ageGroup;
  final DateTime observedOn;
  final double value;
  final String unit;
  final String sourceName;
  final String sourceUrl;

  factory WorkforceSkillSignal.fromSupabase(Map<String, dynamic> data) =>
      WorkforceSkillSignal(
        variable: data['variable'] as String? ?? 'Skills signal',
        ageGroup: data['age_group'] as String? ?? 'Overall',
        observedOn:
            DateTime.tryParse(data['observed_on'] as String? ?? '') ??
            DateTime.now(),
        value: (data['signal_value'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] as String? ?? 'unknown unit',
        sourceName:
            data['source_name'] as String? ??
            'Department of Statistics Malaysia',
        sourceUrl:
            data['source_url'] as String? ??
            'https://data.gov.my/data-catalogue/lfs_qtr_sru_age',
      );
}

class TrainingProgrammeRepository {
  TrainingProgrammeRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<TrainingProgramme>> fetchActiveProgrammes() async {
    final rows = await _supabase
        .from('training_programmes')
        .select()
        .eq('is_active', true);
    return (rows as List)
        .map(
          (row) => TrainingProgramme.fromSupabase(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<WorkforceSkillSignal?> fetchLatestWorkforceSignal() async {
    final rows = await _supabase
        .from('workforce_skill_signals')
        .select()
        .eq('dataset_id', 'lfs_qtr_sru_age')
        .eq('age_group', 'Overall')
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return WorkforceSkillSignal.fromSupabase(
      Map<String, dynamic>.from(rows.first),
    );
  }
}
