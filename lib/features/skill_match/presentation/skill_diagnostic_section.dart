import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../domain/skill_models.dart';

class SkillDiagnosticSection extends StatelessWidget {
  const SkillDiagnosticSection({
    super.key,
    required this.profile,
    required this.answers,
    required this.onAnswerChanged,
    required this.onSubmit,
    this.isReassessment = false,
    this.isSaving = false,
  });

  final RoleCompetencyProfile profile;
  final Map<String, CompetencyLevel> answers;
  final void Function(String competencyId, CompetencyLevel level)
  onAnswerChanged;
  final VoidCallback onSubmit;
  final bool isReassessment;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final complete = answers.length == profile.competencies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 2 / SKILL DIAGNOSTIC'),
        const SizedBox(height: 14),
        Text(
          isReassessment ? 'Reassess your skills' : 'Rate your current level',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          'Answer every competency. Levels map to fixed scores: Beginner 20, Basic 40, Intermediate 65, Advanced 85.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.4),
        ),
        const SizedBox(height: 12),
        ...profile.competencies.map(
          (competency) => _CompetencyQuestion(
            competency: competency,
            selected: answers[competency.id],
            onSelected: (level) => onAnswerChanged(competency.id, level),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${answers.length} / ${profile.competencies.length} answered',
                style: const TextStyle(color: AppColors.slate, fontSize: 12),
              ),
            ),
            FilledButton.icon(
              onPressed: complete && !isSaving ? onSubmit : null,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined, size: 18),
              label: Text(
                isReassessment ? 'Calculate new score' : 'Calculate readiness',
              ),
            ),
          ],
        ),
        if (!complete) ...[
          const SizedBox(height: 8),
          const Text(
            'Complete all questions to unlock the readiness analysis.',
            style: TextStyle(color: AppColors.rust, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _CompetencyQuestion extends StatelessWidget {
  const _CompetencyQuestion({
    required this.competency,
    required this.selected,
    required this.onSelected,
  });

  final SkillCompetency competency;
  final CompetencyLevel? selected;
  final ValueChanged<CompetencyLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    competency.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  'Target ${competency.targetLevel.round()}',
                  style: AppTheme.dataStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${competency.category} · ${(competency.weight * 100).round()}% weight',
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
            const SizedBox(height: 11),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                return Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: CompetencyLevel.values.map((level) {
                    final active = selected == level;
                    return ChoiceChip(
                      selected: active,
                      onSelected: (_) => onSelected(level),
                      label: Text('${level.label} · ${level.score}'),
                      labelStyle: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: active ? AppColors.white : AppColors.ink,
                      ),
                      selectedColor: AppColors.navy,
                      showCheckmark: false,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
