import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../domain/skill_models.dart';

class ProgrammeRecommendations extends StatelessWidget {
  const ProgrammeRecommendations({
    super.key,
    required this.programmes,
    required this.catalogueStatus,
    required this.savedProgrammeIds,
    required this.onSave,
  });

  final List<RankedProgramme> programmes;
  final String catalogueStatus;
  final Set<String> savedProgrammeIds;
  final ValueChanged<RankedProgramme> onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpecDivider(label: 'STEP 4 / RECOMMENDED PROGRAMMES'),
        const SizedBox(height: 12),
        Text(
          catalogueStatus,
          style: const TextStyle(color: AppColors.slate, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (programmes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No programme currently covers a measured priority gap. Your diagnostic and roadmap remain available.',
              ),
            ),
          ),
        ...programmes.map(
          (ranked) => _RecommendationCard(
            ranked: ranked,
            isSaved: savedProgrammeIds.contains(ranked.programme.id),
            onSave: () => onSave(ranked),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.ranked,
    required this.isSaved,
    required this.onSave,
  });

  final RankedProgramme ranked;
  final bool isSaved;
  final VoidCallback onSave;

  Future<void> _openCourse(BuildContext context) async {
    final value = ranked.programme.sourceUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The programme link could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = ranked.programme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programme.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        programme.provider,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${ranked.matchScore.round()}% MATCH',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ...ranked.components.map(
              (component) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${component.label} (${(component.weight * 100).round()}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      component.score == null
                          ? 'Unavailable'
                          : component.score!.round().toString(),
                      style: TextStyle(
                        color: component.score == null
                            ? AppColors.slate
                            : AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Eyebrow('WHY THIS MATCHES'),
            const SizedBox(height: 5),
            ...ranked.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $reason',
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: programme.sourceUrl.trim().isEmpty
                      ? null
                      : () => _openCourse(context),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open programme'),
                ),
                FilledButton.icon(
                  onPressed: isSaved ? null : onSave,
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 16,
                  ),
                  label: Text(isSaved ? 'Saved' : 'Save match'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              programme.sourceName.isEmpty
                  ? 'Live Supabase catalogue'
                  : programme.sourceName,
              style: const TextStyle(color: AppColors.slate, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
