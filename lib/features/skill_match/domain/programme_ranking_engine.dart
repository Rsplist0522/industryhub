import 'skill_models.dart';

class ProgrammeRankingEngine {
  const ProgrammeRankingEngine();

  static const double skillCoverageWeight = 0.40;
  static const double levelSuitabilityWeight = 0.20;
  static const double certificationWeight = 0.15;
  static const double durationWeight = 0.10;
  static const double industryWeight = 0.10;
  static const double prerequisiteWeight = 0.05;

  List<RankedProgramme> rank({
    required Iterable<ProgrammeCandidate> programmes,
    required SkillGapAnalysis analysis,
  }) {
    final ranked =
        programmes
            .map((programme) => _score(programme, analysis))
            .where((result) => result.coveredSkillIds.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final scoreOrder = b.matchScore.compareTo(a.matchScore);
            if (scoreOrder != 0) return scoreOrder;
            final evidenceOrder = b.evidenceCoverage.compareTo(
              a.evidenceCoverage,
            );
            return evidenceOrder != 0
                ? evidenceOrder
                : a.programme.name.compareTo(b.programme.name);
          });
    return ranked;
  }

  RankedProgramme scoreProgramme({
    required ProgrammeCandidate programme,
    required SkillGapAnalysis analysis,
  }) => _score(programme, analysis);

  RankedProgramme _score(
    ProgrammeCandidate programme,
    SkillGapAnalysis analysis,
  ) {
    final covered = analysis.priorityGaps
        .where((gap) => _programmeCovers(programme, gap.competency))
        .map((gap) => gap.competency.id)
        .toList();
    final coverage = _skillCoverage(programme, analysis);
    final level = _levelSuitability(programme, analysis);
    final certification = _certificationRelevance(programme);
    final duration = _durationSuitability(programme);
    final industry = _industryRelevance(programme, analysis, covered);
    final prerequisites = _prerequisiteCompatibility(programme, analysis);
    final components = <ProgrammeScoreComponent>[
      ProgrammeScoreComponent(
        label: 'Skill coverage',
        weight: skillCoverageWeight,
        score: coverage,
        explanation: covered.isEmpty
            ? 'Does not cover a measured priority gap.'
            : 'Covers ${covered.length} measured priority skill gap${covered.length == 1 ? '' : 's'}.',
      ),
      ProgrammeScoreComponent(
        label: 'Level suitability',
        weight: levelSuitabilityWeight,
        score: level,
        explanation: level == null
            ? 'Programme level is unavailable.'
            : 'Compared with your current weighted competency level.',
      ),
      ProgrammeScoreComponent(
        label: 'Certification',
        weight: certificationWeight,
        score: certification,
        explanation: certification == null
            ? 'Certification information is unavailable.'
            : 'Catalogue includes a stated credential or certificate.',
      ),
      ProgrammeScoreComponent(
        label: 'Duration suitability',
        weight: durationWeight,
        score: duration,
        explanation: duration == null
            ? 'Duration information is unavailable.'
            : 'Based on the stated ${programme.durationDays}-day duration.',
      ),
      ProgrammeScoreComponent(
        label: 'Role relevance',
        weight: industryWeight,
        score: industry,
        explanation:
            'Measured from stated skills, role, industry, and summary text.',
      ),
      ProgrammeScoreComponent(
        label: 'Prerequisites',
        weight: prerequisiteWeight,
        score: prerequisites,
        explanation: prerequisites == null
            ? 'Prerequisite information is unavailable.'
            : 'Compared with your assessed competency levels.',
      ),
    ];

    // Missing catalogue fields are excluded and the remaining published
    // weights are normalised. They are never replaced with invented values.
    var weightedScore = 0.0;
    var availableWeight = 0.0;
    for (final component in components.where((item) => item.score != null)) {
      weightedScore += component.weight * component.score!;
      availableWeight += component.weight;
    }
    final match = availableWeight == 0
        ? 0.0
        : (weightedScore / availableWeight).clamp(0, 100).toDouble();
    final evidenceCoverage = (availableWeight * 100).clamp(0, 100).toDouble();

    final reasons = <String>[
      if (covered.isNotEmpty)
        'Covers ${covered.length} of your priority skill gap${covered.length == 1 ? '' : 's'}.',
      if (level != null && level >= 70)
        'Its stated level is suitable for your current readiness.',
      if (certification != null)
        'Includes stated certification or credential information.',
      if (components.any((item) => !item.isAvailable))
        'Unavailable catalogue fields are excluded from the weighted score.',
    ];
    if (reasons.isEmpty) {
      reasons.add('The score uses only information present in the catalogue.');
    }

    return RankedProgramme(
      programme: programme,
      matchScore: match,
      evidenceCoverage: evidenceCoverage,
      components: components,
      coveredSkillIds: covered,
      reasons: reasons,
    );
  }

  double _skillCoverage(
    ProgrammeCandidate programme,
    SkillGapAnalysis analysis,
  ) {
    final priorityGaps = analysis.priorityGaps;
    final totalNeed = priorityGaps.fold<double>(
      0,
      (sum, gap) => sum + gap.priorityScore,
    );
    if (totalNeed <= 0) return 100;
    final coveredNeed = priorityGaps
        .where((gap) => _programmeCovers(programme, gap.competency))
        .fold<double>(0, (sum, gap) => sum + gap.priorityScore);
    return (coveredNeed / totalNeed * 100).clamp(0, 100).toDouble();
  }

  double? _levelSuitability(
    ProgrammeCandidate programme,
    SkillGapAnalysis analysis,
  ) {
    final level = programme.level?.trim().toLowerCase();
    if (level == null || level.isEmpty || level.contains('unspecified')) {
      return null;
    }
    final current = _weightedCurrentLevel(analysis);
    final idealStart = switch (level) {
      String value
          when value.contains('beginner') || value.contains('foundation') =>
        25.0,
      String value when value.contains('intermediate') => 55.0,
      String value when value.contains('advanced') => 78.0,
      _ => null,
    };
    if (idealStart == null) return null;
    return (100 - (current - idealStart).abs() * 2).clamp(0, 100).toDouble();
  }

  double? _certificationRelevance(ProgrammeCandidate programme) {
    final credential = programme.credential?.trim();
    if (credential == null || credential.isEmpty) return null;
    final value = credential.toLowerCase();
    if (value.contains('professional certificate') ||
        value.contains('certification') ||
        value.contains('accredited') ||
        value.contains('diploma') ||
        value.contains('credential')) {
      return 100;
    }
    if (value.contains('certificate')) return 75;
    return 60;
  }

  double? _durationSuitability(ProgrammeCandidate programme) {
    final days = programme.durationDays;
    if (days == null || days <= 0) return null;
    if (days <= 30) return 100;
    if (days <= 90) return 85;
    if (days <= 180) return 70;
    if (days <= 365) return 55;
    return 40;
  }

  double _industryRelevance(
    ProgrammeCandidate programme,
    SkillGapAnalysis analysis,
    List<String> covered,
  ) {
    final corpus = _normalise(
      [
        programme.name,
        programme.summary ?? '',
        programme.industry ?? '',
        ...programme.targetRoles,
        ...programme.skills,
      ].join(' '),
    );
    final role = _normalise(analysis.profile.title);
    final industry = _normalise(analysis.profile.industry);
    if (_containsPhrase(corpus, role)) return 100;
    if (industry.isNotEmpty && _containsPhrase(corpus, industry)) return 90;
    if (covered.length >= 2) return 85;
    if (covered.length == 1) return 65;
    return 0;
  }

  double? _prerequisiteCompatibility(
    ProgrammeCandidate programme,
    SkillGapAnalysis analysis,
  ) {
    final prerequisites = programme.prerequisites;
    if (prerequisites == null) return null;
    if (prerequisites.isEmpty) return 100;
    var met = 0;
    for (final prerequisite in prerequisites) {
      final match = analysis.results.where(
        (gap) => _skillMatches(prerequisite, gap.competency),
      );
      if (match.isEmpty || match.first.currentLevel >= 40) met++;
    }
    return (met / prerequisites.length * 100).clamp(0, 100).toDouble();
  }

  double _weightedCurrentLevel(SkillGapAnalysis analysis) {
    final valid = analysis.results.where(
      (item) => item.competency.weight.isFinite && item.competency.weight > 0,
    );
    final totalWeight = valid.fold<double>(
      0,
      (sum, item) => sum + item.competency.weight,
    );
    if (totalWeight == 0) return 0;
    return valid.fold<double>(
          0,
          (sum, item) => sum + item.currentLevel * item.competency.weight,
        ) /
        totalWeight;
  }

  bool _programmeCovers(
    ProgrammeCandidate programme,
    SkillCompetency competency,
  ) {
    final corpus = [
      programme.name,
      programme.summary ?? '',
      ...programme.skills,
    ].join(' ');
    return _skillMatches(corpus, competency);
  }

  bool _skillMatches(String value, SkillCompetency competency) {
    final corpus = _normalise(value);
    final signals = <String>{
      competency.name,
      ...competency.keywords,
    }.map(_normalise).where((item) => item.length >= 2);
    return signals.any((signal) => _containsPhrase(corpus, signal));
  }

  bool _containsPhrase(String corpus, String phrase) {
    if (corpus.contains(phrase)) return true;
    final meaningful = phrase
        .split(' ')
        .where((token) => token.length >= 3)
        .toList();
    if (meaningful.isEmpty) return false;
    return meaningful.every(corpus.contains);
  }

  String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
