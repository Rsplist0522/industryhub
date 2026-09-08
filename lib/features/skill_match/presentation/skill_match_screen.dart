import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../data/skill_assessment_repository.dart';
import '../data/training_programme_repository.dart';
import '../domain/learning_roadmap_engine.dart';
import '../domain/programme_ranking_engine.dart';
import '../domain/role_profile_catalogue.dart';
import '../domain/skill_gap_engine.dart';
import '../domain/skill_models.dart';
import 'learning_roadmap_widget.dart';
import 'programme_recommendations.dart';
import 'skill_diagnostic_section.dart';
import 'skill_gap_results.dart';

class SkillMatchScreen extends ConsumerStatefulWidget {
  const SkillMatchScreen({super.key});

  @override
  ConsumerState<SkillMatchScreen> createState() => _SkillMatchScreenState();
}

class _SkillMatchScreenState extends ConsumerState<SkillMatchScreen> {
  final _goalController = TextEditingController();
  final _customRoleController = TextEditingController();
  final _scrollController = ScrollController();
  final _programmeRepository = TrainingProgrammeRepository();
  final _assessmentRepository = SkillAssessmentRepository();
  final _gapEngine = const SkillGapEngine();
  final _rankingEngine = const ProgrammeRankingEngine();
  final _roadmapEngine = const LearningRoadmapEngine();
  final _aiService = const AiService();

  RoleCompetencyProfile? _selectedProfile;
  final Map<String, CompetencyLevel> _answers = {};
  final Set<String> _savedProgrammeIds = {};
  List<ProgrammeCandidate> _catalogue = const [];
  List<RankedProgramme> _rankedProgrammes = const [];
  List<SkillAssessment> _assessmentHistory = const [];
  SkillGapAnalysis? _analysis;
  LearningRoadmap? _roadmap;
  WorkforceSkillSignal? _workforceSignal;
  String _catalogueStatus = 'Loading the live Supabase programme catalogue…';
  String? _aiNotice;
  String? _persistenceNotice;
  String? _savingStageId;
  bool _isInterpreting = false;
  bool _isSavingAssessment = false;
  bool _isLoadingHistory = false;
  bool _isReassessing = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    _goalController.dispose();
    _customRoleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCatalogue(),
      _loadSavedMatches(),
      _loadWorkforceSignal(),
    ]);
  }

  Future<void> _loadCatalogue() async {
    try {
      final programmes = await _programmeRepository.fetchActiveProgrammes();
      if (!mounted) return;
      setState(() {
        _catalogue = programmes.map((item) => item.toCandidate()).toList();
        _catalogueStatus = programmes.isEmpty
            ? 'No active programmes are in Supabase. Run the live-data importer to populate the catalogue.'
            : '${programmes.length} active live catalogue programme${programmes.length == 1 ? '' : 's'} evaluated deterministically.';
        if (_analysis != null) {
          _rankedProgrammes = _rankingEngine.rank(
            programmes: _catalogue,
            analysis: _analysis!,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogue = const [];
        _catalogueStatus =
            'Supabase catalogue unavailable. The diagnostic and roadmap still work; programme ranking will return when the catalogue reconnects.';
      });
    }
  }

  Future<void> _loadSavedMatches() async {
    try {
      final ids = await ref
          .read(appStateProvider.notifier)
          .fetchSavedMatchIds();
      if (mounted) setState(() => _savedProgrammeIds.addAll(ids));
    } catch (_) {
      // Saving remains available and reports its own errors.
    }
  }

  Future<void> _loadWorkforceSignal() async {
    try {
      final signal = await _programmeRepository.fetchLatestWorkforceSignal();
      if (mounted) setState(() => _workforceSignal = signal);
    } catch (_) {
      // This contextual signal is optional and never affects a score.
    }
  }

  Future<void> _interpretCareerGoal() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty || _isInterpreting) return;
    setState(() {
      _isInterpreting = true;
      _aiNotice = null;
    });

    var profile = RoleProfileCatalogue.infer(goal);
    try {
      final response = await _aiService.callAI(
        'Interpret only the target occupation in this career goal. Return JSON with role_id and role_title. Allowed role_id values: software_engineer, data_analyst, cnc_operator, quality_inspector, production_supervisor, welding_technician. Do not calculate readiness, gaps, assessment results, programme scores, or roadmap progress.',
        goal,
      );
      final roleId = response['role_id'] as String?;
      final byId = roleId == null ? null : RoleProfileCatalogue.byId(roleId);
      profile =
          byId ??
          _profileFromTitle('${response['role_title'] ?? ''}') ??
          profile;
      _aiNotice =
          'AI interpreted the goal as ${profile.title}. Confirm or change the role before starting.';
    } catch (error) {
      _aiNotice =
          'AI is unavailable, so the on-device role rules selected ${profile.title}. Numerical features are unaffected. ${describeAiError(error)}';
    }
    if (!mounted) return;
    setState(() => _isInterpreting = false);
    await _selectRole(profile);
  }

  RoleCompetencyProfile? _profileFromTitle(String title) {
    final normalised = title.toLowerCase();
    for (final profile in RoleProfileCatalogue.profiles) {
      final words = profile.title.toLowerCase().split(' ');
      if (words.every(normalised.contains)) return profile;
    }
    return null;
  }

  Future<void> _createCustomRole() async {
    final title = _customRoleController.text.trim();
    if (title.isEmpty) return;
    await _selectRole(RoleProfileCatalogue.custom(title));
  }

  Future<void> _selectRole(RoleCompetencyProfile profile) async {
    setState(() {
      _selectedProfile = profile;
      _answers.clear();
      _analysis = null;
      _rankedProgrammes = const [];
      _roadmap = null;
      _assessmentHistory = const [];
      _persistenceNotice = null;
      _isReassessing = false;
      _isLoadingHistory = true;
    });
    try {
      final results = await Future.wait([
        _assessmentRepository.fetchAssessmentHistory(profile.id),
        _assessmentRepository.fetchLatestRoadmap(profile.id),
      ]);
      if (!mounted || _selectedProfile?.id != profile.id) return;
      final history = results[0] as List<SkillAssessment>;
      final savedRoadmap = results[1] as LearningRoadmap?;
      SkillGapAnalysis? analysis;
      if (history.isNotEmpty) {
        final latest = history.last;
        analysis = _gapEngine.analyse(
          profile: profile,
          answers: latest.answers,
        );
      }
      final ranked = analysis == null
          ? const <RankedProgramme>[]
          : _rankingEngine.rank(programmes: _catalogue, analysis: analysis);
      final resolvedRoadmap =
          savedRoadmap ??
          (analysis == null
              ? null
              : _roadmapEngine.build(
                  analysis: analysis,
                  rankedProgrammes: ranked,
                  assessmentId: history.last.id,
                ));
      setState(() {
        _assessmentHistory = history;
        _analysis = analysis;
        _rankedProgrammes = ranked;
        _roadmap = resolvedRoadmap;
        _isLoadingHistory = false;
        if (history.isNotEmpty) {
          _persistenceNotice =
              'Restored ${history.length} saved assessment${history.length == 1 ? '' : 's'}${savedRoadmap == null ? '; a replacement roadmap was generated locally' : ' and the latest roadmap'}.';
        }
      });
    } catch (_) {
      if (!mounted || _selectedProfile?.id != profile.id) return;
      setState(() {
        _isLoadingHistory = false;
        _persistenceNotice =
            'Saved history could not be loaded. You can still complete the diagnostic offline; new progress will be saved when Supabase is available.';
      });
    }
  }

  void _setAnswer(String id, CompetencyLevel level) {
    setState(() => _answers[id] = level);
  }

  Future<void> _submitAssessment() async {
    final profile = _selectedProfile;
    if (profile == null ||
        _answers.length != profile.competencies.length ||
        _isSavingAssessment) {
      return;
    }
    final answers = profile.competencies
        .map(
          (skill) => SkillAssessmentAnswer(
            competencyId: skill.id,
            level: _answers[skill.id]!,
          ),
        )
        .toList();
    final analysis = _gapEngine.analyse(profile: profile, answers: answers);
    final assessment = SkillAssessment(
      roleProfile: profile,
      answers: answers,
      readinessScore: analysis.readinessScore,
      completedAt: DateTime.now().toUtc(),
    );
    final ranked = _rankingEngine.rank(
      programmes: _catalogue,
      analysis: analysis,
    );
    var roadmap = _roadmapEngine.build(
      analysis: analysis,
      rankedProgrammes: ranked,
    );

    setState(() {
      _analysis = analysis;
      _rankedProgrammes = ranked;
      _roadmap = roadmap;
      _assessmentHistory = [..._assessmentHistory, assessment];
      _isSavingAssessment = true;
      _isReassessing = false;
      _persistenceNotice =
          'Calculated locally. Saving assessment and roadmap to Supabase…';
    });

    try {
      final savedAssessment = await _assessmentRepository.saveAssessment(
        assessment,
      );
      roadmap = _roadmapEngine.build(
        analysis: analysis,
        rankedProgrammes: ranked,
        assessmentId: savedAssessment.id,
      );
      final savedRoadmap = await _assessmentRepository.saveRoadmap(roadmap);
      if (!mounted) return;
      setState(() {
        _assessmentHistory = [
          ..._assessmentHistory.take(_assessmentHistory.length - 1),
          savedAssessment,
        ];
        _roadmap = savedRoadmap;
        _persistenceNotice =
            'Assessment history and roadmap saved to Supabase.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _persistenceNotice =
            'The result is available locally, but Supabase could not save it. Check authentication, connectivity, and that the latest migration is applied.';
      });
    } finally {
      if (mounted) setState(() => _isSavingAssessment = false);
    }
  }

  Future<void> _saveProgramme(RankedProgramme ranked) async {
    if (_savedProgrammeIds.contains(ranked.programme.id)) return;
    try {
      final programme = ranked.programme;
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
      setState(() => _savedProgrammeIds.add(programme.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${programme.name} saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The programme match could not be saved.'),
        ),
      );
    }
  }

  Future<void> _updateRoadmapStatus(
    LearningRoadmapStage stage,
    RoadmapStageStatus status,
  ) async {
    final roadmap = _roadmap;
    if (roadmap == null) return;
    final updatedStages = roadmap.stages
        .map(
          (item) => item.sequence == stage.sequence
              ? item.copyWith(status: status)
              : item,
        )
        .toList();
    setState(() {
      _roadmap = roadmap.copyWith(stages: updatedStages);
      _savingStageId = stage.id;
    });
    if (stage.id == null) {
      setState(() {
        _savingStageId = null;
        _persistenceNotice =
            'This roadmap has not been saved to Supabase, so the status change is local only.';
      });
      return;
    }
    try {
      await _assessmentRepository.updateStageStatus(stage.id!, status);
      if (mounted) {
        setState(
          () => _persistenceNotice = 'Roadmap progress saved to Supabase.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _persistenceNotice =
              'The status changed locally, but Supabase could not persist it.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingStageId = null);
    }
  }

  void _startReassessment() {
    setState(() {
      _answers.clear();
      _isReassessing = true;
    });
    _scrollController.animateTo(
      350,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _reset() async {
    setState(() {
      _selectedProfile = null;
      _answers.clear();
      _analysis = null;
      _roadmap = null;
      _rankedProgrammes = const [];
      _assessmentHistory = const [];
      _aiNotice = null;
      _persistenceNotice = null;
      _isReassessing = false;
    });
    _goalController.clear();
    _customRoleController.clear();
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _selectedProfile;
    final analysis = _analysis;
    final baseline = _assessmentHistory.length > 1
        ? _assessmentHistory.first
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: _goBack,
        ),
        title: const Text('SkillMatch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Start a new diagnostic',
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            const PageIntro(
              eyebrow: 'M1 / SKILLMATCH',
              title: 'Diagnose. Learn. Improve.',
              description:
                  'Choose a target role, complete a deterministic skill diagnostic, compare programme scores, and track a learning roadmap.',
            ),
            const SizedBox(height: 14),
            _FlowStrip(
              hasRole: profile != null,
              hasAssessment: analysis != null,
              hasRoadmap: _roadmap != null,
            ),
            if (_workforceSignal != null) ...[
              const SizedBox(height: 12),
              _WorkforceSignalCard(signal: _workforceSignal!),
            ],
            const SizedBox(height: 20),
            _CareerGoalSection(
              goalController: _goalController,
              customRoleController: _customRoleController,
              selectedProfile: profile,
              isInterpreting: _isInterpreting,
              onInterpret: _interpretCareerGoal,
              onRoleSelected: (id) {
                final selected = RoleProfileCatalogue.byId(id);
                if (selected != null) _selectRole(selected);
              },
              onCreateCustomRole: _createCustomRole,
            ),
            if (_aiNotice != null) ...[
              const SizedBox(height: 9),
              _NoticeCard(text: _aiNotice!, icon: Icons.auto_awesome_outlined),
            ],
            if (_isLoadingHistory) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 5),
              const Text(
                'Loading saved SkillMatch history…',
                style: TextStyle(color: AppColors.slate, fontSize: 12),
              ),
            ],
            if (profile != null &&
                !_isLoadingHistory &&
                (analysis == null || _isReassessing)) ...[
              const SizedBox(height: 24),
              SkillDiagnosticSection(
                profile: profile,
                answers: _answers,
                onAnswerChanged: _setAnswer,
                onSubmit: _submitAssessment,
                isReassessment: _isReassessing,
                isSaving: _isSavingAssessment,
              ),
            ],
            if (analysis != null && !_isReassessing) ...[
              const SizedBox(height: 24),
              SkillGapResults(analysis: analysis, firstAssessment: baseline),
              const SizedBox(height: 24),
              ProgrammeRecommendations(
                programmes: _rankedProgrammes,
                catalogueStatus: _catalogueStatus,
                savedProgrammeIds: _savedProgrammeIds,
                onSave: _saveProgramme,
              ),
              if (_roadmap != null) ...[
                const SizedBox(height: 24),
                LearningRoadmapWidget(
                  roadmap: _roadmap!,
                  savingStageId: _savingStageId,
                  onStatusChanged: _updateRoadmapStatus,
                  onReassess: _startReassessment,
                ),
              ],
            ],
            if (_persistenceNotice != null) ...[
              const SizedBox(height: 12),
              _NoticeCard(
                text: _persistenceNotice!,
                icon: Icons.cloud_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareerGoalSection extends StatelessWidget {
  const _CareerGoalSection({
    required this.goalController,
    required this.customRoleController,
    required this.selectedProfile,
    required this.isInterpreting,
    required this.onInterpret,
    required this.onRoleSelected,
    required this.onCreateCustomRole,
  });

  final TextEditingController goalController;
  final TextEditingController customRoleController;
  final RoleCompetencyProfile? selectedProfile;
  final bool isInterpreting;
  final VoidCallback onInterpret;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onCreateCustomRole;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 1 / CAREER GOAL'),
        const SizedBox(height: 13),
        TextField(
          controller: goalController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onInterpret(),
          decoration: InputDecoration(
            labelText: 'Career goal',
            hintText: 'I want to become a software engineer',
            suffixIcon: IconButton(
              onPressed: isInterpreting ? null : onInterpret,
              tooltip: 'Interpret goal',
              icon: isInterpreting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedProfile?.id),
          initialValue: selectedProfile?.isCustom == false
              ? selectedProfile?.id
              : null,
          decoration: const InputDecoration(labelText: 'Confirm target role'),
          items: RoleProfileCatalogue.profiles
              .map(
                (profile) => DropdownMenuItem(
                  value: profile.id,
                  child: Text(profile.title),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onRoleSelected(value);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customRoleController,
                decoration: const InputDecoration(
                  labelText: 'Or create a custom target role',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onCreateCustomRole,
              child: const Text('Create'),
            ),
          ],
        ),
        if (selectedProfile != null) ...[
          const SizedBox(height: 9),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppColors.green),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${selectedProfile!.title} · ${selectedProfile!.competencies.length} weighted competencies',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FlowStrip extends StatelessWidget {
  const _FlowStrip({
    required this.hasRole,
    required this.hasAssessment,
    required this.hasRoadmap,
  });

  final bool hasRole;
  final bool hasAssessment;
  final bool hasRoadmap;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Goal', true),
      ('2', 'Diagnostic', hasRole),
      ('3', 'Gap', hasAssessment),
      ('4', 'Programmes', hasAssessment),
      ('5', 'Roadmap', hasRoadmap),
      ('6', 'Progress', hasRoadmap),
      ('7', 'Reassess', hasRoadmap),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.map((step) {
          final active = step.$3;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: active ? AppColors.green : AppColors.line,
                child: Text(
                  step.$1,
                  style: const TextStyle(color: AppColors.white, fontSize: 10),
                ),
              ),
              label: Text(step.$2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WorkforceSignalCard extends StatelessWidget {
  const _WorkforceSignalCard({required this.signal});

  final WorkforceSkillSignal signal;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.public, color: AppColors.navy, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Malaysia workforce context: ${signal.variable}, ${signal.value.toStringAsFixed(1)} ${signal.unit}. Context only; it does not affect your score.',
              style: const TextStyle(color: AppColors.slate, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.slate),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.slate, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
