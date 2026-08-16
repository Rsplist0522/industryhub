import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(appStateProvider).listings.where((listing) {
      final matchesFilter = _filter == 'all' || listing.type == _filter;
      final query = _search.text.toLowerCase();
      final matchesSearch = query.isEmpty || listing.material.toLowerCase().contains(query) || listing.location.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ReSource Marketplace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(eyebrow: 'M4 / RESOURCE MARKETPLACE', title: 'Materials in motion.', description: 'Browse verified supply and demand from industrial businesses across Malaysia.'),
          const SizedBox(height: 22),
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search material or location', suffixIcon: Icon(Icons.tune_outlined))),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _FilterChip(label: 'All listings', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Supply', selected: _filter == 'supply', color: AppColors.green, onTap: () => setState(() => _filter = 'supply')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Demand', selected: _filter == 'demand', color: AppColors.rust, onTap: () => setState(() => _filter = 'demand')),
          ])),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Eyebrow('LIVE LISTINGS'), Text('${listings.length} results', style: const TextStyle(color: AppColors.slate, fontSize: 12))]),
          const SizedBox(height: 10),
          if (listings.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('No matching listings yet. Try a different material, location, or filter.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate))))
          else
            ...listings.map((listing) => _MarketplaceCard(listing: listing, onTap: () => _showDetail(context, listing))),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, Listing listing) async {
    final isSupply = listing.type == 'supply';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(listing.material, style: Theme.of(context).textTheme.titleLarge)), StatusChip(label: isSupply ? 'SUPPLY' : 'DEMAND', color: isSupply ? AppColors.green : AppColors.rust)]),
            const SizedBox(height: 14),
            _DetailLine(label: 'Business', value: listing.owner),
            _DetailLine(label: 'Quantity', value: '${listing.quantity.toStringAsFixed(0)} ${listing.unit}'),
            _DetailLine(label: 'Location', value: listing.location),
            _DetailLine(label: 'Description', value: listing.description),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(context); _sendRequest(listing); }, icon: const Icon(Icons.handshake_outlined), label: const Text('Send deal request'))),
          ]),
        ),
      ),
    );
  }

  void _sendRequest(Listing listing) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deal request sent to ${listing.owner}.')));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.navy});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: selected ? color : AppColors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: selected ? color : AppColors.line)),
        child: Text(label, style: TextStyle(color: selected ? AppColors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.listing, required this.onTap});
  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSupply = listing.type == 'supply';
    final color = isSupply ? AppColors.green : AppColors.rust;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [StatusChip(label: isSupply ? 'SUPPLY' : 'DEMAND', color: color), const Spacer(), if (listing.verified) const Icon(Icons.verified_outlined, size: 18, color: AppColors.green)]),
            const SizedBox(height: 11),
            Text(listing.material, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(children: [Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit}', style: AppTheme.dataStyle.copyWith(fontSize: 14)), const SizedBox(width: 12), const Icon(Icons.location_on_outlined, size: 15, color: AppColors.slate), const SizedBox(width: 3), Expanded(child: Text(listing.location, style: const TextStyle(color: AppColors.slate, fontSize: 12)))]),
            const SizedBox(height: 11),
            Text(listing.owner, style: const TextStyle(color: AppColors.slate, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 86, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12))), Expanded(child: Text(value, style: const TextStyle(fontSize: 14, height: 1.35)))]));
}
