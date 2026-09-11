import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../domain/skill_models.dart';

class SkillCoachPanel extends StatefulWidget {
  const SkillCoachPanel({
    super.key,
    required this.messages,
    required this.isThinking,
    required this.onAsk,
    this.error,
  });

  final List<SkillCoachMessage> messages;
  final bool isThinking;
  final ValueChanged<String> onAsk;
  final String? error;

  @override
  State<SkillCoachPanel> createState() => _SkillCoachPanelState();
}

class _SkillCoachPanelState extends State<SkillCoachPanel> {
  final _controller = TextEditingController();

  static const _suggestions = [
    'Explain my biggest gap',
    'What should I do this week?',
    'Explain the Malaysia data',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? preset]) {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || widget.isThinking) return;

    _controller.clear();
    widget.onAsk(question);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(
          label: 'AI SKILL COACH / EVIDENCE-GROUNDED',
        ),
        const SizedBox(height: 14),
        Text(
          'Ask about your result',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        const Text(
          'The coach explains your calculated results and DOSM evidence. '
          'It cannot change scores or invent programmes. This conversation '
          'stays on this device for the current session.',
          style: TextStyle(
            color: AppColors.slate,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (suggestion) => ActionChip(
                  avatar: Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: widget.isThinking
                        ? AppColors.slate
                        : AppColors.navy,
                  ),
                  label: Text(
                    suggestion,
                    style: TextStyle(
                      color: widget.isThinking
                          ? AppColors.slate
                          : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: AppColors.white,
                  disabledColor:
                      AppColors.slate.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: widget.isThinking
                        ? AppColors.line.withValues(alpha: 0.65)
                        : AppColors.line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: widget.isThinking
                      ? null
                      : () => _submit(suggestion),
                ),
              )
              .toList(),
        ),

        if (widget.messages.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...widget.messages.map(_MessageCard.new),
        ],

        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: const TextStyle(
              color: AppColors.rust,
              fontSize: 12,
            ),
          ),
        ],

        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ask the AI coach',
                  hintText: 'How should I practise my top gap?',
                  labelStyle: TextStyle(
                    color: AppColors.slate,
                  ),
                  hintStyle: TextStyle(
                    color: AppColors.slate,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.isThinking ? null : _submit,
              tooltip: 'Ask coach',
              icon: widget.isThinking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message);

  final SkillCoachMessage message;

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                message.isUser ? AppColors.navy : AppColors.white,
            border: Border.all(
              color:
                  message.isUser ? AppColors.navy : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? AppColors.white
                      : AppColors.ink,
                  height: 1.4,
                ),
              ),
              if (message.actionSteps.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...message.actionSteps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: TextStyle(
                            color: message.isUser
                                ? AppColors.white
                                : AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      );
}
