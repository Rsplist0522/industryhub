// M1 SkillMatch AI for IndustryHub.
// Design intent: turn a plain-language workforce need into a clear, reviewable
// brief and a transparent shortlist backed by the live Supabase catalogue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../data/training_programme_repository.dart';

class _ChatLine {
  const _ChatLine(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class _Requirement {
  const _Requirement({
    required this.intent,
    required this.role,
    required this.skills,
    required this.experience,
    required this.shift,
    required this.certification,
  });

  final String intent;
  final String role;
  final List<String> skills;
  final String experience;
  final String shift;
  final String certification;
}

class _ProgramDefinition {
  const _ProgramDefinition({
    required this.id,
    required this.name,
    required this.provider,
    required this.level,
    required this.duration,
    required this.skills,
    required this.credential,
    required this.summary,
    this.sourceName = 'Live Supabase catalogue',
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String provider;
  final String level;
  final String duration;
  final List<String> skills;
  final String credential;
  final String summary;
  final String sourceName;
  final String sourceUrl;
}

class _Program {
  const _Program({
    required this.id,
    required this.name,
    required this.provider,
    required this.level,
    required this.duration,
    required this.match,
    required this.matchedSkills,
    required this.credential,
    required this.summary,
    this.sourceName = 'Live Supabase catalogue',
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String provider;
  final String level;
  final String duration;
  final int match;
  final List<String> matchedSkills;
  final String credential;
  final String summary;
  final String sourceName;
  final String sourceUrl;
}

class _FollowUpPrompt {
  const _FollowUpPrompt({required this.label, required this.message});

  final String label;
  final String message;
}

class _ProgramRanking {
  const _ProgramRanking({
    required this.programmes,
    required this.catalogueStatus,
  });

  final List<_Program> programmes;
  final String catalogueStatus;
}

class SkillMatchScreen extends ConsumerStatefulWidget {
  const SkillMatchScreen({super.key});

  @override
  ConsumerState<SkillMatchScreen> createState() => _SkillMatchScreenState();
}

class _SkillMatchScreenState extends ConsumerState<SkillMatchScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _savedProgramIds = <String>{};
  final _trainingProgrammeRepository = TrainingProgrammeRepository();
  final _aiService = const AiService();
  final _messages = <_ChatLine>[
    const _ChatLine(
      'Tell me what capability you need to build. Include the role, current experience, shift coverage, or certification requirement.',
      false,
    ),
  ];

  bool _isThinking = false;
  bool _isSavingProgram = false;
  _Requirement? _requirement;
  String? _lastNeedText;
  List<_Program> _programs = const [];
  String _catalogueStatus =
      'Submit a career or workforce need to search the live SkillMatch catalogue.';
  WorkforceSkillSignal? _workforceSkillSignal;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await Future.wait([_loadWorkforceSignal(), _loadSavedMatches()]);
    });
  }

  Future<void> _loadSavedMatches() async {
    try {
      final savedIds = await ref
          .read(appStateProvider.notifier)
          .fetchSavedMatchIds();
      if (!mounted) return;
      setState(() => _savedProgramIds.addAll(savedIds));
    } catch (error) {
      debugPrint('SkillMatch saved matches could not be loaded: $error');
    }
  }

  Future<void> _loadWorkforceSignal() async {
    try {
      final signal = await _trainingProgrammeRepository
          .fetchLatestWorkforceSignal();
      if (!mounted) return;
      setState(() => _workforceSkillSignal = signal);
    } catch (error) {
      debugPrint('SkillMatch workforce signal could not be loaded: $error');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isThinking) return;

    _input.clear();
    setState(() {
      _messages.add(_ChatLine(text, true));
      _isThinking = true;
    });
    _scrollToBottom();

    Map<String, dynamic> aiResponse;
    Object? aiError;
    var aiAvailable = true;
    try {
      final signalContext = _workforceSkillSignal == null
          ? 'No Malaysian workforce signal is currently available.'
          : 'DOSM Malaysia workforce signal: ${_workforceSkillSignal!.variable}, ${_workforceSkillSignal!.ageGroup}, ${_workforceSkillSignal!.value.toStringAsFixed(1)} ${_workforceSkillSignal!.unit}, observed ${_workforceSkillSignal!.observedOn.toIso8601String().substring(0, 10)}.';
      aiResponse = await _aiService.callAI(
        'You are SkillMatch, a career and workforce-learning assistant. The user may be an individual seeking a career transition, not only an employer. Extract a structured learning brief from the user request. Return exactly these JSON keys: intent, role, skills (array of concise skill names), experience, shift, certification, assistant_message. If the user says they want to become a software engineer, set role to Software engineer / developer and recommend relevant learning paths. Do not turn a career request into a production-team hiring request. Use the Malaysian workforce signal only as context, not as a personal diagnosis. Never invent a course provider; recommendations must come from the live catalogue records supplied by the app. $signalContext',
        text,
      );
    } catch (error) {
      aiAvailable = false;
      aiError = error;
      debugPrint('SkillMatch AI call unavailable: $error');
      aiResponse = const {'__source': 'unavailable'};
    }
    if (!mounted) return;

    final requirement = _requirementFromAi(text, aiResponse);
    final ranking = await _rankProgrammes(requirement);
    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _requirement = requirement;
      _lastNeedText = text;
      _programs = ranking.programmes;
      _catalogueStatus = ranking.catalogueStatus;
      final assistantMessage =
          aiAvailable &&
              aiResponse['assistant_message'] is String &&
              (aiResponse['assistant_message'] as String).trim().isNotEmpty
          ? (aiResponse['assistant_message'] as String).trim()
          : aiAvailable
          ? 'I created a ${requirement.intent.toLowerCase()} brief for a ${requirement.role.toLowerCase()} and ranked ${ranking.programmes.length} relevant programme options.'
          : 'The AI assistant is unavailable, so I used only the words in your message. ${describeAiError(aiError ?? 'Unknown AI error')}';
      final sourceLabel = aiAvailable
          ? 'AI-assisted brief.'
          : 'AI unavailable; local parsing only. ${describeAiError(aiError ?? 'Unknown AI error')}';
      _messages.add(
        _ChatLine(
          '$assistantMessage $sourceLabel Review the brief, then open the live course links that fit your goal.',
          false,
        ),
      );
    });
    _scrollToBottom();
  }

  _Requirement _requirementFromAi(String text, Map<String, dynamic> response) {
    final local = _extractRequirement(text);
    final aiSkills = _normaliseSkills(response['skills']);
    final lower = text.toLowerCase();
    final explicitCareerRole =
        lower.contains('software') ||
        lower.contains('developer') ||
        lower.contains('programming') ||
        lower.contains('coding') ||
        lower.contains('engineer') ||
        lower.contains('web development') ||
        lower.contains('data analyst');
    return _Requirement(
      intent:
          (lower.contains('want') ||
              lower.contains('become') ||
              lower.contains('career') ||
              lower.contains('learn') ||
              lower.contains('course') ||
              lower.contains('certificate'))
          ? local.intent
          : _textOr(response['intent'], local.intent),
      role: explicitCareerRole
          ? local.role
          : _textOr(response['role'], local.role),
      skills: aiSkills.isEmpty ? local.skills : aiSkills,
      experience: _textOr(
        response['experience'],
        _textOr(response['experience_level'], local.experience),
      ),
      shift: _textOr(response['shift'], local.shift),
      certification: _textOr(
        response['certification'],
        _textOr(response['certifications'], local.certification),
      ),
    );
  }

  List<String> _normaliseSkills(dynamic value) {
    if (value is! List) return const [];
    const aliases = <String, String>{
      'cnc': 'CNC machining',
      'cnc machining': 'CNC machining',
      'machining': 'CNC machining',
      'lean': 'Lean manufacturing',
      'lean manufacturing': 'Lean manufacturing',
      'quality': 'Quality systems',
      'quality systems': 'Quality systems',
      'iso': 'Quality systems',
      'welding': 'Welding',
      'weld': 'Welding',
      'safety': 'Occupational safety',
      'osh': 'Occupational safety',
      'team supervision': 'Team supervision',
      'supervision': 'Team supervision',
      'production planning': 'Production planning',
      'planning': 'Production planning',
      'software': 'Software engineering',
      'software engineering': 'Software engineering',
      'software development': 'Software engineering',
      'software engineer': 'Software engineering',
      'developer': 'Software engineering',
      'programming': 'Software engineering',
      'coding': 'Software engineering',
      'web development': 'Web development',
      'web developer': 'Web development',
      'frontend': 'Web development',
      'backend': 'Web development',
      'data and analytics': 'Data and analytics',
      'data analytics': 'Data and analytics',
      'data analyst': 'Data and analytics',
      'machine learning': 'Data and analytics',
      'cloud and devops': 'Cloud and DevOps',
      'cloud': 'Cloud and DevOps',
      'devops': 'Cloud and DevOps',
    };
    final skills = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final label = item.trim();
      if (label.isEmpty) continue;
      final canonical = aliases[label.toLowerCase()] ?? label;
      if (!skills.contains(canonical)) skills.add(canonical);
    }
    return skills.take(6).toList();
  }

  String _textOr(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List && value.isNotEmpty && value.first is String) {
      return (value.first as String).trim();
    }
    return fallback;
  }

  _Requirement _extractRequirement(String text) {
    final lower = text.toLowerCase();
    final skills = <String>[];

    void addSkill(String skill, List<String> signals) {
      if (signals.any(lower.contains)) skills.add(skill);
    }

    addSkill('CNC machining', ['cnc', 'machin', 'lathe', 'milling']);
    addSkill('Lean manufacturing', [
      'lean',
      '5s',
      'kaizen',
      'process improvement',
    ]);
    addSkill('Quality systems', ['quality', 'iso', 'inspection', 'audit']);
    addSkill('Welding', ['weld', 'fabricat']);
    addSkill('Occupational safety', ['safety', 'osh', 'hse']);
    addSkill('Team supervision', ['supervisor', 'supervise', 'lead team']);
    addSkill('Production planning', [
      'schedule',
      'planning',
      'production',
      'shift',
    ]);
    addSkill('Software engineering', [
      'software',
      'developer',
      'programming',
      'coding',
      'engineer',
    ]);
    addSkill('Web development', [
      'web',
      'frontend',
      'backend',
      'full stack',
      'fullstack',
    ]);
    addSkill('Data and analytics', [
      'data',
      'analytics',
      'machine learning',
      'sql',
    ]);
    addSkill('Cloud and DevOps', ['cloud', 'devops', 'aws', 'azure']);

    final role =
        lower.contains('software') ||
            lower.contains('developer') ||
            lower.contains('programming') ||
            lower.contains('coding') ||
            lower.contains('engineer')
        ? 'Software engineer / developer'
        : lower.contains('cnc')
        ? 'CNC operator / technician'
        : lower.contains('weld')
        ? 'Welding technician'
        : lower.contains('quality') || lower.contains('inspect')
        ? 'Quality inspector'
        : lower.contains('supervisor')
        ? 'Production supervisor'
        : lower.contains('technician')
        ? 'Technician'
        : 'Role to be clarified';

    final intent =
        lower.contains('upskill') ||
            lower.contains('existing staff') ||
            lower.contains('current staff') ||
            lower.contains('want to become') ||
            lower.contains('want be') ||
            lower.contains('career') ||
            lower.contains('learn') ||
            lower.contains('course') ||
            lower.contains('certificate') ||
            lower.contains('certification') ||
            lower.contains('become')
        ? 'Career learning / upskilling'
        : lower.contains('hire') ||
              lower.contains('need a') ||
              lower.contains('recruit')
        ? 'Hiring / capability-building'
        : 'Career learning / upskilling';

    final shift = lower.contains('3 shift') || lower.contains('three shift')
        ? 'Three-shift coverage'
        : lower.contains('2 shift') ||
              lower.contains('two shift') ||
              lower.contains('second shift')
        ? 'Two-shift coverage'
        : lower.contains('shift')
        ? 'Shift coverage required'
        : 'Standard operating hours';

    final experience =
        lower.contains('senior') ||
            lower.contains('5 year') ||
            lower.contains('experienced')
        ? 'Intermediate / senior'
        : lower.contains('fresh') ||
              lower.contains('entry') ||
              lower.contains('no experience')
        ? 'Entry level'
        : 'Entry to intermediate';

    final certification = lower.contains('iso')
        ? 'ISO 9001 / quality-systems evidence'
        : lower.contains('weld')
        ? 'Welding competency evidence'
        : lower.contains('safety') || lower.contains('osh')
        ? 'Occupational safety certification'
        : lower.contains('software') ||
              lower.contains('developer') ||
              lower.contains('coding') ||
              lower.contains('engineer')
        ? 'Industry-recognised software certificate recommended'
        : 'Relevant industry certificate recommended';

    return _Requirement(
      intent: intent,
      role: role,
      skills: skills,
      experience: experience,
      shift: shift,
      certification: certification,
    );
  }

  Future<_ProgramRanking> _rankProgrammes(_Requirement requirement) async {
    try {
      final catalogueProgrammes = await _trainingProgrammeRepository
          .fetchActiveProgrammes();
      final catalogueDefinitions = catalogueProgrammes
          .map(_definitionFromCatalogue)
          .toList();
      final catalogueMatches = _rankDefinitions(
        requirement,
        catalogueDefinitions,
        onlyMatched: true,
      );

      if (catalogueMatches.isNotEmpty) {
        return _ProgramRanking(
          programmes: catalogueMatches.take(3).toList(),
          catalogueStatus:
              'Showing ${catalogueMatches.length} matching programme record${catalogueMatches.length == 1 ? '' : 's'} from the Supabase catalogue.',
        );
      }

      if (catalogueProgrammes.isNotEmpty) {
        return _ProgramRanking(
          programmes: const [],
          catalogueStatus:
              'No live catalogue record matches this brief yet. Add or refresh programmes in Supabase to see recommendations.',
        );
      }
    } catch (error) {
      debugPrint('SkillMatch Supabase catalogue read failed: $error');
      return _ProgramRanking(
        programmes: const [],
        catalogueStatus:
            'The live Supabase catalogue is unavailable right now. Try again after the data sync is restored.',
      );
    }

    return _ProgramRanking(
      programmes: const [],
      catalogueStatus:
          'No active live programmes found. Run the Dart live-data importer to populate Supabase.',
    );
  }

  _ProgramDefinition _definitionFromCatalogue(TrainingProgramme programme) {
    final duration = programme.durationDays == 1
        ? '1 day'
        : '${programme.durationDays} days';
    final sourceSuffix = programme.sourceName.isEmpty
        ? ''
        : ' Source: ${programme.sourceName}.';
    return _ProgramDefinition(
      id: programme.id,
      name: programme.name,
      provider: programme.provider,
      level: programme.level,
      duration: programme.durationDays > 0
          ? duration
          : 'Duration to be confirmed',
      skills: programme.skills,
      credential: programme.credential.isEmpty
          ? 'Programme details from the Supabase catalogue'
          : programme.credential,
      summary: programme.summary.isEmpty
          ? 'This programme is stored in your Supabase training catalogue.$sourceSuffix'
          : programme.summary,
      sourceName: programme.sourceName,
      sourceUrl: programme.sourceUrl,
    );
  }

  List<String> _skillSignals(String skill) {
    final lower = skill.toLowerCase();
    if (lower.contains('software')) {
      return [
        'software',
        'developer',
        'programming',
        'coding',
        'computer science',
      ];
    }
    if (lower.contains('web')) {
      return ['web', 'frontend', 'backend', 'full stack', 'fullstack'];
    }
    if (lower.contains('data')) {
      return [
        'data',
        'analytics',
        'sql',
        'machine learning',
        'artificial intelligence',
      ];
    }
    if (lower.contains('cloud') || lower.contains('devops')) {
      return ['cloud', 'devops', 'aws', 'azure', 'docker'];
    }
    return [lower];
  }

  List<_Program> _rankDefinitions(
    _Requirement requirement,
    List<_ProgramDefinition> definitions, {
    bool onlyMatched = false,
  }) {
    final ranked =
        definitions
            .map((definition) {
              final corpus =
                  '${definition.name} ${definition.provider} ${definition.summary} ${definition.skills.join(' ')}'
                      .toLowerCase();
              final matchedSkills = requirement.skills.where((skill) {
                final exact = definition.skills.any(
                  (item) => item.toLowerCase() == skill.toLowerCase(),
                );
                final semantic = _skillSignals(skill).any(corpus.contains);
                return exact || semantic;
              }).toList();
              final roleSignals = _skillSignals(requirement.role);
              final roleMatch = roleSignals.any(corpus.contains);
              final score =
                  (55 +
                          (matchedSkills.length * 13) +
                          (roleMatch ? 10 : 0) +
                          (requirement.experience == definition.level ? 4 : 0))
                      .clamp(55, 98)
                      .toInt();
              final reason = matchedSkills.isEmpty
                  ? 'Supports a related learning pathway in your brief.'
                  : 'Matches ${matchedSkills.join(' and ')} in your brief.';
              return _Program(
                id: definition.id,
                name: definition.name,
                provider: definition.provider,
                level: definition.level,
                duration: definition.duration,
                match: score,
                matchedSkills: matchedSkills,
                credential: definition.credential,
                summary: '${definition.summary} $reason',
                sourceName: definition.sourceName,
                sourceUrl: definition.sourceUrl,
              );
            })
            .where(
              (programme) => !onlyMatched || programme.matchedSkills.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => b.match.compareTo(a.match));

    return ranked;
  }

  List<_FollowUpPrompt> _followUpPrompts(_Requirement requirement) {
    final originalNeed = _lastNeedText ?? '';
    final prompts = <_FollowUpPrompt>[];

    if (requirement.shift == 'Standard operating hours') {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add two-shift coverage',
          message:
              '$originalNeed We need this role to cover two shifts, including the second shift.',
        ),
      );
    }

    if (requirement.experience == 'Entry to intermediate') {
      prompts.add(
        _FollowUpPrompt(
          label: 'Make this an experienced hire',
          message:
              '$originalNeed We need an experienced candidate with at least 3 years of relevant factory experience.',
        ),
      );
    }

    if (requirement.certification == 'HRD Corp claimable preferred') {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add a quality certification need',
          message:
              '$originalNeed The employee should also understand ISO 9001 quality procedures and internal checks.',
        ),
      );
    }

    if (!requirement.skills.contains('Occupational safety')) {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add workplace safety',
          message:
              '$originalNeed Include occupational safety awareness and safe work practices in the requirement.',
        ),
      );
    }

    if (!requirement.skills.contains('Production planning')) {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add production-planning skills',
          message:
              '$originalNeed The person should also support daily production planning and handovers.',
        ),
      );
    }

    return prompts.take(3).toList();
  }

  Future<void> _saveProgramme(_Program programme) async {
    if (_savedProgramIds.contains(programme.id) || _isSavingProgram) return;

    setState(() => _isSavingProgram = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .saveMatch(
            programmeId: programme.id,
            programmeName: programme.name,
            provider: programme.provider,
            sourceUrl: programme.sourceUrl,
            sourceName: programme.sourceName,
          );
      if (!mounted) return;
      setState(() => _savedProgramIds.add(programme.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${programme.name} saved to your profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The training match could not be saved. Please check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingProgram = false);
    }
  }

  Future<void> _resetConversation() async {
    if (_isThinking) return;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a new skill brief?'),
        content: const Text(
          'Your current requirement and ranked programmes will be cleared. Saved matches stay in your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current brief'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start new brief'),
          ),
        ],
      ),
    );

    if (!mounted || shouldReset != true) return;

    _input.clear();
    setState(() {
      _messages
        ..clear()
        ..add(
          const _ChatLine(
            'What capability would you like to build next? You can describe a new hire, an existing employee, or a certification gap.',
            false,
          ),
        );
      _requirement = null;
      _lastNeedText = null;
      _programs = const [];
      _catalogueStatus =
          'Submit a workforce need to search the SkillMatch programme catalogue.';
    });
    _scrollToTop();
  }

  void _usePrompt(String value) {
    _input.text = value;
    _send();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: _goBack,
        ),
        title: const Text('Skill Advisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Start a new skill brief',
            onPressed: _isThinking ? null : _resetConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                const PageIntro(
                  eyebrow: 'M1 / SKILLMATCH AI',
                  title: 'Find the right capability.',
                  description:
                      'Describe a career goal or workforce need. SkillMatch turns it into a structured brief, uses Malaysian workforce context, and ranks live course or certificate records.',
                ),
                if (_workforceSkillSignal != null) ...[
                  const SizedBox(height: 14),
                  _WorkforceSignalCard(signal: _workforceSkillSignal!),
                ],
                if (_requirement == null && !_isThinking) ...[
                  const SizedBox(height: 18),
                  const Eyebrow('TRY A STARTER PROMPT'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PromptChip(
                        label: 'Need a CNC operator for two shifts',
                        onTap: () => _usePrompt(
                          'Need a CNC operator for two shifts with basic machining experience.',
                        ),
                      ),
                      _PromptChip(
                        label: 'Upskill quality inspectors for ISO',
                        onTap: () => _usePrompt(
                          'Upskill our quality inspectors for ISO internal audits and process checks.',
                        ),
                      ),
                      _PromptChip(
                        label: 'Train welding staff safely',
                        onTap: () => _usePrompt(
                          'We need to train existing welding staff on safe welding process and quality checks.',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                const SpecDivider(label: 'CONVERSATION'),
                const SizedBox(height: 16),
                ..._messages.map(
                  (message) =>
                      ChatBubble(text: message.text, isUser: message.isUser),
                ),
                if (_isThinking) const _TypingBubble(),
                if (_requirement != null) ...[
                  const SizedBox(height: 8),
                  _RequirementCard(requirement: _requirement!),
                  const SizedBox(height: 18),
                  const SpecDivider(label: 'RANKED PROGRAMMES'),
                  const SizedBox(height: 5),
                  Text(
                    _catalogueStatus,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._programs.map(
                    (programme) => _ProgramCard(
                      programme: programme,
                      isSaved: _savedProgramIds.contains(programme.id),
                      onSave: () => _saveProgramme(programme),
                    ),
                  ),
                  if (_programs.isEmpty && _lastNeedText != null)
                    _LiveCourseSearchCard(query: _lastNeedText!),
                  const SizedBox(height: 18),
                  const Eyebrow('REFINE THIS BRIEF'),
                  const SizedBox(height: 5),
                  const Text(
                    'Not sure what to ask next? Add one useful detail to improve the recommendations.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _followUpPrompts(_requirement!)
                        .map(
                          (prompt) => _PromptChip(
                            label: prompt.label,
                            onTap: () => _usePrompt(prompt.message),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          _Composer(controller: _input, onSend: _send, isThinking: _isThinking),
        ],
      ),
    );
  }
}

class _WorkforceSignalCard extends StatelessWidget {
  const _WorkforceSignalCard({required this.signal});

  final WorkforceSkillSignal signal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.public_outlined, color: AppColors.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MALAYSIA WORKFORCE SIGNAL',
                    style: AppTheme.eyebrowStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${signal.variable} · ${signal.ageGroup}: ${signal.value.toStringAsFixed(1)} ${signal.unit}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'DOSM / data.gov.my · observed ${signal.observedOn.year}-${signal.observedOn.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(
        Icons.add_comment_outlined,
        size: 16,
        color: AppColors.green,
      ),
      label: Text(label, style: const TextStyle(color: AppColors.ink)),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Analysing capability need…',
          style: TextStyle(color: AppColors.slate),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.isThinking,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'e.g. Need a CNC operator for our second shift…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Analyse skill need',
              onPressed: isThinking ? null : onSend,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement});

  final _Requirement requirement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Eyebrow('WORKFORCE BRIEF'),
                StatusChip(
                  label: requirement.intent.toUpperCase(),
                  color: AppColors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SpecRow(label: 'Role', value: requirement.role),
            _SpecRow(label: 'Skills', value: requirement.skills.join('  /  ')),
            _SpecRow(label: 'Experience', value: requirement.experience),
            _SpecRow(label: 'Shift', value: requirement.shift),
            _SpecRow(label: 'Certification', value: requirement.certification),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.dataStyle.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.programme,
    required this.isSaved,
    required this.onSave,
  });

  final _Program programme;
  final bool isSaved;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    programme.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${programme.match}%',
                  style: AppTheme.dataStyle.copyWith(color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              programme.provider,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 3),
            Text(
              'Source: ${programme.sourceName}',
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label: programme.level.toUpperCase(),
                  color: AppColors.navy,
                ),
                StatusChip(
                  label: programme.duration.toUpperCase(),
                  color: AppColors.slate,
                ),
                if (programme.matchedSkills.isNotEmpty)
                  ...programme.matchedSkills.map(
                    (skill) => StatusChip(
                      label: skill.toUpperCase(),
                      color: AppColors.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              programme.summary,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 11),
            if (programme.sourceUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final uri = Uri.tryParse(programme.sourceUrl);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open live course page'),
                ),
              ),
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 16,
                  color: AppColors.slate,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    programme.credential,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isSaved
                    ? const Text(
                        'SAVED',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          onSave();
                        },
                        icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                        label: const Text('Save'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCourseSearchCard extends StatelessWidget {
  const _LiveCourseSearchCard({required this.query});

  final String query;

  Future<void> _openSearch(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.coursera.org/search?query=${Uri.encodeQueryComponent(query)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the live Coursera search page.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.chalk,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.open_in_new, color: AppColors.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIVE COURSE SEARCH', style: AppTheme.eyebrowStyle),
                  const SizedBox(height: 4),
                  const Text(
                    'No matching Supabase course record is synced yet. Search the provider directly for this request; the destination is generated from your message, not a seeded course.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openSearch(context),
                    icon: const Icon(Icons.school_outlined, size: 17),
                    label: const Text('Open live Coursera results'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
