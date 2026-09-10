import 'skill_models.dart';

class LearningRoadmapEngine {
  const LearningRoadmapEngine();

  LearningRoadmap build({
    required SkillGapAnalysis analysis,
    required List<RankedProgramme> rankedProgrammes,
    String? assessmentId,
    DateTime? createdAt,
  }) {
    final orderedGaps = _orderGaps(analysis);
    final stages = <LearningRoadmapStage>[];
    for (var index = 0; index < orderedGaps.length; index++) {
      final gap = orderedGaps[index];
      final programme = _bestProgrammeFor(gap.competency.id, rankedProgrammes);
      stages.add(
        LearningRoadmapStage(
          sequence: index + 1,
          title: gap.competency.category.toUpperCase(),
          skillId: gap.competency.id,
          skillName: gap.competency.name,
          targetLevel: gap.competency.targetLevel,
          gapAtCreation: gap.gap,
          programmeId: programme?.programme.id,
          programmeName: programme?.programme.name,
        ),
      );
    }
    return LearningRoadmap(
      assessmentId: assessmentId,
      roleProfileId: analysis.profile.id,
      roleTitle: analysis.profile.title,
      stages: stages,
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }

  List<SkillGapResult> _orderGaps(SkillGapAnalysis analysis) {
    final remaining = [...analysis.priorityGaps];
    final ordered = <SkillGapResult>[];
    final added = <String>{};

    while (remaining.isNotEmpty) {
      var selectedIndex = remaining.indexWhere(
        (gap) => gap.competency.prerequisiteIds.every(
          (id) =>
              added.contains(id) ||
              !remaining.any((item) => item.competency.id == id),
        ),
      );
      if (selectedIndex < 0) selectedIndex = 0;
      final selected = remaining.removeAt(selectedIndex);
      ordered.add(selected);
      added.add(selected.competency.id);
    }
    return ordered;
  }

  RankedProgramme? _bestProgrammeFor(
    String skillId,
    List<RankedProgramme> programmes,
  ) {
    for (final programme in programmes) {
      if (programme.coveredSkillIds.contains(skillId)) return programme;
    }
    return null;
  }
}
