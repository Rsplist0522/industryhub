import 'skill_models.dart';

class WorkforceInsightEngine {
  const WorkforceInsightEngine();

  List<String> ageGroups(Iterable<WorkforceSkillSignal> signals) {
    final groups =
        signals
            .map((signal) => signal.ageGroup.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) {
            if (_isOverall(a)) return -1;
            if (_isOverall(b)) return 1;
            return a.compareTo(b);
          });
    return groups;
  }

  MalaysiaWorkforceInsight? build({
    required Iterable<WorkforceSkillSignal> signals,
    required String ageGroup,
  }) {
    final selected = signals
        .where((signal) => _sameGroup(signal.ageGroup, ageGroup))
        .where((signal) => signal.value.isFinite && signal.value >= 0)
        .toList();
    final rates = selected.where(_isRate).toList()
      ..sort((a, b) => b.observedOn.compareTo(a.observedOn));
    if (rates.isEmpty) return null;
    final latest = rates.first;
    WorkforceSkillSignal? previous;
    for (final signal in rates.skip(1)) {
      if (signal.observedOn.isBefore(latest.observedOn)) {
        previous = signal;
        break;
      }
    }
    WorkforceSkillSignal? people;
    for (final signal in selected) {
      if (signal.observedOn == latest.observedOn && !_isRate(signal)) {
        people = signal;
        break;
      }
    }
    return MalaysiaWorkforceInsight(
      ageGroup: latest.ageGroup,
      observedOn: latest.observedOn,
      rate: latest.value,
      previousRate: previous?.value,
      peopleThousands: people?.value,
      sourceName: latest.sourceName,
      sourceUrl: latest.sourceUrl,
    );
  }

  bool _isRate(WorkforceSkillSignal signal) {
    final variable = signal.variable.toLowerCase();
    final unit = signal.unit.toLowerCase();
    return variable.contains('rate') || unit.contains('percent') || unit == '%';
  }

  bool _sameGroup(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  bool _isOverall(String value) => value.trim().toLowerCase() == 'overall';
}
