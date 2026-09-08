import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/features/skill_match/domain/skill_gap_engine.dart';
import 'package:industryhub/features/skill_match/domain/skill_models.dart';

void main() {
  const engine = SkillGapEngine();

  RoleCompetencyProfile profile(List<SkillCompetency> skills) =>
      RoleCompetencyProfile(
        id: 'test_role',
        title: 'Test Role',
        industry: 'Testing',
        competencies: skills,
      );

  SkillAssessmentAnswer answer(String id, CompetencyLevel level) =>
      SkillAssessmentAnswer(competencyId: id, level: level);

  group('SkillGapEngine', () {
    test('returns perfect readiness at every target', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 85, weight: 0.6),
          SkillCompetency(id: 'b', name: 'B', targetLevel: 40, weight: 0.4),
        ]),
        answers: [
          answer('a', CompetencyLevel.advanced),
          answer('b', CompetencyLevel.basic),
        ],
      );

      expect(result.readinessScore, 100);
      expect(result.results.every((item) => item.gap == 0), isTrue);
    });

    test('returns zero readiness when no competencies are answered', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 80, weight: 1),
        ]),
        answers: const [],
      );

      expect(result.readinessScore, 0);
      expect(result.results.single.currentLevel, 0);
      expect(result.results.single.gap, 80);
    });

    test('calculates partial weighted readiness', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 80, weight: 0.6),
          SkillCompetency(id: 'b', name: 'B', targetLevel: 80, weight: 0.4),
        ]),
        answers: [
          answer('a', CompetencyLevel.basic),
          answer('b', CompetencyLevel.basic),
        ],
      );

      expect(result.readinessScore, closeTo(50, 0.001));
    });

    test('caps competency above target at full readiness', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 40, weight: 1),
        ]),
        answers: [answer('a', CompetencyLevel.advanced)],
      );

      expect(result.readinessScore, 100);
      expect(result.results.single.gap, 0);
    });

    test('ignores invalid weights and returns zero if none are valid', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 85, weight: 0),
          SkillCompetency(id: 'b', name: 'B', targetLevel: 85, weight: -1),
        ]),
        answers: [
          answer('a', CompetencyLevel.advanced),
          answer('b', CompetencyLevel.advanced),
        ],
      );

      expect(result.readinessScore, 0);
      expect(result.results.every((item) => item.priorityScore == 0), isTrue);
    });

    test('handles multiple competencies and ranks weighted priority gaps', () {
      final result = engine.analyse(
        profile: profile(const [
          SkillCompetency(id: 'a', name: 'A', targetLevel: 80, weight: 0.5),
          SkillCompetency(id: 'b', name: 'B', targetLevel: 70, weight: 0.3),
          SkillCompetency(id: 'c', name: 'C', targetLevel: 40, weight: 0.2),
        ]),
        answers: [
          answer('a', CompetencyLevel.basic),
          answer('b', CompetencyLevel.beginner),
          answer('c', CompetencyLevel.basic),
        ],
      );

      expect(result.readinessScore, closeTo(53.57, 0.01));
      expect(result.priorityGaps.first.competency.id, 'a');
      expect(result.results.last.gap, 0);
    });
  });
}
