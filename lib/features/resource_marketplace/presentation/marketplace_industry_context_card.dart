// Official Market Context card for M4 ReSource Marketplace.
// Source: Department of Statistics Malaysia through data.gov.my.

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/industrial_context_repository.dart';

class MarketplaceIndustryContextCard extends StatelessWidget {
  const MarketplaceIndustryContextCard({
    super.key,
    required this.context,
    required this.selectedLocation,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final IndustrialContext? context;
  final String selectedLocation;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final data = this.context;

    return Card(
      color: AppColors.green.withOpacity(0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Official regional industry context', style: typography.titleSmall),
                ),
                IconButton(
                  tooltip: 'Refresh official data',
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Loading DOSM manufacturing context...'),
                  ],
                ),
              )
            else if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: AppColors.slate))
            else if (data == null)
              Text(
                'No state-level manufacturing context is available for $selectedLocation yet.',
                style: const TextStyle(color: AppColors.slate),
              )
            else ...[
              Text(
                '${data.state} manufacturing output: RM ${data.valueRmMillions.toStringAsFixed(1)} million',
                style: typography.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Annual real GDP, reference year ${data.referenceDate.year}.',
                style: const TextStyle(color: AppColors.slate),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Source: Department of Statistics Malaysia via data.gov.my. Context only; listing matches use Marketplace material, quantity, and location data.',
              style: TextStyle(color: AppColors.slate, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
