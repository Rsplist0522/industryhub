import 'dart:convert';

import '../../../core/services.dart';
import '../domain/skill_models.dart';

class SkillCoachService {
  SkillCoachService({this.aiService = const AiService()});

  final AiService aiService;

  Future<SkillCoachMessage> ask({
    required String question,
    required SkillGapAnalysis analysis,
    required List<RankedProgramme> programmes,
    required LearningRoadmap? roadmap,
    required MalaysiaWorkforceInsight? workforceInsight,
  }) async {
    final response = await aiService.callAI(
      _systemPrompt,
      jsonEncode({
        'question': question.trim(),
        'verified_calculated_context': {
          'role': analysis.profile.title,
          'readiness_score': analysis.readinessScore.round(),
          'priority_gaps': analysis.priorityGaps
              .take(4)
              .map(
                (gap) => {
                  'skill': gap.competency.name,
                  'current': gap.currentLevel.round(),
                  'target': gap.competency.targetLevel.round(),
                  'gap': gap.gap.round(),
                  'weight_percent': (gap.competency.weight * 100).round(),
                },
              )
              .toList(),
          'ranked_programmes': programmes
              .take(3)
              .map(
                (ranked) => {
                  'name': ranked.programme.name,
                  'provider': ranked.programme.provider,
                  'match_score': ranked.matchScore.round(),
                  'evidence_coverage_percent': ranked.evidenceCoverage.round(),
                  'reasons': ranked.reasons,
                },
              )
              .toList(),
          'roadmap': roadmap?.stages
              .map(
                (stage) => {
                  'sequence': stage.sequence,
                  'skill': stage.skillName,
                  'status': stage.status.label,
                  'programme': stage.programmeName,
                },
              )
              .toList(),
          'malaysia_government_context': workforceInsight == null
              ? null
              : {
                  'dataset':
                      'DOSM Quarterly Skills-Related Underemployment by Age',
                  'age_group': workforceInsight.ageGroup,
                  'period': workforceInsight.periodLabel,
                  'rate_percent': workforceInsight.rate,
                  'change_from_previous_quarter_points':
                      workforceInsight.rateChange,
                  'people_thousands': workforceInsight.peopleThousands,
                  'source_url': workforceInsight.sourceUrl,
                  'scope_note':
                      'National or age-group context only; not a role-demand forecast and not part of personal readiness.',
                },
        },
      }),
    );
    final answer = '${response['answer'] ?? ''}'.trim();
    if (answer.isEmpty) {
      throw const FormatException('AI coach returned no answer.');
    }
    final rawSteps = response['action_steps'];
    final steps = rawSteps is List
        ? rawSteps
              .map((step) => '$step'.trim())
              .where((step) => step.isNotEmpty)
              .take(4)
              .toList()
        : const <String>[];
    return SkillCoachMessage(text: answer, isUser: false, actionSteps: steps);
  }

  static const _systemPrompt = '''
You are the IndustryHub SkillMatch AI coach for Malaysian industrial workforce development.
Return exactly a JSON object with: answer (string), action_steps (array of short strings).
Use only verified_calculated_context. Treat every supplied number, programme name, status, and government value as immutable evidence.
Never calculate, replace, round differently, or invent a readiness score, skill gap, match score, programme, credential, labour statistic, or completed activity.
Explain the deterministic results in practical language and answer the user's question directly.
When discussing the DOSM statistic, state that it measures tertiary-educated people in semi-skilled or low-skilled work and is context, not proof of demand for the selected role.
If information is absent, say it is unavailable. Never claim that finishing a roadmap stage automatically improves readiness; only reassessment does that.
Keep the answer under 130 words and make action steps specific to the supplied gaps and roadmap.
''';
}
