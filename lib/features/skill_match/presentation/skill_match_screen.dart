import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../data/skill_assessment_repository.dart';
import '../data/skill_coach_service.dart';
import '../data/training_programme_repository.dart';
import '../domain/learning_roadmap_engine.dart';
import '../domain/programme_ranking_engine.dart';
import '../domain/role_profile_catalogue.dart';
import '../domain/skill_gap_engine.dart';
import '../domain/skill_models.dart';
import '../domain/workforce_insight_engine.dart';
import 'learning_roadmap_widget.dart';
import 'malaysia_workforce_insight_card.dart';
import 'programme_recommendations.dart';
import 'skill_coach_panel.dart';
import 'skill_diagnostic_section.dart';
import 'skill_gap_results.dart';

class SkillMatchScreen extends ConsumerStatefulWidget {
  const SkillMatchScreen({super.key});

  @override
  ConsumerState<SkillMatchScreen> createState() => _SkillMatchScreenState();
}

class _SkillMatchScreenState extends ConsumerState<SkillMatchScreen> {
  final _scrollController = ScrollController();
  final _diagnosticSectionKey = GlobalKey();
  final _roleCatalogue = RoleProfileCatalogue();
  final _programmeRepository = TrainingProgrammeRepository();
  final _assessmentRepository = SkillAssessmentRepository();
  final _coachService = SkillCoachService();
  final _gapEngine = const SkillGapEngine();
  final _rankingEngine = const ProgrammeRankingEngine();
  final _roadmapEngine = const LearningRoadmapEngine();
  final _workforceEngine = const WorkforceInsightEngine();

  RoleCompetencyProfile? _selectedProfile;
  final Map<String, CompetencyLevel> _answers = {};
  final Set<String> _savedProgrammeIds = {};
  List<ProgrammeCandidate> _catalogue = const [];
  List<RankedProgramme> _rankedProgrammes = const [];
  List<SkillAssessment> _assessmentHistory = const [];
  List<RoleCompetencyProfile> _roleProfiles = const [];
  List<WorkforceSkillSignal> _workforceSignals = const [];
  List<SkillCoachMessage> _coachMessages = const [];
  SkillGapAnalysis? _analysis;
  LearningRoadmap? _roadmap;
  String? _selectedAgeGroup;
  String _roleLibraryStatus = 'Loading the role profile library...';
  String? _workforceError;
  String? _coachError;
  String _catalogueStatus = 'Loading the live Supabase programme catalogue…';
  String? _persistenceNotice;
  String? _savingStageId;
  bool _isSavingAssessment = false;
  bool _isLoadingHistory = false;
  bool _isReassessing = false;
  bool _isLoadingWorkforce = true;
  bool _isCoachThinking = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadRoleProfiles(),
      _loadCatalogue(),
      _loadSavedMatches(),
      _loadWorkforceSignals(),
    ]);
  }

  Future<void> _loadRoleProfiles() async {
    try {
      final profiles = await _roleCatalogue.load();
      if (!mounted) return;
      setState(() {
        _roleProfiles = profiles;
        _roleLibraryStatus =
            '${profiles.length} industrial and digital role profiles loaded once from the bundled catalogue.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roleProfiles = const [];
        _roleLibraryStatus =
            'The role profile library could not be loaded. Check the bundled role data.';
      });
    }
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

    }
  }

  Future<void> _loadWorkforceSignals() async {
    try {
      final signals = await _programmeRepository.fetchWorkforceSkillSignals();
      final groups = _workforceEngine.ageGroups(signals);
      if (!mounted) return;
      setState(() {
        _workforceSignals = signals;
        _selectedAgeGroup = groups.isEmpty ? null : groups.first;
        _isLoadingWorkforce = false;
        _workforceError = signals.isEmpty
            ? 'DOSM returned no usable skills-related underemployment records.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingWorkforce = false;
        _workforceError =
            'DOSM data is temporarily unavailable. Diagnostics remain usable without it.';
      });
    }
  }

  Future<void> _selectRole(RoleCompetencyProfile profile) async {
    setState(() {
      _selectedProfile = profile;
      _answers.clear();
      _analysis = null;
      _rankedProgrammes = const [];
      _roadmap = null;
      _assessmentHistory = const [];
      _coachMessages = const [];
      _coachError = null;
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

  MalaysiaWorkforceInsight? get _workforceInsight {
    final group = _selectedAgeGroup;
    if (group == null) return null;
    return _workforceEngine.build(signals: _workforceSignals, ageGroup: group);
  }

  void _changeAgeGroup(String value) {
    setState(() {
      _selectedAgeGroup = value;
      _coachMessages = const [];
      _coachError = null;
    });
  }

  Future<void> _askCoach(String question) async {
    final analysis = _analysis;
    if (analysis == null || _isCoachThinking) return;
    final userMessage = SkillCoachMessage(text: question, isUser: true);
    setState(() {
      _coachMessages = [..._coachMessages, userMessage];
      _isCoachThinking = true;
      _coachError = null;
    });
    try {
      final reply = await _coachService.ask(
        question: question,
        analysis: analysis,
        programmes: _rankedProgrammes,
        roadmap: _roadmap,
        workforceInsight: _workforceInsight,
      );
      if (!mounted) return;
      setState(() => _coachMessages = [..._coachMessages, reply]);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _coachError =
            'AI coach unavailable. Your diagnostic, ranking, and roadmap still work. ${describeAiError(error)}';
      });
    } finally {
      if (mounted) setState(() => _isCoachThinking = false);
    }
  }

  void _startReassessment() {
    setState(() {
      _answers.clear();
      _isReassessing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSection(_diagnosticSectionKey);
    });
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      alignment: 0.06,
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
      _coachMessages = const [];
      _coachError = null;
      _persistenceNotice = null;
      _isReassessing = false;
    });
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
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
    final ageGroups = _workforceEngine.ageGroups(_workforceSignals);
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
            const SizedBox(height: 12),
            MalaysiaWorkforceInsightCard(
              ageGroups: ageGroups,
              selectedAgeGroup: _selectedAgeGroup,
              onAgeGroupChanged: _changeAgeGroup,
              isLoading: _isLoadingWorkforce,
              insight: _workforceInsight,
              error: _workforceError,
            ),
            const SizedBox(height: 20),
            _TargetRoleSection(
              profiles: _roleProfiles,
              libraryStatus: _roleLibraryStatus,
              selectedProfile: profile,
              onRoleSelected: (id) {
                final selected = _roleCatalogue.byId(id);
                if (selected != null) _selectRole(selected);
              },
            ),
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
                key: _diagnosticSectionKey,
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
                fallbackQuery: [
                  profile!.title,
                  ...analysis.priorityGaps
                      .take(3)
                      .map((gap) => gap.competency.name),
                ].join(' '),
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
              const SizedBox(height: 24),
              SkillCoachPanel(
                messages: _coachMessages,
                isThinking: _isCoachThinking,
                error: _coachError,
                onAsk: _askCoach,
              ),
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

class _TargetRoleSection extends StatelessWidget {
  const _TargetRoleSection({
    required this.profiles,
    required this.libraryStatus,
    required this.selectedProfile,
    required this.onRoleSelected,
  });

  final List<RoleCompetencyProfile> profiles;
  final String libraryStatus;
  final RoleCompetencyProfile? selectedProfile;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 1 / TARGET ROLE'),
        const SizedBox(height: 13),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedProfile?.id),
          isExpanded: true,
          initialValue: selectedProfile?.isCustom == false
              ? selectedProfile?.id
              : null,
          decoration: const InputDecoration(
            labelText: 'Target role',
            hintText: 'Choose the role you want to assess',
          ),
          items: profiles
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
        const SizedBox(height: 7),
        Text(
          libraryStatus,
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
        if (selectedProfile != null) ...[
          const SizedBox(height: 9),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${selectedProfile!.title} - ${selectedProfile!.competencies.length} weighted competencies',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (selectedProfile!.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      selectedProfile!.summary,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (selectedProfile!.frameworkNote.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      selectedProfile!.frameworkNote,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  if (selectedProfile!.frameworkSourceName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Role reference: ${selectedProfile!.frameworkSourceName}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
