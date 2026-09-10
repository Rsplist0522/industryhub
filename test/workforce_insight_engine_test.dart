import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/features/skill_match/domain/skill_models.dart';
import 'package:industryhub/features/skill_match/domain/workforce_insight_engine.dart';

void main() {
  const engine = WorkforceInsightEngine();

  WorkforceSkillSignal signal({
    required String age,
    required String variable,
    required DateTime date,
    required double value,
  }) => WorkforceSkillSignal(
    variable: variable,
    ageGroup: age,
    observedOn: date,
    value: value,
    unit: variable == 'rate' ? 'percent' : "persons ('000)",
    sourceName: 'DOSM',
    sourceUrl: 'https://data.gov.my/example',
  );

  test('builds latest rate, previous-quarter change, and people count', () {
    final insight = engine.build(
      ageGroup: 'Overall',
      signals: [
        signal(
          age: 'Overall',
          variable: 'rate',
          date: DateTime.utc(2025, 4),
          value: 35.1,
        ),
        signal(
          age: 'Overall',
          variable: 'rate',
          date: DateTime.utc(2025, 7),
          value: 35.5,
        ),
        signal(
          age: 'Overall',
          variable: 'persons',
          date: DateTime.utc(2025, 7),
          value: 1950,
        ),
      ],
    );

    expect(insight, isNotNull);
    expect(insight!.rate, 35.5);
    expect(insight.rateChange, closeTo(0.4, 0.001));
    expect(insight.peopleThousands, 1950);
    expect(insight.periodLabel, 'Q3 2025');
  });

  test('uses only the selected government age group', () {
    final insight = engine.build(
      ageGroup: '25-34',
      signals: [
        signal(
          age: 'Overall',
          variable: 'rate',
          date: DateTime.utc(2025, 7),
          value: 35.5,
        ),
        signal(
          age: '25-34',
          variable: 'rate',
          date: DateTime.utc(2025, 7),
          value: 41.2,
        ),
      ],
    );

    expect(insight!.rate, 41.2);
  });

  test('puts Overall first and derives remaining groups from the dataset', () {
    final groups = engine.ageGroups([
      signal(
        age: '35-44',
        variable: 'rate',
        date: DateTime.utc(2025),
        value: 1,
      ),
      signal(
        age: 'Overall',
        variable: 'rate',
        date: DateTime.utc(2025),
        value: 1,
      ),
      signal(
        age: '25-34',
        variable: 'rate',
        date: DateTime.utc(2025),
        value: 1,
      ),
    ]);

    expect(groups, ['Overall', '25-34', '35-44']);
  });
}
