import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/features/skill_match/domain/role_profile_catalogue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads validated profiles from the bundled data asset', () async {
    final catalogue = RoleProfileCatalogue();
    final profiles = await catalogue.load();

    expect(profiles.length, 11);
    expect(profiles.map((profile) => profile.id).toSet().length, 11);
    for (final profile in profiles) {
      final totalWeight = profile.competencies.fold<double>(
        0,
        (sum, competency) => sum + competency.weight,
      );
      expect(totalWeight, closeTo(1, 0.001), reason: profile.id);
      expect(profile.frameworkNote, isNotEmpty);
    }
  });

  test(
    'local inference recognises a supported role alias without AI',
    () async {
      final catalogue = RoleProfileCatalogue();
      await catalogue.load();

      final profile = catalogue.infer('I want to work as a PLC technician');

      expect(profile?.id, 'industrial_automation_technician');
    },
  );

  test('local inference maps teacher goals to TVET instruction', () async {
    final catalogue = RoleProfileCatalogue();
    await catalogue.load();

    final profile = catalogue.infer('I want to be a teacher');

    expect(profile?.id, 'tvet_instructor');
  });

  test(
    'does not fabricate a generic profile for an unsupported occupation',
    () async {
      final catalogue = RoleProfileCatalogue();
      await catalogue.load();

      expect(catalogue.infer('I want to become a doctor'), isNull);
    },
  );
}
