import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/skill_models.dart';

class SkillAssessmentRepository {
  SkillAssessmentRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before saving SkillMatch progress.');
    }
    return user;
  }

  Future<SkillAssessment> saveAssessment(SkillAssessment assessment) async {
    final user = _requireUser();
    final row = await _supabase
        .from('skill_assessments')
        .insert({
          'user_id': user.id,
          'role_profile_id': assessment.roleProfile.id,
          'role_title': assessment.roleProfile.title,
          'role_profile': assessment.roleProfile.toJson(),
          'readiness_score': assessment.readinessScore,
          'completed_at': assessment.completedAt.toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final assessmentId = '${row['id']}';
    final competencies = {
      for (final item in assessment.roleProfile.competencies) item.id: item,
    };
    await _supabase
        .from('skill_assessment_scores')
        .insert(
          assessment.answers.map((answer) {
            final competency = competencies[answer.competencyId]!;
            return {
              'user_id': user.id,
              'assessment_id': assessmentId,
              'competency_id': competency.id,
              'competency_name': competency.name,
              'current_level': answer.currentLevel,
              'target_level': competency.targetLevel,
              'competency_weight': competency.weight,
            };
          }).toList(),
        );
    return SkillAssessment(
      id: assessmentId,
      roleProfile: assessment.roleProfile,
      answers: assessment.answers,
      readinessScore: assessment.readinessScore,
      completedAt: assessment.completedAt,
    );
  }

  Future<List<SkillAssessment>> fetchAssessmentHistory(
    String roleProfileId,
  ) async {
    final user = _requireUser();
    final rows = await _supabase
        .from('skill_assessments')
        .select('id, role_profile, readiness_score, completed_at')
        .eq('user_id', user.id)
        .eq('role_profile_id', roleProfileId)
        .order('completed_at');
    final assessments = <SkillAssessment>[];
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final scoreRows = await _supabase
          .from('skill_assessment_scores')
          .select('competency_id, current_level')
          .eq('assessment_id', '${row['id']}');
      final profile = RoleCompetencyProfile.fromJson(
        Map<String, dynamic>.from(row['role_profile'] as Map),
      );
      assessments.add(
        SkillAssessment(
          id: '${row['id']}',
          roleProfile: profile,
          answers: (scoreRows as List).map((rawScore) {
            final score = Map<String, dynamic>.from(rawScore as Map);
            return SkillAssessmentAnswer(
              competencyId: '${score['competency_id']}',
              level: CompetencyLevelDetails.fromScore(
                (score['current_level'] as num?) ?? 0,
              ),
            );
          }).toList(),
          readinessScore: (row['readiness_score'] as num?)?.toDouble() ?? 0,
          completedAt:
              DateTime.tryParse('${row['completed_at']}') ?? DateTime.now(),
        ),
      );
    }
    return assessments;
  }

  Future<LearningRoadmap> saveRoadmap(LearningRoadmap roadmap) async {
    final user = _requireUser();
    if (roadmap.assessmentId == null) {
      throw ArgumentError('A saved assessment is required for a roadmap.');
    }
    final row = await _supabase
        .from('learning_roadmaps')
        .insert({
          'user_id': user.id,
          'assessment_id': roadmap.assessmentId,
          'role_profile_id': roadmap.roleProfileId,
          'role_title': roadmap.roleTitle,
        })
        .select('id, created_at')
        .single();
    final roadmapId = '${row['id']}';
    final itemRows = await _supabase
        .from('learning_roadmap_items')
        .insert(
          roadmap.stages
              .map(
                (stage) => {
                  'user_id': user.id,
                  'roadmap_id': roadmapId,
                  'sequence_no': stage.sequence,
                  'stage_title': stage.title,
                  'skill_id': stage.skillId,
                  'skill_name': stage.skillName,
                  'target_level': stage.targetLevel,
                  'gap_at_creation': stage.gapAtCreation,
                  'programme_id': stage.programmeId,
                  'programme_name': stage.programmeName,
                  'status': stage.status.databaseValue,
                },
              )
              .toList(),
        )
        .select('id, sequence_no');
    final idsBySequence = {
      for (final raw in itemRows as List)
        (raw as Map)['sequence_no'] as int: '${raw['id']}',
    };
    return LearningRoadmap(
      id: roadmapId,
      assessmentId: roadmap.assessmentId,
      roleProfileId: roadmap.roleProfileId,
      roleTitle: roadmap.roleTitle,
      createdAt: DateTime.tryParse('${row['created_at']}') ?? roadmap.createdAt,
      stages: roadmap.stages
          .map((stage) => stage.copyWith(id: idsBySequence[stage.sequence]))
          .toList(),
    );
  }

  Future<LearningRoadmap?> fetchLatestRoadmap(String roleProfileId) async {
    final user = _requireUser();
    final row = await _supabase
        .from('learning_roadmaps')
        .select('id, assessment_id, role_profile_id, role_title, created_at')
        .eq('user_id', user.id)
        .eq('role_profile_id', roleProfileId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final items = await _supabase
        .from('learning_roadmap_items')
        .select()
        .eq('roadmap_id', '${row['id']}')
        .order('sequence_no');
    return LearningRoadmap(
      id: '${row['id']}',
      assessmentId: '${row['assessment_id']}',
      roleProfileId: '${row['role_profile_id']}',
      roleTitle: '${row['role_title']}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
      stages: (items as List).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return LearningRoadmapStage(
          id: '${item['id']}',
          sequence: (item['sequence_no'] as num?)?.toInt() ?? 0,
          title: '${item['stage_title']}',
          skillId: '${item['skill_id']}',
          skillName: '${item['skill_name']}',
          targetLevel: (item['target_level'] as num?)?.toDouble() ?? 0,
          gapAtCreation: (item['gap_at_creation'] as num?)?.toDouble() ?? 0,
          programmeId: item['programme_id'] as String?,
          programmeName: item['programme_name'] as String?,
          status: RoadmapStageStatusDetails.fromDatabase(
            item['status'] as String?,
          ),
        );
      }).toList(),
    );
  }

  Future<void> updateStageStatus(
    String stageId,
    RoadmapStageStatus status,
  ) async {
    final user = _requireUser();
    await _supabase
        .from('learning_roadmap_items')
        .update({'status': status.databaseValue})
        .eq('id', stageId)
        .eq('user_id', user.id);
  }
}
