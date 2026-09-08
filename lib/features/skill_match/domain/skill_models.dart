enum CompetencyLevel { beginner, basic, intermediate, advanced }

extension CompetencyLevelDetails on CompetencyLevel {
  String get label => switch (this) {
    CompetencyLevel.beginner => 'Beginner',
    CompetencyLevel.basic => 'Basic',
    CompetencyLevel.intermediate => 'Intermediate',
    CompetencyLevel.advanced => 'Advanced',
  };

  int get score => switch (this) {
    CompetencyLevel.beginner => 20,
    CompetencyLevel.basic => 40,
    CompetencyLevel.intermediate => 65,
    CompetencyLevel.advanced => 85,
  };

  static CompetencyLevel fromScore(num score) {
    if (score >= 75) return CompetencyLevel.advanced;
    if (score >= 53) return CompetencyLevel.intermediate;
    if (score >= 30) return CompetencyLevel.basic;
    return CompetencyLevel.beginner;
  }
}

class SkillCompetency {
  const SkillCompetency({
    required this.id,
    required this.name,
    required this.targetLevel,
    required this.weight,
    this.category = 'Core skill',
    this.prerequisiteIds = const [],
    this.keywords = const [],
  });

  final String id;
  final String name;
  final double targetLevel;
  final double weight;
  final String category;
  final List<String> prerequisiteIds;
  final List<String> keywords;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target_level': targetLevel,
    'weight': weight,
    'category': category,
    'prerequisite_ids': prerequisiteIds,
    'keywords': keywords,
  };

  factory SkillCompetency.fromJson(Map<String, dynamic> json) =>
      SkillCompetency(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Unnamed skill'}',
        targetLevel: (json['target_level'] as num?)?.toDouble() ?? 0,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        category: '${json['category'] ?? 'Core skill'}',
        prerequisiteIds: _stringList(json['prerequisite_ids']),
        keywords: _stringList(json['keywords']),
      );
}

class RoleCompetencyProfile {
  const RoleCompetencyProfile({
    required this.id,
    required this.title,
    required this.industry,
    required this.competencies,
    this.isCustom = false,
  });

  final String id;
  final String title;
  final String industry;
  final List<SkillCompetency> competencies;
  final bool isCustom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'industry': industry,
    'is_custom': isCustom,
    'competencies': competencies.map((item) => item.toJson()).toList(),
  };

  factory RoleCompetencyProfile.fromJson(Map<String, dynamic> json) =>
      RoleCompetencyProfile(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Target role'}',
        industry: '${json['industry'] ?? 'General'}',
        isCustom: json['is_custom'] == true,
        competencies: (json['competencies'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  SkillCompetency.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
}

class SkillAssessmentAnswer {
  const SkillAssessmentAnswer({
    required this.competencyId,
    required this.level,
  });

  final String competencyId;
  final CompetencyLevel level;
  int get currentLevel => level.score;
}

class SkillAssessment {
  const SkillAssessment({
    this.id,
    required this.roleProfile,
    required this.answers,
    required this.readinessScore,
    required this.completedAt,
  });

  final String? id;
  final RoleCompetencyProfile roleProfile;
  final List<SkillAssessmentAnswer> answers;
  final double readinessScore;
  final DateTime completedAt;
}

class SkillGapResult {
  const SkillGapResult({
    required this.competency,
    required this.currentLevel,
    required this.gap,
    required this.weightedCurrent,
    required this.weightedTarget,
    required this.priorityScore,
  });

  final SkillCompetency competency;
  final double currentLevel;
  final double gap;
  final double weightedCurrent;
  final double weightedTarget;
  final double priorityScore;

  double get readinessRatio => competency.targetLevel <= 0
      ? 1
      : (currentLevel / competency.targetLevel).clamp(0, 1).toDouble();
}

class SkillGapAnalysis {
  const SkillGapAnalysis({
    required this.profile,
    required this.results,
    required this.readinessScore,
  });

  final RoleCompetencyProfile profile;
  final List<SkillGapResult> results;
  final double readinessScore;

  List<SkillGapResult> get priorityGaps {
    final gaps = results.where((item) => item.gap > 0).toList()
      ..sort((a, b) {
        final priority = b.priorityScore.compareTo(a.priorityScore);
        return priority != 0 ? priority : b.gap.compareTo(a.gap);
      });
    return gaps;
  }
}

class ProgrammeCandidate {
  const ProgrammeCandidate({
    required this.id,
    required this.name,
    required this.provider,
    required this.skills,
    this.level,
    this.durationDays,
    this.credential,
    this.summary,
    this.industry,
    this.targetRoles = const [],
    this.prerequisites,
    this.sourceName = '',
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String provider;
  final List<String> skills;
  final String? level;
  final int? durationDays;
  final String? credential;
  final String? summary;
  final String? industry;
  final List<String> targetRoles;
  final List<String>? prerequisites;
  final String sourceName;
  final String sourceUrl;
}

class ProgrammeScoreComponent {
  const ProgrammeScoreComponent({
    required this.label,
    required this.weight,
    required this.score,
    required this.explanation,
  });

  final String label;
  final double weight;
  final double? score;
  final String explanation;
  bool get isAvailable => score != null;
}

class RankedProgramme {
  const RankedProgramme({
    required this.programme,
    required this.matchScore,
    required this.components,
    required this.coveredSkillIds,
    required this.reasons,
  });

  final ProgrammeCandidate programme;
  final double matchScore;
  final List<ProgrammeScoreComponent> components;
  final List<String> coveredSkillIds;
  final List<String> reasons;
}

enum RoadmapStageStatus { notStarted, inProgress, completed }

extension RoadmapStageStatusDetails on RoadmapStageStatus {
  String get label => switch (this) {
    RoadmapStageStatus.notStarted => 'NOT STARTED',
    RoadmapStageStatus.inProgress => 'IN PROGRESS',
    RoadmapStageStatus.completed => 'COMPLETED',
  };

  String get databaseValue => switch (this) {
    RoadmapStageStatus.notStarted => 'not_started',
    RoadmapStageStatus.inProgress => 'in_progress',
    RoadmapStageStatus.completed => 'completed',
  };

  static RoadmapStageStatus fromDatabase(String? value) => switch (value) {
    'in_progress' => RoadmapStageStatus.inProgress,
    'completed' => RoadmapStageStatus.completed,
    _ => RoadmapStageStatus.notStarted,
  };
}

class LearningRoadmapStage {
  const LearningRoadmapStage({
    this.id,
    required this.sequence,
    required this.title,
    required this.skillId,
    required this.skillName,
    required this.targetLevel,
    required this.gapAtCreation,
    this.programmeId,
    this.programmeName,
    this.status = RoadmapStageStatus.notStarted,
  });

  final String? id;
  final int sequence;
  final String title;
  final String skillId;
  final String skillName;
  final double targetLevel;
  final double gapAtCreation;
  final String? programmeId;
  final String? programmeName;
  final RoadmapStageStatus status;

  LearningRoadmapStage copyWith({String? id, RoadmapStageStatus? status}) =>
      LearningRoadmapStage(
        id: id ?? this.id,
        sequence: sequence,
        title: title,
        skillId: skillId,
        skillName: skillName,
        targetLevel: targetLevel,
        gapAtCreation: gapAtCreation,
        programmeId: programmeId,
        programmeName: programmeName,
        status: status ?? this.status,
      );
}

class LearningRoadmap {
  const LearningRoadmap({
    this.id,
    this.assessmentId,
    required this.roleProfileId,
    required this.roleTitle,
    required this.stages,
    required this.createdAt,
  });

  final String? id;
  final String? assessmentId;
  final String roleProfileId;
  final String roleTitle;
  final List<LearningRoadmapStage> stages;
  final DateTime createdAt;

  int get completedStages => stages
      .where((stage) => stage.status == RoadmapStageStatus.completed)
      .length;

  double get progressPercent => stages.isEmpty
      ? 0
      : (completedStages / stages.length * 100).clamp(0, 100).toDouble();

  LearningRoadmap copyWith({String? id, List<LearningRoadmapStage>? stages}) =>
      LearningRoadmap(
        id: id ?? this.id,
        assessmentId: assessmentId,
        roleProfileId: roleProfileId,
        roleTitle: roleTitle,
        stages: stages ?? this.stages,
        createdAt: createdAt,
      );
}

List<String> _stringList(dynamic value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
    : const [];
