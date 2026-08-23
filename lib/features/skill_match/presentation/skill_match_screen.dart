// M1 SkillMatch AI for IndustryHub.
// Design intent: turn a plain-language workforce need into a clear, reviewable
// brief and a transparent shortlist backed by the Supabase catalogue with a curated fallback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
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
  });

  final String id;
  final String name;
  final String provider;
  final String level;
  final String duration;
  final List<String> skills;
  final String credential;
  final String summary;
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
}

class _FollowUpPrompt {
  const _FollowUpPrompt({required this.label, required this.message});

  final String label;
  final String message;
}

class _ProgramRanking {
  const _ProgramRanking({required this.programmes, required this.catalogueStatus});

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
  final _messages = <_ChatLine>[
    const _ChatLine(
      'Tell me what capability you need to build. Include the role, current experience, shift coverage, or certification requirement.',
      false,
    ),
  ];

  bool _isThinking = false;
  _Requirement? _requirement;
  String? _lastNeedText;
  List<_Program> _programs = const [];
  String _catalogueStatus = 'Submit a workforce need to search the SkillMatch programme catalogue.';

  static const _catalogue = <_ProgramDefinition>[
    _ProgramDefinition(
      id: 'cnc-setup',
      name: 'CNC Programming & Setup',
      provider: 'Penang Skills Development Centre',
      level: 'Intermediate',
      duration: '3 days',
      skills: ['CNC machining', 'Production planning'],
      credential: 'Practical setup competency',
      summary: 'Builds confidence in machine setup, tool offsets, safe operation, and basic programme adjustment.',
    ),
    _ProgramDefinition(
      id: 'lean-essentials',
      name: 'Lean Manufacturing Essentials',
      provider: 'Malaysia Productivity Corporation',
      level: 'Foundation',
      duration: '2 days',
      skills: ['Lean manufacturing', 'Production planning'],
      credential: 'Continuous-improvement toolkit',
      summary: 'Introduces visual management, waste reduction, and practical improvement routines for production teams.',
    ),
    _ProgramDefinition(
      id: 'quality-systems',
      name: 'Industrial Quality Systems',
      provider: 'SIRIM Academy',
      level: 'Intermediate',
      duration: '4 days',
      skills: ['Quality systems', 'Production planning'],
      credential: 'Quality systems evidence',
      summary: 'Covers process controls, internal quality checks, traceability, and non-conformance handling.',
    ),
    _ProgramDefinition(
      id: 'welding-safety',
      name: 'Welding Process & Workplace Safety',
      provider: 'Skills Training Centre Catalogue',
      level: 'Foundation',
      duration: '3 days',
      skills: ['Welding', 'Occupational safety'],
      credential: 'Safety and process evidence',
      summary: 'Supports safe preparation, process discipline, and basic quality checks for welding work.',
    ),
    _ProgramDefinition(
      id: 'supervision',
      name: 'Production Team Supervision',
      provider: 'Manufacturing Leadership Catalogue',
      level: 'Intermediate',
      duration: '2 days',
      skills: ['Team supervision', 'Production planning', 'Lean manufacturing'],
      credential: 'Supervisor action plan',
      summary: 'Helps emerging supervisors coordinate shifts, coach workers, and manage daily production priorities.',
    ),
  ];

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

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final requirement = _extractRequirement(text);
    final ranking = await _rankProgrammes(requirement);
    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _requirement = requirement;
      _lastNeedText = text;
      _programs = ranking.programmes;
      _catalogueStatus = ranking.catalogueStatus;
      _messages.add(
        _ChatLine(
          'I created a ${requirement.intent.toLowerCase()} brief for a ${requirement.role.toLowerCase()} and ranked ${ranking.programmes.length} relevant programme options. Review the brief, then save the programmes that fit your team plan.',
          false,
        ),
      );
    });
    _scrollToBottom();
  }

  _Requirement _extractRequirement(String text) {
    final lower = text.toLowerCase();
    final skills = <String>[];

    void addSkill(String skill, List<String> signals) {
      if (signals.any(lower.contains)) skills.add(skill);
    }

    addSkill('CNC machining', ['cnc', 'machin', 'lathe', 'milling']);
    addSkill('Lean manufacturing', ['lean', '5s', 'kaizen', 'process improvement']);
    addSkill('Quality systems', ['quality', 'iso', 'inspection', 'audit']);
    addSkill('Welding', ['weld', 'fabricat']);
    addSkill('Occupational safety', ['safety', 'osh', 'hse']);
    addSkill('Team supervision', ['supervisor', 'supervise', 'lead team']);
    addSkill('Production planning', ['schedule', 'planning', 'production', 'shift']);

    if (skills.isEmpty) {
      skills.addAll(['Production planning', 'Lean manufacturing']);
    }

    final role = lower.contains('cnc')
        ? 'CNC operator / technician'
        : lower.contains('weld')
            ? 'Welding technician'
            : lower.contains('quality') || lower.contains('inspect')
                ? 'Quality inspector'
                : lower.contains('supervisor')
                    ? 'Production supervisor'
                    : 'Production team member';

    final intent = lower.contains('upskill') || lower.contains('existing staff') || lower.contains('current staff')
        ? 'Upskilling'
        : 'Hiring / capability-building';

    final shift = lower.contains('3 shift') || lower.contains('three shift')
        ? 'Three-shift coverage'
        : lower.contains('2 shift') || lower.contains('two shift') || lower.contains('second shift')
            ? 'Two-shift coverage'
            : lower.contains('shift')
                ? 'Shift coverage required'
                : 'Standard operating hours';

    final experience = lower.contains('senior') || lower.contains('5 year') || lower.contains('experienced')
        ? 'Intermediate / senior'
        : lower.contains('fresh') || lower.contains('entry') || lower.contains('no experience')
            ? 'Entry level'
            : 'Entry to intermediate';

    final certification = lower.contains('iso')
        ? 'ISO 9001 / quality-systems evidence'
        : lower.contains('weld')
            ? 'Welding competency evidence'
            : lower.contains('safety') || lower.contains('osh')
                ? 'Occupational safety certification'
                : 'HRD Corp claimable preferred';

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
      final catalogueProgrammes = await _trainingProgrammeRepository.fetchActiveProgrammes();
      final catalogueDefinitions = catalogueProgrammes.map(_definitionFromCatalogue).toList();
      final catalogueMatches = _rankDefinitions(requirement, catalogueDefinitions, onlyMatched: true);

      if (catalogueMatches.isNotEmpty) {
        return _ProgramRanking(
          programmes: catalogueMatches.take(3).toList(),
          catalogueStatus: 'Showing ${catalogueMatches.length} matching programme record${catalogueMatches.length == 1 ? '' : 's'} from the Supabase catalogue.',
        );
      }

      if (catalogueProgrammes.isNotEmpty) {
        return _ProgramRanking(
          programmes: _rankDefinitions(requirement, _catalogue).take(3).toList(),
          catalogueStatus: 'No catalogue record matches this brief yet. Showing curated suggestions while more programmes are added.',
        );
      }
    } catch (error) {
      debugPrint('SkillMatch Supabase catalogue read failed: $error');
      return _ProgramRanking(
        programmes: _rankDefinitions(requirement, _catalogue).take(3).toList(),
        catalogueStatus: 'The Supabase catalogue is unavailable right now. Showing curated suggestions instead.',
      );
    }

    return _ProgramRanking(
      programmes: _rankDefinitions(requirement, _catalogue).take(3).toList(),
      catalogueStatus: 'No active Supabase programmes found. Showing curated suggestions instead.',
    );
  }

  _ProgramDefinition _definitionFromCatalogue(TrainingProgramme programme) {
    final duration = programme.durationDays == 1 ? '1 day' : '${programme.durationDays} days';
    final sourceSuffix = programme.sourceName.isEmpty ? '' : ' Source: ${programme.sourceName}.';
    return _ProgramDefinition(
      id: programme.id,
      name: programme.name,
      provider: programme.provider,
      level: programme.level,
      duration: programme.durationDays > 0 ? duration : 'Duration to be confirmed',
      skills: programme.skills,
      credential: programme.credential.isEmpty ? 'Programme details from the Supabase catalogue' : programme.credential,
      summary: programme.summary.isEmpty ? 'This programme is stored in your Supabase training catalogue.$sourceSuffix' : programme.summary,
    );
  }

  List<_Program> _rankDefinitions(_Requirement requirement, List<_ProgramDefinition> definitions, {bool onlyMatched = false}) {
    final ranked = definitions.map((definition) {
      final matchedSkills = requirement.skills.where(definition.skills.contains).toList();
      final score = (60 + (matchedSkills.length * 13) + (requirement.experience == definition.level ? 4 : 0)).clamp(65, 98).toInt();
      final reason = matchedSkills.isEmpty
          ? 'Supports the broader production capability in your brief.'
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
      );
    }).where((programme) => !onlyMatched || programme.matchedSkills.isNotEmpty).toList()
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
          message: '$originalNeed We need this role to cover two shifts, including the second shift.',
        ),
      );
    }

    if (requirement.experience == 'Entry to intermediate') {
      prompts.add(
        _FollowUpPrompt(
          label: 'Make this an experienced hire',
          message: '$originalNeed We need an experienced candidate with at least 3 years of relevant factory experience.',
        ),
      );
    }

    if (requirement.certification == 'HRD Corp claimable preferred') {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add a quality certification need',
          message: '$originalNeed The employee should also understand ISO 9001 quality procedures and internal checks.',
        ),
      );
    }

    if (!requirement.skills.contains('Occupational safety')) {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add workplace safety',
          message: '$originalNeed Include occupational safety awareness and safe work practices in the requirement.',
        ),
      );
    }

    if (!requirement.skills.contains('Production planning')) {
      prompts.add(
        _FollowUpPrompt(
          label: 'Add production-planning skills',
          message: '$originalNeed The person should also support daily production planning and handovers.',
        ),
      );
    }

    return prompts.take(3).toList();
  }

  void _saveProgramme(_Program programme) {
    if (_savedProgramIds.contains(programme.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This programme is already saved to your profile.')));
      return;
    }

    setState(() => _savedProgramIds.add(programme.id));
    ref.read(appStateProvider.notifier).saveMatch();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${programme.name} saved to your profile.')),
    );
  }

  Future<void> _resetConversation() async {
    if (_isThinking) return;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a new skill brief?'),
        content: const Text('Your current requirement and ranked programmes will be cleared. Saved matches stay in your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep current brief')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start new brief')),
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
      _catalogueStatus = 'Submit a workforce need to search the SkillMatch programme catalogue.';
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
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
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
                  description: 'Describe a hiring or upskilling need. SkillMatch turns it into a structured workforce brief and ranks relevant local programmes.',
                ),
                if (_requirement == null && !_isThinking) ...[
                  const SizedBox(height: 18),
                  const Eyebrow('TRY A STARTER PROMPT'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PromptChip(label: 'Need a CNC operator for two shifts', onTap: () => _usePrompt('Need a CNC operator for two shifts with basic machining experience.')),
                      _PromptChip(label: 'Upskill quality inspectors for ISO', onTap: () => _usePrompt('Upskill our quality inspectors for ISO internal audits and process checks.')),
                      _PromptChip(label: 'Train welding staff safely', onTap: () => _usePrompt('We need to train existing welding staff on safe welding process and quality checks.')),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                const SpecDivider(label: 'CONVERSATION'),
                const SizedBox(height: 16),
                ..._messages.map((message) => ChatBubble(text: message.text, isUser: message.isUser)),
                if (_isThinking) const _TypingBubble(),
                if (_requirement != null) ...[
                  const SizedBox(height: 8),
                  _RequirementCard(requirement: _requirement!),
                  const SizedBox(height: 18),
                  const SpecDivider(label: 'RANKED PROGRAMMES'),
                  const SizedBox(height: 5),
                  Text(_catalogueStatus, style: const TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 14),
                  ..._programs.map(
                    (programme) => _ProgramCard(
                      programme: programme,
                      isSaved: _savedProgramIds.contains(programme.id),
                      onSave: () => _saveProgramme(programme),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Eyebrow('REFINE THIS BRIEF'),
                  const SizedBox(height: 5),
                  const Text('Not sure what to ask next? Add one useful detail to improve the recommendations.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _followUpPrompts(_requirement!)
                        .map((prompt) => _PromptChip(label: prompt.label, onTap: () => _usePrompt(prompt.message)))
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
      icon: const Icon(Icons.add_comment_outlined, size: 16, color: AppColors.green),
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
        child: const Text('Analysing capability need…', style: TextStyle(color: AppColors.slate)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.isThinking});

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'e.g. Need a CNC operator for our second shift…'),
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
                StatusChip(label: requirement.intent.toUpperCase(), color: AppColors.green),
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
          SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12))),
          Expanded(child: Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.programme, required this.isSaved, required this.onSave});

  final _Program programme;
  final bool isSaved;
  final VoidCallback onSave;

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
                Expanded(child: Text(programme.name, style: Theme.of(context).textTheme.titleMedium)),
                Text('${programme.match}%', style: AppTheme.dataStyle.copyWith(color: AppColors.green)),
              ],
            ),
            const SizedBox(height: 7),
            Text(programme.provider, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(label: programme.level.toUpperCase(), color: AppColors.navy),
                StatusChip(label: programme.duration.toUpperCase(), color: AppColors.slate),
                if (programme.matchedSkills.isNotEmpty)
                  ...programme.matchedSkills.map((skill) => StatusChip(label: skill.toUpperCase(), color: AppColors.green)),
              ],
            ),
            const SizedBox(height: 11),
            Text(programme.summary, style: const TextStyle(color: AppColors.slate, fontSize: 13, height: 1.35)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, size: 16, color: AppColors.slate),
                const SizedBox(width: 6),
                Expanded(child: Text(programme.credential, style: const TextStyle(color: AppColors.slate, fontSize: 12))),
                const SizedBox(width: 8),
                isSaved
                    ? const Text('SAVED', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700))
                    : TextButton.icon(
                        onPressed: onSave,
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
