// M3 ReSource Profile for IndustryHub.
// Design intent: provide a clear, trustworthy business identity and safe local
// listing management while keeping data shapes ready for later Firestore storage.

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
  final _profileFormKey = GlobalKey<FormState>();
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
    final profile = state.profile;
    final ownListings = state.listings.where((item) => item.owner == profile.businessName).toList();
    final hasIdentity = profile.businessName.trim().isNotEmpty && profile.sector.trim().isNotEmpty;
    final hasListings = ownListings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: _goBack,
        ),
        title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(
            eyebrow: 'M3 / RESOURCE PROFILE',
            title: 'Make your business match-ready.',
            description: 'Keep your operating identity current, publish material needs or by-products, and make it easier for partners to understand your context.',
          ),
          const SizedBox(height: 22),
          _ReadinessCard(
            hasIdentity: hasIdentity,
            hasListings: hasListings,
            onAction: hasIdentity ? () => _showAddListing(context) : _startEditing,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_outlined, color: AppColors.navy),
                      const SizedBox(width: 10),
                      Expanded(child: Text(profile.businessName, style: Theme.of(context).textTheme.titleLarge)),
                      const StatusChip(label: 'PROFILE READY', color: AppColors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('This prototype status means your profile has the information needed for a review. It is not an automatic government or third-party verification.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 16),
                  if (_editing)
                    _ProfileEditor(
                      formKey: _profileFormKey,
                      business: _business,
                      sector: _sector,
                      onCancel: _cancelEditing,
                      onSave: () => _saveProfile(profile.businessName, ownListings.isNotEmpty),
                    )
                  else ...[
                    _ProfileLine(label: 'Sector', value: profile.sector),
                    _ProfileLine(label: 'Account role', value: profile.role),
                    const _ProfileLine(label: 'Review status', value: 'Ready for business review'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _startEditing, icon: const Icon(Icons.edit_outlined), label: const Text('Edit profile')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('MY LISTINGS'),
              TextButton.icon(onPressed: () => _showAddListing(context), icon: const Icon(Icons.add, size: 18), label: const Text('Add listing')),
            ],
          ),
          const SizedBox(height: 4),
          Text('${ownListings.length} active listing${ownListings.length == 1 ? '' : 's'} shown in your local prototype session.', style: const TextStyle(color: AppColors.slate, fontSize: 12)),
          const SizedBox(height: 10),
          if (ownListings.isEmpty)
            _ProfileEmptyState(onAddListing: () => _showAddListing(context))
          else
            ...ownListings.map(
              (listing) => _ListingRow(
                listing: listing,
                onDelete: () => _confirmRemoveListing(listing),
              ),
            ),
          const SizedBox(height: 24),
          const SpecDivider(label: 'PROFILE CHECKLIST'),
          const SizedBox(height: 12),
          _ChecklistRow(label: 'Business details', complete: profile.businessName.trim().isNotEmpty),
          _ChecklistRow(label: 'Industry sector', complete: profile.sector.trim().isNotEmpty),
          const _ChecklistRow(label: 'Profile ready for review', complete: true),
          _ChecklistRow(label: 'First marketplace listing', complete: hasListings),
          const SizedBox(height: 8),
          const Text('Later, profile fields and listings can be stored under the signed-in user in Firestore. They are currently held in local app state for the assignment prototype.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing() {
    final profile = ref.read(appStateProvider).profile;
    _business.text = profile.businessName;
    _sector.text = profile.sector;
    setState(() => _editing = false);
  }

  void _saveProfile(String originalBusinessName, bool hasListings) {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    final businessName = _business.text.trim();
    final sector = _sector.text.trim();

    ref.read(appStateProvider.notifier).updateProfile(businessName: businessName, sector: sector);
    setState(() => _editing = false);

    final message = hasListings && businessName != originalBusinessName
        ? 'Profile saved. Existing local listings keep their original owner name until Firestore syncing is added.'
        : 'Profile saved for this session.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddListing(BuildContext context) async {
    final material = TextEditingController();
    final quantity = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var type = 'supply';
    var unit = 'kg';

    final draft = await showDialog<_ListingDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add resource listing'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This listing will appear in ReSource Marketplace during the current prototype session.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Listing type'),
                    items: const [
                      DropdownMenuItem(value: 'supply', child: Text('I can supply')),
                      DropdownMenuItem(value: 'demand', child: Text('I need to buy')),
                    ],
                    onChanged: (value) => setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: material, decoration: const InputDecoration(labelText: 'Material or by-product'), validator: _requiredText),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Quantity ($unit)'),
                          validator: _positiveQuantity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(value: 'tonnes', child: Text('tonnes')),
                            DropdownMenuItem(value: 'pieces', child: Text('pieces')),
                          ],
                          onChanged: (value) => setDialogState(() => unit = value ?? unit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: location, decoration: const InputDecoration(labelText: 'Location'), validator: _requiredText),
                  const SizedBox(height: 12),
                  TextFormField(controller: description, maxLines: 3, maxLength: 240, decoration: const InputDecoration(labelText: 'Material condition or collection notes (optional)', alignLabelWithHint: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  dialogContext,
                  _ListingDraft(
                    type: type,
                    material: material.text.trim(),
                    quantity: double.parse(quantity.text.trim()),
                    unit: unit,
                    location: location.text.trim(),
                    description: description.text.trim(),
                  ),
                );
              },
              child: const Text('Publish listing'),
            ),
          ],
        ),
      ),
    );

    // Let the modal route finish disposing before Riverpod rebuilds Profile.
    // Its TextFormFields still depend on these controllers during the close
    // animation, so dispose them only after the route is completely gone.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    material.dispose();
    quantity.dispose();
    location.dispose();
    description.dispose();

    if (draft == null || !mounted) return;
    await ref.read(appStateProvider.notifier).addListing(
          type: draft.type,
          material: draft.material,
          quantity: draft.quantity,
          unit: draft.unit,
          location: draft.location,
          description: draft.description,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing added to ReSource Marketplace.')));
  }

  Future<void> _confirmRemoveListing(Listing listing) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Text('${listing.material} will no longer appear in ReSource Marketplace during this prototype session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep listing')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove listing')),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;
    ref.read(appStateProvider.notifier).removeListing(listing.id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing removed from the prototype marketplace.')));
  }

  String? _requiredText(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _positiveQuantity(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || amount <= 0) return 'Enter a quantity above zero.';
    return null;
  }
}

class _ListingDraft {
  const _ListingDraft({
    required this.type,
    required this.material,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.description,
  });

  final String type;
  final String material;
  final double quantity;
  final String unit;
  final String location;
  final String description;
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.hasIdentity, required this.hasListings, required this.onAction});

  final bool hasIdentity;
  final bool hasListings;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final complete = [hasIdentity, hasListings].where((value) => value).length;
    final title = !hasIdentity
        ? 'Complete your operating identity'
        : !hasListings
            ? 'Publish your first material listing'
            : 'Your ReSource profile is match-ready';
    final description = !hasIdentity
        ? 'Add a business name and sector before sharing material opportunities.'
        : !hasListings
            ? 'A supply or demand listing makes your business discoverable in Marketplace.'
            : 'Keep listings accurate so local partners can assess a possible exchange.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROFILE READINESS $complete / 2', style: AppTheme.eyebrowStyle.copyWith(color: AppColors.white.withOpacity(0.68))),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(color: AppColors.white.withOpacity(0.82), height: 1.35)),
          if (complete < 2) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.white, side: const BorderSide(color: AppColors.white)),
              icon: Icon(hasIdentity ? Icons.add_box_outlined : Icons.edit_outlined, size: 18),
              label: Text(hasIdentity ? 'Add listing' : 'Complete profile'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEditor extends StatelessWidget {
  const _ProfileEditor({required this.formKey, required this.business, required this.sector, required this.onCancel, required this.onSave});

  final GlobalKey<FormState> formKey;
  final TextEditingController business;
  final TextEditingController sector;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(controller: business, decoration: const InputDecoration(labelText: 'Business name'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a business name.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: sector, decoration: const InputDecoration(labelText: 'Industry sector'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter an industry sector.' : null),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: onSave, child: const Text('Save profile'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 105, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 13))),
            Expanded(child: Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 14))),
          ],
        ),
      );
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({required this.onAddListing});

  final VoidCallback onAddListing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.green, size: 28),
            const SizedBox(height: 12),
            Text('No marketplace listings yet.', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text('Publish a supply or demand listing to make material opportunities visible in ReSource Marketplace.', style: TextStyle(color: AppColors.slate, height: 1.35)),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: onAddListing, icon: const Icon(Icons.add), label: const Text('Add first listing')),
          ],
        ),
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.onDelete});

  final Listing listing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isSupply = listing.type == 'supply';
    final color = isSupply ? AppColors.green : AppColors.rust;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Icon(isSupply ? Icons.arrow_upward : Icons.arrow_downward, color: color),
        title: Text(listing.material, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit} · ${listing.location}\n${isSupply ? 'Supply listing' : 'Demand listing'}'),
        isThreeLine: true,
        trailing: IconButton(onPressed: onDelete, tooltip: 'Remove listing', icon: const Icon(Icons.delete_outline, color: AppColors.rust)),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(complete ? Icons.check_circle : Icons.radio_button_unchecked, color: complete ? AppColors.green : AppColors.slate, size: 20),
        title: Text(label),
        trailing: Text(complete ? 'DONE' : 'NEXT', style: AppTheme.eyebrowStyle.copyWith(color: complete ? AppColors.green : AppColors.slate)),
      );
}
