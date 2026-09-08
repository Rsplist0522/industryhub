import 'skill_models.dart';

abstract final class RoleProfileCatalogue {
  static const profiles = <RoleCompetencyProfile>[
    RoleCompetencyProfile(
      id: 'software_engineer',
      title: 'Software Engineer',
      industry: 'Digital technology',
      competencies: [
        SkillCompetency(
          id: 'programming_fundamentals',
          name: 'Programming Fundamentals',
          targetLevel: 85,
          weight: 0.25,
          category: 'Foundation',
          keywords: ['programming', 'coding', 'software development'],
        ),
        SkillCompetency(
          id: 'git_version_control',
          name: 'Git / Version Control',
          targetLevel: 70,
          weight: 0.15,
          category: 'Version control',
          prerequisiteIds: ['programming_fundamentals'],
          keywords: ['git', 'github', 'version control'],
        ),
        SkillCompetency(
          id: 'databases_sql',
          name: 'Databases / SQL',
          targetLevel: 70,
          weight: 0.15,
          category: 'Data',
          prerequisiteIds: ['programming_fundamentals'],
          keywords: ['database', 'sql', 'data'],
        ),
        SkillCompetency(
          id: 'backend_apis',
          name: 'Backend / APIs',
          targetLevel: 75,
          weight: 0.20,
          category: 'Development',
          prerequisiteIds: ['programming_fundamentals', 'databases_sql'],
          keywords: ['backend', 'api', 'web development', 'server'],
        ),
        SkillCompetency(
          id: 'problem_solving',
          name: 'Problem Solving',
          targetLevel: 80,
          weight: 0.15,
          category: 'Core skill',
          keywords: ['problem solving', 'algorithms', 'analytical'],
        ),
        SkillCompetency(
          id: 'development_practices',
          name: 'Software Development Practices',
          targetLevel: 70,
          weight: 0.10,
          category: 'Practice',
          prerequisiteIds: ['git_version_control'],
          keywords: ['testing', 'agile', 'software engineering', 'devops'],
        ),
      ],
    ),
    RoleCompetencyProfile(
      id: 'data_analyst',
      title: 'Data Analyst',
      industry: 'Digital technology',
      competencies: [
        SkillCompetency(
          id: 'data_literacy',
          name: 'Data Literacy',
          targetLevel: 80,
          weight: 0.20,
          category: 'Foundation',
          keywords: ['data literacy', 'analytics'],
        ),
        SkillCompetency(
          id: 'sql',
          name: 'SQL',
          targetLevel: 80,
          weight: 0.22,
          category: 'Data',
          prerequisiteIds: ['data_literacy'],
          keywords: ['sql', 'database'],
        ),
        SkillCompetency(
          id: 'spreadsheets',
          name: 'Spreadsheets',
          targetLevel: 75,
          weight: 0.15,
          category: 'Tools',
          keywords: ['excel', 'spreadsheet'],
        ),
        SkillCompetency(
          id: 'visualisation',
          name: 'Data Visualisation',
          targetLevel: 75,
          weight: 0.18,
          category: 'Communication',
          prerequisiteIds: ['data_literacy'],
          keywords: ['visualisation', 'visualization', 'power bi', 'tableau'],
        ),
        SkillCompetency(
          id: 'statistics',
          name: 'Applied Statistics',
          targetLevel: 70,
          weight: 0.15,
          category: 'Analysis',
          prerequisiteIds: ['data_literacy'],
          keywords: ['statistics', 'analysis'],
        ),
        SkillCompetency(
          id: 'business_communication',
          name: 'Business Communication',
          targetLevel: 70,
          weight: 0.10,
          category: 'Communication',
          keywords: ['communication', 'reporting'],
        ),
      ],
    ),
    RoleCompetencyProfile(
      id: 'cnc_operator',
      title: 'CNC Operator',
      industry: 'Manufacturing',
      competencies: [
        SkillCompetency(
          id: 'technical_drawing',
          name: 'Technical Drawing',
          targetLevel: 70,
          weight: 0.15,
          category: 'Foundation',
          keywords: ['technical drawing', 'blueprint'],
        ),
        SkillCompetency(
          id: 'cnc_setup',
          name: 'CNC Setup & Operation',
          targetLevel: 85,
          weight: 0.28,
          category: 'Machining',
          prerequisiteIds: ['technical_drawing'],
          keywords: ['cnc', 'machining', 'milling', 'lathe'],
        ),
        SkillCompetency(
          id: 'measurement',
          name: 'Precision Measurement',
          targetLevel: 80,
          weight: 0.18,
          category: 'Quality',
          keywords: ['metrology', 'measurement', 'inspection'],
        ),
        SkillCompetency(
          id: 'gcode',
          name: 'G-code Fundamentals',
          targetLevel: 70,
          weight: 0.17,
          category: 'Programming',
          prerequisiteIds: ['cnc_setup'],
          keywords: ['g-code', 'cnc programming'],
        ),
        SkillCompetency(
          id: 'machine_safety',
          name: 'Machine Safety',
          targetLevel: 85,
          weight: 0.12,
          category: 'Safety',
          keywords: ['safety', 'osh'],
        ),
        SkillCompetency(
          id: 'quality_checks',
          name: 'Quality Checks',
          targetLevel: 70,
          weight: 0.10,
          category: 'Quality',
          prerequisiteIds: ['measurement'],
          keywords: ['quality', 'inspection'],
        ),
      ],
    ),
    RoleCompetencyProfile(
      id: 'quality_inspector',
      title: 'Quality Inspector',
      industry: 'Manufacturing',
      competencies: [
        SkillCompetency(
          id: 'inspection_methods',
          name: 'Inspection Methods',
          targetLevel: 85,
          weight: 0.25,
          category: 'Inspection',
          keywords: ['inspection', 'quality control'],
        ),
        SkillCompetency(
          id: 'measurement_tools',
          name: 'Measurement Tools',
          targetLevel: 80,
          weight: 0.20,
          category: 'Tools',
          keywords: ['metrology', 'measurement'],
        ),
        SkillCompetency(
          id: 'quality_standards',
          name: 'Quality Standards / ISO',
          targetLevel: 75,
          weight: 0.20,
          category: 'Standards',
          keywords: ['iso', 'quality systems', 'audit'],
        ),
        SkillCompetency(
          id: 'defect_analysis',
          name: 'Defect Analysis',
          targetLevel: 75,
          weight: 0.15,
          category: 'Analysis',
          prerequisiteIds: ['inspection_methods'],
          keywords: ['defect', 'root cause'],
        ),
        SkillCompetency(
          id: 'quality_documentation',
          name: 'Quality Documentation',
          targetLevel: 70,
          weight: 0.10,
          category: 'Practice',
          keywords: ['documentation', 'reporting'],
        ),
        SkillCompetency(
          id: 'workplace_safety',
          name: 'Workplace Safety',
          targetLevel: 75,
          weight: 0.10,
          category: 'Safety',
          keywords: ['safety', 'osh'],
        ),
      ],
    ),
    RoleCompetencyProfile(
      id: 'production_supervisor',
      title: 'Production Supervisor',
      industry: 'Manufacturing',
      competencies: [
        SkillCompetency(
          id: 'production_planning',
          name: 'Production Planning',
          targetLevel: 85,
          weight: 0.23,
          category: 'Operations',
          keywords: ['production planning', 'scheduling'],
        ),
        SkillCompetency(
          id: 'team_leadership',
          name: 'Team Leadership',
          targetLevel: 80,
          weight: 0.20,
          category: 'Leadership',
          keywords: ['supervision', 'leadership'],
        ),
        SkillCompetency(
          id: 'lean_manufacturing',
          name: 'Lean Manufacturing',
          targetLevel: 75,
          weight: 0.18,
          category: 'Improvement',
          keywords: ['lean', '5s', 'kaizen'],
        ),
        SkillCompetency(
          id: 'quality_management',
          name: 'Quality Management',
          targetLevel: 75,
          weight: 0.15,
          category: 'Quality',
          keywords: ['quality', 'iso'],
        ),
        SkillCompetency(
          id: 'safety_management',
          name: 'Safety Management',
          targetLevel: 80,
          weight: 0.14,
          category: 'Safety',
          keywords: ['safety', 'osh'],
        ),
        SkillCompetency(
          id: 'shift_communication',
          name: 'Shift Communication',
          targetLevel: 75,
          weight: 0.10,
          category: 'Communication',
          keywords: ['shift', 'handover', 'communication'],
        ),
      ],
    ),
    RoleCompetencyProfile(
      id: 'welding_technician',
      title: 'Welding Technician',
      industry: 'Manufacturing',
      competencies: [
        SkillCompetency(
          id: 'welding_processes',
          name: 'Welding Processes',
          targetLevel: 85,
          weight: 0.28,
          category: 'Technical',
          keywords: ['welding', 'mig', 'tig', 'arc'],
        ),
        SkillCompetency(
          id: 'drawing_weld_symbols',
          name: 'Drawings & Weld Symbols',
          targetLevel: 75,
          weight: 0.15,
          category: 'Foundation',
          keywords: ['weld symbols', 'technical drawing'],
        ),
        SkillCompetency(
          id: 'weld_quality',
          name: 'Weld Quality Inspection',
          targetLevel: 80,
          weight: 0.20,
          category: 'Quality',
          prerequisiteIds: ['welding_processes'],
          keywords: ['weld quality', 'inspection'],
        ),
        SkillCompetency(
          id: 'materials',
          name: 'Materials Knowledge',
          targetLevel: 70,
          weight: 0.12,
          category: 'Foundation',
          keywords: ['materials', 'metallurgy'],
        ),
        SkillCompetency(
          id: 'welding_safety',
          name: 'Welding Safety',
          targetLevel: 90,
          weight: 0.15,
          category: 'Safety',
          keywords: ['welding safety', 'safety', 'osh'],
        ),
        SkillCompetency(
          id: 'equipment_care',
          name: 'Equipment Setup & Care',
          targetLevel: 75,
          weight: 0.10,
          category: 'Practice',
          prerequisiteIds: ['welding_processes'],
          keywords: ['equipment', 'maintenance'],
        ),
      ],
    ),
  ];

  static RoleCompetencyProfile? byId(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  static RoleCompetencyProfile infer(String text) {
    final value = text.toLowerCase();
    if (value.contains('data') && value.contains('anal')) return profiles[1];
    if (value.contains('cnc') || value.contains('machin')) return profiles[2];
    if (value.contains('quality') || value.contains('inspect')) {
      return profiles[3];
    }
    if (value.contains('supervisor') || value.contains('production lead')) {
      return profiles[4];
    }
    if (value.contains('weld')) return profiles[5];
    return profiles.first;
  }

  static RoleCompetencyProfile custom(String title) => RoleCompetencyProfile(
    id: 'custom_${_slug(title)}',
    title: title.trim(),
    industry: 'General',
    isCustom: true,
    competencies: const [
      SkillCompetency(
        id: 'technical_foundations',
        name: 'Technical Foundations',
        targetLevel: 75,
        weight: 0.25,
        category: 'Foundation',
        keywords: ['technical', 'foundation'],
      ),
      SkillCompetency(
        id: 'role_tools',
        name: 'Role-specific Tools',
        targetLevel: 75,
        weight: 0.20,
        category: 'Tools',
        prerequisiteIds: ['technical_foundations'],
        keywords: ['tools', 'technology'],
      ),
      SkillCompetency(
        id: 'problem_solving',
        name: 'Problem Solving',
        targetLevel: 80,
        weight: 0.20,
        category: 'Core skill',
        keywords: ['problem solving', 'analysis'],
      ),
      SkillCompetency(
        id: 'quality_safety',
        name: 'Quality & Safety',
        targetLevel: 75,
        weight: 0.20,
        category: 'Practice',
        keywords: ['quality', 'safety'],
      ),
      SkillCompetency(
        id: 'communication',
        name: 'Workplace Communication',
        targetLevel: 70,
        weight: 0.15,
        category: 'Communication',
        keywords: ['communication', 'reporting'],
      ),
    ],
  );

  static String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
