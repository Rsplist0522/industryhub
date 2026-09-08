import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../domain/skill_models.dart';

class LearningRoadmapWidget extends StatelessWidget {
  const LearningRoadmapWidget({
    super.key,
    required this.roadmap,
    required this.onStatusChanged,
    required this.onReassess,
    this.savingStageId,
  });

  final LearningRoadmap roadmap;
  final void Function(LearningRoadmapStage stage, RoadmapStageStatus status)
  onStatusChanged;
  final VoidCallback onReassess;
  final String? savingStageId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 5–7 / LEARNING ROADMAP'),
        const SizedBox(height: 14),
        Text(
          'Personal learning roadmap',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          'Prerequisites come first, followed by the largest weighted skill gaps.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: 12),
        MetricStrip(
          metrics: [
            MapEntry('ROADMAP PROGRESS', '${roadmap.progressPercent.round()}%'),
            MapEntry(
              'COMPLETED',
              '${roadmap.completedStages} / ${roadmap.stages.length} stages',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (roadmap.stages.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No roadmap stages are needed because no skill gaps were measured.',
              ),
            ),
          ),
        ...roadmap.stages.map(
          (stage) => _RoadmapStageCard(
            stage: stage,
            isSaving: savingStageId == stage.id,
            onChanged: (status) => onStatusChanged(stage, status),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onReassess,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('REASSESS SKILLS'),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Completing a stage does not change readiness. Only a new diagnostic creates a new score.',
          style: TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    );
  }
}

class _RoadmapStageCard extends StatelessWidget {
  const _RoadmapStageCard({
    required this.stage,
    required this.onChanged,
    required this.isSaving,
  });

  final LearningRoadmapStage stage;
  final ValueChanged<RoadmapStageStatus> onChanged;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage.status) {
      RoadmapStageStatus.notStarted => AppColors.slate,
      RoadmapStageStatus.inProgress => AppColors.amber,
      RoadmapStageStatus.completed => AppColors.green,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${stage.sequence}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(stage.title, color: color),
                  const SizedBox(height: 3),
                  Text(
                    stage.skillName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (stage.programmeName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      stage.programmeName!,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RoadmapStageStatus>(
                    initialValue: stage.status,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Stage status',
                    ),
                    items: RoadmapStageStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (value) {
                            if (value != null) onChanged(value);
                          },
                  ),
                ],
              ),
            ),
            if (isSaving) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
