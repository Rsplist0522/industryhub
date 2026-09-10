import 'dart:math' as math;

import 'skill_models.dart';

/// Pure, deterministic readiness calculation.
///
/// For every positively weighted competency, readiness contributes
/// `weight * min(current / target, 1)`. The weighted contributions are divided
/// by the sum of valid weights and converted to a percentage.
class SkillGapEngine {
  const SkillGapEngine();

  SkillGapAnalysis analyse({
    required RoleCompetencyProfile profile,
    required Iterable<SkillAssessmentAnswer> answers,
  }) {
    final answerById = {
      for (final answer in answers) answer.competencyId: answer,
    };
    var weightedReadiness = 0.0;
    var validWeightTotal = 0.0;
    final results = <SkillGapResult>[];

    for (final competency in profile.competencies) {
      final current = (answerById[competency.id]?.currentLevel ?? 0)
          .clamp(0, 100)
          .toDouble();
      final target = competency.targetLevel.clamp(0, 100).toDouble();
      final weight = competency.weight.isFinite && competency.weight > 0
          ? competency.weight
          : 0.0;
      final gap = math.max(target - current, 0).toDouble();
      final ratio = target <= 0 ? 1.0 : math.min(current / target, 1.0);

      weightedReadiness += weight * ratio;
      validWeightTotal += weight;
      results.add(
        SkillGapResult(
          competency: competency,
          currentLevel: current,
          gap: gap,
          weightedCurrent: current * weight,
          weightedTarget: target * weight,
          priorityScore: gap * weight,
        ),
      );
    }

    final readiness = validWeightTotal == 0
        ? 0.0
        : (weightedReadiness / validWeightTotal * 100).clamp(0, 100).toDouble();
    return SkillGapAnalysis(
      profile: profile,
      results: results,
      readinessScore: readiness,
    );
  }
}
