import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/features/skill_match/domain/learning_roadmap_engine.dart';
import 'package:industryhub/features/skill_match/domain/skill_gap_engine.dart';
import 'package:industryhub/features/skill_match/domain/skill_models.dart';

void main() {
  const profile = RoleCompetencyProfile(
    id: 'role',
    title: 'Role',
    industry: 'Industry',
    competencies: [
      SkillCompetency(
        id: 'foundation',
        name: 'Foundation',
        targetLevel: 80,
        weight: 0.2,
        category: 'Foundation',
      ),
      SkillCompetency(
        id: 'advanced',
        name: 'Advanced Skill',
        targetLevel: 85,
        weight: 0.8,
        prerequisiteIds: ['foundation'],
        category: 'Development',
      ),
    ],
  );
  final analysis = const SkillGapEngine().analyse(
    profile: profile,
    answers: const [
      SkillAssessmentAnswer(
        competencyId: 'foundation',
        level: CompetencyLevel.beginner,
      ),
      SkillAssessmentAnswer(
        competencyId: 'advanced',
        level: CompetencyLevel.beginner,
      ),
    ],
  );

  test('orders prerequisites before larger dependent gaps', () {
    final roadmap = const LearningRoadmapEngine().build(
      analysis: analysis,
      rankedProgrammes: const [],
    );

    expect(roadmap.stages.map((stage) => stage.skillId), [
      'foundation',
      'advanced',
    ]);
  });

  test('calculates progress only from completed stages', () {
    final original = const LearningRoadmapEngine().build(
      analysis: analysis,
      rankedProgrammes: const [],
    );
    final roadmap = original.copyWith(
      stages: [
        original.stages[0].copyWith(status: RoadmapStageStatus.completed),
        original.stages[1].copyWith(status: RoadmapStageStatus.inProgress),
      ],
    );

    expect(roadmap.completedStages, 1);
    expect(roadmap.progressPercent, 50);
  });

  test('empty roadmap has zero progress', () {
    final roadmap = LearningRoadmap(
      roleProfileId: 'role',
      roleTitle: 'Role',
      stages: const [],
      createdAt: DateTime.utc(2026),
    );

    expect(roadmap.progressPercent, 0);
  });
}
