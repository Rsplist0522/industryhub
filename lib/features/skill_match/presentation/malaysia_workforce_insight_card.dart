import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../domain/skill_models.dart';

class MalaysiaWorkforceInsightCard extends StatelessWidget {
  const MalaysiaWorkforceInsightCard({
    super.key,
    required this.ageGroups,
    required this.selectedAgeGroup,
    required this.onAgeGroupChanged,
    required this.isLoading,
    this.insight,
    this.error,
  });

  final List<String> ageGroups;
  final String? selectedAgeGroup;
  final ValueChanged<String> onAgeGroupChanged;
  final bool isLoading;
  final MalaysiaWorkforceInsight? insight;
  final String? error;

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(insight?.sourceUrl ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The DOSM source page could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = insight;
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, color: AppColors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MALAYSIA WORKFORCE EVIDENCE',
                    style: AppTheme.eyebrowStyle.copyWith(
                      color: AppColors.amber,
                    ),
                  ),
                ),
                const _LiveBadge(),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'DOSM measures tertiary-educated people working in semi-skilled or low-skilled jobs. Select an age group to examine the latest official context.',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const LinearProgressIndicator()
            else if (data == null)
              Text(
                error ?? 'Official workforce data is temporarily unavailable.',
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final selector = _AgeGroupSelector(
                    ageGroups: ageGroups,
                    selectedAgeGroup: selectedAgeGroup,
                    onChanged: onAgeGroupChanged,
                  );
                  final metrics = Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      _Metric(label: 'LATEST PERIOD', value: data.periodLabel),
                      _Metric(
                        label: 'UNDEREMPLOYMENT RATE',
                        value: '${data.rate.toStringAsFixed(1)}%',
                      ),
                      if (data.peopleThousands != null)
                        _Metric(
                          label: 'AFFECTED PEOPLE',
                          value: '${data.peopleThousands!.toStringAsFixed(1)}k',
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [selector, const SizedBox(height: 14), metrics],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(width: 280, child: selector),
                      const SizedBox(width: 30),
                      Expanded(child: metrics),
                    ],
                  );
                },
              ),
              if (data.rateChange != null) ...[
                const SizedBox(height: 10),
                Text(
                  '${data.rateChange! > 0
                      ? 'Increased'
                      : data.rateChange! < 0
                      ? 'Decreased'
                      : 'Unchanged'} by ${data.rateChange!.abs().toStringAsFixed(1)} percentage points from the previous quarter.',
                  style: const TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Used as labour-market context and in AI explanations. It never changes your personal diagnostic score.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openSource(context),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('Open ${data.sourceName} source'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgeGroupSelector extends StatelessWidget {
  const _AgeGroupSelector({
    required this.ageGroups,
    required this.selectedAgeGroup,
    required this.onChanged,
  });

  final List<String> ageGroups;
  final String? selectedAgeGroup;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'DOSM AGE GROUP',
        style: AppTheme.eyebrowStyle.copyWith(color: AppColors.amber),
      ),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(
        initialValue: selectedAgeGroup,
        isExpanded: true,
        dropdownColor: AppColors.white,
        style: const TextStyle(color: AppColors.ink),
        decoration: const InputDecoration(
          filled: true,
          fillColor: AppColors.white,
          hintText: 'Select an age group',
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: ageGroups
            .map((group) => DropdownMenuItem(value: group, child: Text(group)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTheme.eyebrowStyle.copyWith(color: AppColors.amber),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppTheme.dataStyle.copyWith(
          color: AppColors.white,
          fontSize: 20,
        ),
      ),
    ],
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'LIVE API / CACHE',
      style: TextStyle(
        color: AppColors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
