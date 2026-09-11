


import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/skill_models.dart';

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
    this.industry,
    this.targetRoles = const [],
    this.prerequisites,
    this.metadataNote = '',
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
  final String? industry;
  final List<String> targetRoles;
  final List<String>? prerequisites;
  final String metadataNote;

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
      industry: _optionalText(data['industry']),
      targetRoles: _readStringList(data['target_roles']),
      prerequisites: data.containsKey('prerequisites')
          ? _readStringList(data['prerequisites'])
          : null,
      metadataNote: _optionalText(data['metadata_note']) ?? '',
    );
  }

  ProgrammeCandidate toCandidate() => ProgrammeCandidate(
    id: id,
    name: name,
    provider: provider,
    skills: skills,
    level: level.trim().isEmpty || level == 'Unspecified level' ? null : level,
    durationDays: durationDays > 0 ? durationDays : null,
    credential: credential.trim().isEmpty ? null : credential,
    summary: summary.trim().isEmpty ? null : summary,
    industry: industry,
    targetRoles: targetRoles,
    prerequisites: prerequisites,
    metadataNote: metadataNote,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
  );
}

String? _optionalText(dynamic value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

List<String> _readStringList(dynamic value) => value is List
    ? value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

class TrainingProgrammeRepository {
  TrainingProgrammeRepository({SupabaseClient? supabase, http.Client? client})
    : _supabase = supabase ?? Supabase.instance.client,
      _client = client ?? http.Client();

  final SupabaseClient _supabase;
  final http.Client _client;
  Future<List<WorkforceSkillSignal>>? _workforceSignals;

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

  Future<List<WorkforceSkillSignal>> fetchWorkforceSkillSignals() =>
      _workforceSignals ??= _loadWorkforceSkillSignals();

  Future<List<WorkforceSkillSignal>> _loadWorkforceSkillSignals() async {
    try {
      final rows = await _supabase
          .from('workforce_skill_signals')
          .select()
          .eq('dataset_id', 'lfs_qtr_sru_age')
          .order('observed_on');
      if (rows.isNotEmpty) {
        return rows
            .map(
              (row) => WorkforceSkillSignal.fromSupabase(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {


    }

    final response = await _client
        .get(
          Uri.parse(
            'https://api.data.gov.my/data-catalogue?id=lfs_qtr_sru_age&limit=10000',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'DOSM workforce-skills API returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'DOSM workforce-skills response was not a list.',
      );
    }

    final signals = <WorkforceSkillSignal>[];
    for (final raw in decoded.whereType<Map>()) {
      final data = Map<String, dynamic>.from(raw);
      final age = '${data['age'] ?? ''}'.trim();
      final variable = '${data['variable'] ?? ''}'.trim();
      final observedOn = DateTime.tryParse('${data['date'] ?? ''}');
      final value = data['sru'] is num
          ? (data['sru'] as num).toDouble()
          : double.tryParse('${data['sru'] ?? ''}');
      if (age.isEmpty ||
          variable.isEmpty ||
          observedOn == null ||
          value == null ||
          !value.isFinite) {
        continue;
      }
      signals.add(
        WorkforceSkillSignal(
          variable: variable,
          ageGroup: age,
          observedOn: observedOn,
          value: value,
          unit: variable.toLowerCase().contains('rate')
              ? 'percent'
              : "persons ('000)",
          sourceName: 'Department of Statistics Malaysia',
          sourceUrl: 'https://data.gov.my/data-catalogue/lfs_qtr_sru_age',
        ),
      );
    }
    return List.unmodifiable(signals);
  }
}
