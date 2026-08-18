import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  late final TextEditingController _business;
  late final TextEditingController _sector;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appStateProvider).profile;
    _business = TextEditingController(text: profile.businessName);
    _sector = TextEditingController(text: profile.sector);
  }

  @override
  void dispose() {
    _business.dispose();
    _sector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final ownListings = state.listings.where((item) => item.owner == state.profile.businessName).toList();
    return Scaffold(
      appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Go back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(eyebrow: 'M3 / RESOURCE PROFILES', title: 'Your operating profile.', description: 'Keep your business identity clear so the right partners can trust and contact you.'),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.business_outlined, color: AppColors.navy), const SizedBox(width: 10), Expanded(child: Text(state.profile.businessName, style: Theme.of(context).textTheme.titleLarge)), const StatusChip(label: 'VERIFIED', color: AppColors.green)]),
                const SizedBox(height: 16),
                if (_editing) ...[
                  TextField(controller: _business, decoration: const InputDecoration(labelText: 'Business name')),
                  const SizedBox(height: 12),
                  TextField(controller: _sector, decoration: const InputDecoration(labelText: 'Sector')),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: () { ref.read(appStateProvider.notifier).updateProfile(businessName: _business.text, sector: _sector.text); setState(() => _editing = false); }, child: const Text('Save profile')))]),
                ] else ...[
                  _ProfileLine(label: 'Sector', value: state.profile.sector),
                  _ProfileLine(label: 'Account role', value: state.profile.role),
                  _ProfileLine(label: 'Verification', value: 'Business details reviewed'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit_outlined), label: const Text('Edit profile')),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Eyebrow('MY LISTINGS'), TextButton.icon(onPressed: () => _showAddListing(context), icon: const Icon(Icons.add, size: 18), label: const Text('Add listing'))]),
          const SizedBox(height: 8),
          if (ownListings.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('No listings yet — add your first material to start matching with buyers.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate))))
          else
            ...ownListings.map((listing) => _ListingRow(listing: listing, onDelete: () => ref.read(appStateProvider.notifier).removeListing(listing.id))),
          const SizedBox(height: 24),
          const SpecDivider(label: 'PROFILE CHECKLIST'),
          const SizedBox(height: 14),
          const _ChecklistRow(label: 'Business details', complete: true),
          const _ChecklistRow(label: 'Industry sector', complete: true),
          const _ChecklistRow(label: 'Verification review', complete: true),
          const _ChecklistRow(label: 'First marketplace listing', complete: false),
        ],
      ),
    );
  }

  Future<void> _showAddListing(BuildContext context) async {
    final material = TextEditingController();
    final quantity = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();
    String type = 'supply';
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add resource listing'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Listing type'), items: const [DropdownMenuItem(value: 'supply', child: Text('I can supply')), DropdownMenuItem(value: 'demand', child: Text('I need to buy'))], onChanged: (value) => setDialogState(() => type = value!)),
          const SizedBox(height: 12),
          TextFormField(controller: material, decoration: const InputDecoration(labelText: 'Material'), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (kg)'), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: location, decoration: const InputDecoration(labelText: 'Location'), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (!(formKey.currentState?.validate() ?? false)) return; ref.read(appStateProvider.notifier).addListing(type: type, material: material.text, quantity: double.tryParse(quantity.text) ?? 0, unit: 'kg', location: location.text, description: description.text); Navigator.pop(context); }, child: const Text('Add listing'))],
      )),
    );
    material.dispose();
    quantity.dispose();
    location.dispose();
    description.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [SizedBox(width: 105, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 13))), Expanded(child: Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 14)))]));
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.onDelete});
  final Listing listing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isSupply = listing.type == 'supply';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Icon(isSupply ? Icons.arrow_upward : Icons.arrow_downward, color: isSupply ? AppColors.green : AppColors.rust),
        title: Text(listing.material, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit} · ${listing.location}'),
        trailing: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.rust)),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.complete});
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(complete ? Icons.check_circle : Icons.radio_button_unchecked, color: complete ? AppColors.green : AppColors.slate, size: 20), title: Text(label), trailing: Text(complete ? 'DONE' : 'NEXT', style: AppTheme.eyebrowStyle.copyWith(color: complete ? AppColors.green : AppColors.slate)));
}
