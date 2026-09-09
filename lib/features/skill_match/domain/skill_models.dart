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

  String get evidenceAnchor => switch (this) {
    CompetencyLevel.beginner =>
      'I need step-by-step guidance and cannot yet complete this independently.',
    CompetencyLevel.basic =>
      'I understand the basics and can complete simple tasks with some support.',
    CompetencyLevel.intermediate =>
      'I can complete normal work independently and troubleshoot familiar issues.',
    CompetencyLevel.advanced =>
      'I can handle complex work, explain decisions, and guide other people.',
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
    this.summary = '',
    this.aliases = const [],
    this.frameworkNote = '',
    this.frameworkSourceName = '',
    this.frameworkSourceUrl = '',
    this.isCustom = false,
  });

  final String id;
  final String title;
  final String industry;
  final List<SkillCompetency> competencies;
  final String summary;
  final List<String> aliases;
  final String frameworkNote;
  final String frameworkSourceName;
  final String frameworkSourceUrl;
  final bool isCustom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'industry': industry,
    'summary': summary,
    'aliases': aliases,
    'framework_note': frameworkNote,
    'framework_source_name': frameworkSourceName,
    'framework_source_url': frameworkSourceUrl,
    'is_custom': isCustom,
    'competencies': competencies.map((item) => item.toJson()).toList(),
  };

  factory RoleCompetencyProfile.fromJson(Map<String, dynamic> json) =>
      RoleCompetencyProfile(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Target role'}',
        industry: '${json['industry'] ?? 'General'}',
        summary: '${json['summary'] ?? ''}',
        aliases: _stringList(json['aliases']),
        frameworkNote: '${json['framework_note'] ?? ''}',
        frameworkSourceName: '${json['framework_source_name'] ?? ''}',
        frameworkSourceUrl: '${json['framework_source_url'] ?? ''}',
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
    this.metadataNote = '',
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
  final String metadataNote;
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
    required this.evidenceCoverage,
    required this.components,
    required this.coveredSkillIds,
    required this.reasons,
  });

  final ProgrammeCandidate programme;
  final double matchScore;
  final double evidenceCoverage;
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

class WorkforceSkillSignal {
  const WorkforceSkillSignal({
    required this.variable,
    required this.ageGroup,
    required this.observedOn,
    required this.value,
    required this.unit,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String variable;
  final String ageGroup;
  final DateTime observedOn;
  final double value;
  final String unit;
  final String sourceName;
  final String sourceUrl;

  factory WorkforceSkillSignal.fromSupabase(
    Map<String, dynamic> data,
  ) => WorkforceSkillSignal(
    variable: '${data['variable'] ?? 'Skills signal'}',
    ageGroup: '${data['age_group'] ?? 'Overall'}',
    observedOn:
        DateTime.tryParse('${data['observed_on'] ?? ''}') ?? DateTime(1970),
    value: (data['signal_value'] as num?)?.toDouble() ?? 0,
    unit: '${data['unit'] ?? 'unknown unit'}',
    sourceName: '${data['source_name'] ?? 'Department of Statistics Malaysia'}',
    sourceUrl:
        '${data['source_url'] ?? 'https://data.gov.my/data-catalogue/lfs_qtr_sru_age'}',
  );
}

class MalaysiaWorkforceInsight {
  const MalaysiaWorkforceInsight({
    required this.ageGroup,
    required this.observedOn,
    required this.rate,
    required this.sourceName,
    required this.sourceUrl,
    this.previousRate,
    this.peopleThousands,
  });

  final String ageGroup;
  final DateTime observedOn;
  final double rate;
  final double? previousRate;
  final double? peopleThousands;
  final String sourceName;
  final String sourceUrl;

  double? get rateChange => previousRate == null ? null : rate - previousRate!;

  String get periodLabel {
    final quarter = ((observedOn.month - 1) ~/ 3) + 1;
    return 'Q$quarter ${observedOn.year}';
  }
}

class SkillCoachMessage {
  const SkillCoachMessage({
    required this.text,
    required this.isUser,
    this.actionSteps = const [],
  });

  final String text;
  final bool isUser;
  final List<String> actionSteps;
}

List<String> _stringList(dynamic value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
    : const [];
