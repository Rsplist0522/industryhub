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
    required this.fallbackQuery,
  });

  final List<RankedProgramme> programmes;
  final String catalogueStatus;
  final Set<String> savedProgrammeIds;
  final ValueChanged<RankedProgramme> onSave;
  final String fallbackQuery;

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
        if (programmes.isEmpty) _CatalogueFallbackCard(query: fallbackQuery),
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
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: AppColors.slate,
                ),
                const SizedBox(width: 6),
                Text(
                  '${ranked.evidenceCoverage.round()}% catalogue evidence available',
                  style: const TextStyle(color: AppColors.slate, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            if (programme.metadataNote.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                programme.metadataNote,
                style: const TextStyle(color: AppColors.slate, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogueFallbackCard extends StatelessWidget {
  const _CatalogueFallbackCard({required this.query});

  final String query;

  Future<void> _openUri(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The live course search could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No verified catalogue programme currently covers your measured gaps. SkillMatch will not invent a recommendation.',
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openUri(
                  context,
                  Uri.parse('https://upskillmalaysia.gov.my/'),
                ),
                icon: const Icon(Icons.account_balance_outlined, size: 17),
                label: const Text('Open Upskill Malaysia'),
              ),
              OutlinedButton.icon(
                onPressed: query.trim().isEmpty
                    ? null
                    : () => _openUri(
                        context,
                        Uri.parse(
                          'https://www.coursera.org/search?query=${Uri.encodeQueryComponent(query)}',
                        ),
                      ),
                icon: const Icon(Icons.travel_explore, size: 17),
                label: const Text('Search live courses'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
