import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../domain/skill_models.dart';

class SkillGapResults extends StatelessWidget {
  const SkillGapResults({
    super.key,
    required this.analysis,
    this.firstAssessment,
  });

  final SkillGapAnalysis analysis;
  final SkillAssessment? firstAssessment;

  @override
  Widget build(BuildContext context) {
    final first = firstAssessment;
    final baselineLevels = {
      for (final answer in first?.answers ?? const <SkillAssessmentAnswer>[])
        answer.competencyId: answer.currentLevel,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 3 / YOUR SKILL GAP'),
        const SizedBox(height: 14),
        Card(
          color: AppColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.profile.title.toUpperCase(),
                  style: AppTheme.eyebrowStyle.copyWith(color: AppColors.amber),
                ),
                const SizedBox(height: 7),
                Text(
                  '${analysis.readinessScore.round()} / 100',
                  style: AppTheme.dataStyle.copyWith(
                    color: AppColors.white,
                    fontSize: 30,
                  ),
                ),
                const Text(
                  'Overall readiness',
                  style: TextStyle(color: AppColors.white),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: analysis.readinessScore / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: AppColors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(AppColors.green),
                ),
                if (first != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _ComparisonValue(
                        label: 'BEFORE',
                        value: '${first.readinessScore.round()}',
                      ),
                      _ComparisonValue(
                        label: 'AFTER',
                        value: '${analysis.readinessScore.round()}',
                      ),
                      _ComparisonValue(
                        label: 'IMPROVEMENT',
                        value:
                            '${analysis.readinessScore - first.readinessScore >= 0 ? '+' : ''}${(analysis.readinessScore - first.readinessScore).round()} points',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('How this score is calculated'),
            subtitle: const Text('Transparent and deterministic - not AI'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: const [
              Text(
                'For each competency, SkillMatch divides your fixed level score by the target, caps it at 100%, and multiplies it by the competency weight. The weighted results are added and converted to a 0-100 readiness score. Priority gaps use gap size x weight.',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...analysis.results.map(
          (gap) => _GapRow(
            gap: gap,
            baselineLevel: baselineLevels[gap.competency.id],
          ),
        ),
        const SizedBox(height: 8),
        const Eyebrow('TOP PRIORITY SKILLS', color: AppColors.rust),
        const SizedBox(height: 8),
        ...analysis.priorityGaps
            .take(3)
            .toList()
            .asMap()
            .entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${entry.key + 1}. ${entry.value.competency.name} · ${entry.value.gap.round()} point gap',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
      ],
    );
  }
}

class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTheme.eyebrowStyle.copyWith(color: AppColors.amber),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, this.baselineLevel});

  final SkillGapResult gap;
  final int? baselineLevel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gap.competency.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Gap ${gap.gap.round()}',
                  style: TextStyle(
                    color: gap.gap > 25 ? AppColors.rust : AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: gap.currentLevel / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
            const SizedBox(height: 6),
            Text(
              'Current ${gap.currentLevel.round()}  ·  Target ${gap.competency.targetLevel.round()}  ·  Weight ${(gap.competency.weight * 100).round()}%',
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
            if (baselineLevel != null) ...[
              const SizedBox(height: 4),
              Text(
                'Since first assessment: ${(gap.currentLevel - baselineLevel!) >= 0 ? '+' : ''}${(gap.currentLevel - baselineLevel!).round()} points',
                style: TextStyle(
                  color: gap.currentLevel >= baselineLevel!
                      ? AppColors.green
                      : AppColors.rust,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
