import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/features/skill_match/domain/programme_ranking_engine.dart';
import 'package:industryhub/features/skill_match/domain/skill_gap_engine.dart';
import 'package:industryhub/features/skill_match/domain/skill_models.dart';

void main() {
  const rankingEngine = ProgrammeRankingEngine();
  const profile = RoleCompetencyProfile(
    id: 'developer',
    title: 'Software Engineer',
    industry: 'Digital technology',
    competencies: [
      SkillCompetency(
        id: 'code',
        name: 'Programming',
        targetLevel: 85,
        weight: 0.7,
        keywords: ['coding'],
      ),
      SkillCompetency(
        id: 'sql',
        name: 'SQL',
        targetLevel: 70,
        weight: 0.3,
        keywords: ['database'],
      ),
    ],
  );
  final analysis = const SkillGapEngine().analyse(
    profile: profile,
    answers: const [
      SkillAssessmentAnswer(
        competencyId: 'code',
        level: CompetencyLevel.beginner,
      ),
      SkillAssessmentAnswer(
        competencyId: 'sql',
        level: CompetencyLevel.beginner,
      ),
    ],
  );

  ProgrammeCandidate candidate({
    required String id,
    required List<String> skills,
    String? level = 'Beginner',
    int? durationDays = 20,
    String? credential = 'Professional Certificate',
    String? industry = 'Digital technology',
    List<String>? prerequisites = const [],
  }) => ProgrammeCandidate(
    id: id,
    name: '$id programme',
    provider: 'Provider',
    skills: skills,
    level: level,
    durationDays: durationDays,
    credential: credential,
    industry: industry,
    prerequisites: prerequisites,
  );

  group('ProgrammeRankingEngine', () {
    test('gives a strong match a high deterministic score', () {
      final result = rankingEngine.scoreProgramme(
        programme: candidate(id: 'strong', skills: ['Programming', 'SQL']),
        analysis: analysis,
      );

      expect(result.coveredSkillIds, containsAll(['code', 'sql']));
      expect(result.matchScore, greaterThan(85));
      expect(result.evidenceCoverage, 100);
    });

    test('scores a weak partial match below a strong match', () {
      final strong = rankingEngine.scoreProgramme(
        programme: candidate(id: 'strong', skills: ['Programming', 'SQL']),
        analysis: analysis,
      );
      final weak = rankingEngine.scoreProgramme(
        programme: candidate(
          id: 'weak',
          skills: ['SQL'],
          level: 'Advanced',
          durationDays: 500,
          credential: null,
          industry: null,
          prerequisites: null,
        ),
        analysis: analysis,
      );

      expect(weak.matchScore, lessThan(strong.matchScore));
    });

    test('no skill overlap has zero coverage and is omitted from ranking', () {
      final noOverlap = candidate(id: 'unrelated', skills: ['Welding']);
      final scored = rankingEngine.scoreProgramme(
        programme: noOverlap,
        analysis: analysis,
      );
      final ranked = rankingEngine.rank(
        programmes: [noOverlap],
        analysis: analysis,
      );

      expect(scored.components.first.score, 0);
      expect(scored.coveredSkillIds, isEmpty);
      expect(ranked, isEmpty);
    });

    test(
      'marks missing optional information unavailable without inventing it',
      () {
        final result = rankingEngine.scoreProgramme(
          programme: candidate(
            id: 'minimal',
            skills: ['Programming'],
            level: null,
            durationDays: null,
            credential: null,
            industry: null,
            prerequisites: null,
          ),
          analysis: analysis,
        );

        expect(
          result.components
              .where((component) => component.score == null)
              .length,
          4,
        );
        expect(result.reasons.join(' '), contains('excluded'));
        expect(result.evidenceCoverage, 50);
      },
    );

    test('always clamps scores between zero and one hundred', () {
      final programmes = [
        candidate(id: 'strong', skills: ['Programming', 'SQL']),
        candidate(id: 'weak', skills: ['SQL'], durationDays: 900),
        candidate(id: 'none', skills: ['Welding']),
      ];

      for (final programme in programmes) {
        final score = rankingEngine
            .scoreProgramme(programme: programme, analysis: analysis)
            .matchScore;
        expect(score, inInclusiveRange(0, 100));
      }
    });

    test('sorts strongest match first', () {
      final ranked = rankingEngine.rank(
        programmes: [
          candidate(id: 'weak', skills: ['SQL'], level: 'Advanced'),
          candidate(id: 'strong', skills: ['Programming', 'SQL']),
        ],
        analysis: analysis,
      );

      expect(ranked.map((item) => item.programme.id), ['strong', 'weak']);
    });
  });
}
