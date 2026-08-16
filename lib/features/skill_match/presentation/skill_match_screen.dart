import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

class _ChatLine {
  const _ChatLine(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class _Program {
  const _Program({required this.name, required this.provider, required this.level, required this.duration, required this.match});
  final String name;
  final String provider;
  final String level;
  final String duration;
  final int match;
}

class SkillMatchScreen extends ConsumerStatefulWidget {
  const SkillMatchScreen({super.key});

  @override
  ConsumerState<SkillMatchScreen> createState() => _SkillMatchScreenState();
}

class _SkillMatchScreenState extends ConsumerState<SkillMatchScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatLine>[
    const _ChatLine('Tell me what capability you need to build. Include the role, current experience, or any certification requirement.', false),
  ];
  bool _isThinking = false;
  Map<String, dynamic>? _requirement;
  List<_Program> _programs = const [];

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
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    final lower = text.toLowerCase();
    final skills = <String>[
      if (lower.contains('cnc') || lower.contains('machin')) 'CNC machining',
      if (lower.contains('lean') || lower.contains('process')) 'Lean manufacturing',
      if (lower.contains('quality') || lower.contains('iso')) 'Quality systems',
      if (lower.contains('weld')) 'Welding',
    ];
    if (skills.isEmpty) skills.addAll(['CNC machining', 'Lean manufacturing']);
    setState(() {
      _isThinking = false;
      _requirement = {
        'skills': skills,
        'experience': lower.contains('senior') || lower.contains('5 year') ? 'Intermediate / senior' : 'Entry to intermediate',
        'certification': lower.contains('iso') ? 'ISO 9001 internal auditor' : 'HRD Corp claimable preferred',
      };
      _programs = [
        const _Program(name: 'CNC Programming & Setup', provider: 'Penang Skills Development Centre', level: 'Intermediate', duration: '3 days', match: 94),
        const _Program(name: 'Lean Manufacturing Essentials', provider: 'Malaysia Productivity Corporation', level: 'Foundation', duration: '2 days', match: 86),
        const _Program(name: 'Industrial Quality Systems', provider: 'SIRIM Academy', level: 'Intermediate', duration: '4 days', match: 72),
      ];
      _messages.add(const _ChatLine('I translated that into a structured requirement and ranked the closest local programmes below. You can save any match to your profile.', false));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skill Advisor'), automaticallyImplyLeading: true),
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
                  description: 'Describe the gap in plain language. The prototype turns it into a structured brief and compares it with a local programme catalogue.',
                ),
                const SizedBox(height: 22),
                const SpecDivider(label: 'CONVERSATION'),
                const SizedBox(height: 16),
                ..._messages.map((message) => ChatBubble(text: message.text, isUser: message.isUser)),
                if (_isThinking) const _TypingBubble(),
                if (_requirement != null) ...[
                  const SizedBox(height: 6),
                  _RequirementCard(requirement: _requirement!),
                  const SizedBox(height: 18),
                  const SpecDivider(label: 'RANKED PROGRAMMES'),
                  const SizedBox(height: 14),
                  ..._programs.map((program) => _ProgramCard(program: program, onSave: () { ref.read(appStateProvider.notifier).saveMatch(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match saved to profile.'))); })),
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
        child: const Text('···', style: TextStyle(fontSize: 20, color: AppColors.slate, letterSpacing: 4)),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 3, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'e.g. Need a CNC operator for our second shift…'))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: isThinking ? null : onSend, icon: const Icon(Icons.arrow_upward)),
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement});
  final Map<String, dynamic> requirement;

  @override
  Widget build(BuildContext context) {
    final skills = (requirement['skills'] as List<String>).join('  /  ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Eyebrow('REQUIREMENT'), StatusChip(label: 'STRUCTURED', color: AppColors.green)]),
            const SizedBox(height: 14),
            _SpecRow(label: 'Skills', value: skills),
            _SpecRow(label: 'Experience', value: requirement['experience'] as String),
            _SpecRow(label: 'Certification', value: requirement['certification'] as String),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12))), Expanded(child: Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 13)))]),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onSave});
  final _Program program;
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
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(program.name, style: Theme.of(context).textTheme.titleMedium)), Text('${program.match}%', style: AppTheme.dataStyle.copyWith(color: AppColors.green))]),
            const SizedBox(height: 7),
            Text(program.provider, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate)),
            const SizedBox(height: 12),
            Row(children: [StatusChip(label: program.level, color: AppColors.navy), const SizedBox(width: 8), StatusChip(label: program.duration, color: AppColors.slate), const Spacer(), TextButton(onPressed: onSave, child: const Text('Save match'))]),
          ],
        ),
      ),
    );
  }
}
