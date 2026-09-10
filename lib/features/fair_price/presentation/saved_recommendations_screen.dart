import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets.dart';
import '../data/fair_price_recommendation_repository.dart';

class SavedRecommendationsScreen extends StatefulWidget {
  const SavedRecommendationsScreen({super.key});

  @override
  State<SavedRecommendationsScreen> createState() =>
      _SavedRecommendationsScreenState();
}

class _SavedRecommendationsScreenState extends State<SavedRecommendationsScreen> {
  final _repository = FairPriceRecommendationRepository();
  var _isLoading = true;
  String? _error;
  List<SavedFairPriceRecommendation> _recommendations = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadRecommendations);
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchMyRecommendations();
      if (!mounted) return;
      setState(() {
        _recommendations = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Saved recommendations could not be loaded right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecommendation(
      SavedFairPriceRecommendation item,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recommendation?'),
        content: const Text(
          'This saved recommendation will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _repository.deleteRecommendation(item.id);

      if (!mounted) return;

      await _loadRecommendations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendation deleted.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recommendation could not be deleted. Please try again.',
          ),
        ),
      );
    }
  }

  void _showDetails(SavedFairPriceRecommendation item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.product),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Material category', value: item.materialCategory),
              _DetailRow(label: 'Quantity', value: '${item.quantity.toStringAsFixed(0)} kg'),
              _DetailRow(label: 'Proposed', value: 'RM ${item.proposedPricePerKg.toStringAsFixed(2)}/kg'),
              _DetailRow(label: 'Condition', value: item.materialCondition),
              _DetailRow(label: 'Collection', value: item.collectionTerms),
              _DetailRow(label: 'Recommended range', value: 'RM ${item.recommendedLow.toStringAsFixed(2)} – ${item.recommendedHigh.toStringAsFixed(2)}/kg'),
              _DetailRow(label: 'Target', value: 'RM ${item.suggestedTarget.toStringAsFixed(2)}/kg'),
              _DetailRow(label: 'Confidence', value: item.confidence == null ? 'Not available' : item.confidence!.toStringAsFixed(1)),
              _DetailRow(label: 'Peer observations', value: item.peerObservationCount.toString()),
              _DetailRow(label: 'Saved', value: _formatDate(item.createdAt)),
              _DetailRow(label: 'Updated', value: _formatDate(item.updatedAt)),
              if (item.notes.trim().isNotEmpty)
                _DetailRow(label: 'Notes', value: item.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Saved recommendations',
      showBack: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _recommendations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No saved recommendations yet.',
                          style: TextStyle(color: AppColors.slate, fontSize: 16),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: _recommendations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final recommendation = _recommendations[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recommendation.product,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${recommendation.quantity.toStringAsFixed(0)} kg · Proposed: RM ${recommendation.proposedPricePerKg.toStringAsFixed(2)}/kg',
                                  style: const TextStyle(color: AppColors.slate),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recommended: RM ${recommendation.recommendedLow.toStringAsFixed(2)} – ${recommendation.recommendedHigh.toStringAsFixed(2)}/kg',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Target: RM ${recommendation.suggestedTarget.toStringAsFixed(2)}/kg · Saved: ${_formatDate(recommendation.createdAt)}',
                                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _showDetails(recommendation),
                                      child: const Text('View'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        context.push('/fair-price', extra: recommendation).then((_) => _loadRecommendations());
                                      },
                                      child: const Text('Edit / Recalculate'),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () => _deleteRecommendation(recommendation),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.eyebrowStyle),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}
