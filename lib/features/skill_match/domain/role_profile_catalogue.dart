import 'dart:convert';

import 'package:flutter/services.dart';

import 'skill_models.dart';

class RoleProfileCatalogue {
  RoleProfileCatalogue({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/skillmatch_role_profiles.json';

  final AssetBundle _bundle;
  List<RoleCompetencyProfile>? _profiles;

  List<RoleCompetencyProfile> get profiles =>
      List.unmodifiable(_profiles ?? const <RoleCompetencyProfile>[]);

  Future<List<RoleCompetencyProfile>> load() async {
    final cached = _profiles;
    if (cached != null) return cached;
    final decoded = jsonDecode(await _bundle.loadString(assetPath));
    if (decoded is! Map) {
      throw const FormatException('Role profile asset must contain an object.');
    }
    final root = Map<String, dynamic>.from(decoded);
    final frameworkNote = '${root['framework_note'] ?? ''}'.trim();
    final frameworkSourceName = '${root['framework_source_name'] ?? ''}'.trim();
    final frameworkSourceUrl = '${root['framework_source_url'] ?? ''}'.trim();
    final rawProfiles = root['profiles'];
    if (rawProfiles is! List || rawProfiles.isEmpty) {
      throw const FormatException('Role profile asset contains no profiles.');
    }
    final loaded = rawProfiles
        .whereType<Map>()
        .map((raw) {
          final data = Map<String, dynamic>.from(raw);
          data.putIfAbsent('framework_note', () => frameworkNote);
          data.putIfAbsent('framework_source_name', () => frameworkSourceName);
          data.putIfAbsent('framework_source_url', () => frameworkSourceUrl);
          return RoleCompetencyProfile.fromJson(data);
        })
        .toList(growable: false);
    _validate(loaded);
    _profiles = loaded;
    return loaded;
  }

  RoleCompetencyProfile? byId(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  RoleCompetencyProfile? findByTitle(String title) {
    final wanted = _normalise(title);
    if (wanted.isEmpty) return null;
    for (final profile in profiles) {
      final names = [profile.title, ...profile.aliases].map(_normalise);
      if (names.any((name) => name == wanted || wanted.contains(name))) {
        return profile;
      }
    }
    return null;
  }

  RoleCompetencyProfile? infer(String text) {
    if (profiles.isEmpty) {
      throw StateError('Load the role profile catalogue before inference.');
    }
    final query = _normalise(text);
    RoleCompetencyProfile? best;
    var bestScore = -1;
    for (final profile in profiles) {
      var score = 0;
      for (final candidate in [profile.title, ...profile.aliases]) {
        final normalised = _normalise(candidate);
        if (normalised.isNotEmpty && query.contains(normalised)) {
          score = 100 + normalised.length;
          break;
        }
        final tokens = normalised.split(' ').where((word) => word.length > 2);
        score += tokens.where(query.contains).length * 10;
      }
      if (score > bestScore) {
        bestScore = score;
        best = profile;
      }
    }
    return bestScore > 0 ? best : null;
  }

  String get aiRoleOptions => profiles
      .map(
        (profile) =>
            '${profile.id}: ${profile.title} (${profile.industry}); aliases: ${profile.aliases.join(', ')}',
      )
      .join('\n');

  void _validate(List<RoleCompetencyProfile> values) {
    final roleIds = <String>{};
    for (final profile in values) {
      if (profile.id.isEmpty || !roleIds.add(profile.id)) {
        throw const FormatException('Role IDs must be non-empty and unique.');
      }
      if (profile.title.trim().isEmpty || profile.competencies.isEmpty) {
        throw FormatException('${profile.id} has no title or competencies.');
      }
      final skillIds = profile.competencies.map((skill) => skill.id).toSet();
      final weight = profile.competencies.fold<double>(
        0,
        (total, skill) => total + skill.weight,
      );
      if ((weight - 1).abs() > 0.001) {
        throw FormatException('${profile.id} competency weights must total 1.');
      }
      for (final skill in profile.competencies) {
        if (skill.id.isEmpty ||
            skill.targetLevel <= 0 ||
            skill.targetLevel > 100 ||
            skill.weight <= 0 ||
            skill.prerequisiteIds.any((id) => !skillIds.contains(id))) {
          throw FormatException(
            '${profile.id} contains invalid competency data.',
          );
        }
      }
    }
  }

  String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
