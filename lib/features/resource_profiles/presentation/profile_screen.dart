// M3 ReSource Profile for IndustryHub.
// Design intent: provide a clear, trustworthy business identity and safe listing
// management backed by the signed-in user's Supabase workspace.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../../../core/validators.dart';
import '../data/msic_repository.dart';

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
  final _msicRepository = MsicRepository();
  final _profileAiInput = TextEditingController();
  final _aiService = const AiService();
  List<IndustrySector> _industrySectors = const [];
  bool _isLoadingIndustrySectors = true;
  bool _isProfileAiThinking = false;
  String? _profileAiAnswer;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appStateProvider).profile;
    _business = TextEditingController(text: profile.businessName);
    _sector = TextEditingController(text: profile.sector);
    Future<void>.microtask(_loadIndustrySectors);
  }

  Future<void> _loadIndustrySectors() async {
    try {
      final sectors = await _msicRepository.fetchTopLevelSectors();
      if (!mounted) return;
      setState(() {
        _industrySectors = sectors;
        _isLoadingIndustrySectors = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingIndustrySectors = false);
      debugPrint('MSIC sector catalogue could not be loaded: $error');
    }
  }

  @override
  void dispose() {
    _business.dispose();
    _sector.dispose();
    _profileAiInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final profile = state.profile;
    final ownListings = state.listings
        .where((item) => item.owner == profile.businessName)
        .toList();
    final hasIdentity =
        profile.businessName.trim().isNotEmpty &&
        profile.sector.trim().isNotEmpty;
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
            description:
                'Keep your operating identity current, publish material needs or by-products, and make it easier for partners to understand your context.',
          ),
          const SizedBox(height: 22),
          _ReadinessCard(
            hasIdentity: hasIdentity,
            hasListings: hasListings,
            onAction: hasIdentity
                ? () => _showAddListing(context)
                : _startEditing,
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
                      const Icon(
                        Icons.business_outlined,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          profile.businessName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const StatusChip(
                        label: 'PROFILE READY',
                        color: AppColors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This readiness status means your profile has the information needed for a review. It is not an automatic government or third-party verification.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_editing)
                    _ProfileEditor(
                      formKey: _profileFormKey,
                      business: _business,
                      sector: _sector,
                      sectors: _industrySectors,
                      isLoadingSectors: _isLoadingIndustrySectors,
                      onRefreshSectors: _loadIndustrySectors,
                      onCancel: _cancelEditing,
                      onSave: () => _saveProfile(
                        profile.businessName,
                        ownListings.isNotEmpty,
                      ),
                    )
                  else ...[
                    _ProfileLine(label: 'Sector', value: profile.sector),
                    if (profile.msicCode != null)
                      _ProfileLine(
                        label: 'MSIC code',
                        value:
                            '${profile.msicCode} · ${profile.msicDescription ?? profile.sector}',
                      ),
                    _ProfileLine(label: 'Account role', value: profile.role),
                    const _ProfileLine(
                      label: 'Review status',
                      value: 'Ready for business review',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ProfileAiAdvisor(
            controller: _profileAiInput,
            answer: _profileAiAnswer,
            isThinking: _isProfileAiThinking,
            onAsk: _askProfileAi,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('MY LISTINGS'),
              TextButton.icon(
                onPressed: () => _showAddListing(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add listing'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ownListings.length} active listing${ownListings.length == 1 ? '' : 's'} stored in your Supabase workspace.',
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (ownListings.isEmpty)
            _ProfileEmptyState(onAddListing: () => _showAddListing(context))
          else
            ...ownListings.map(
              (listing) => _ListingRow(
                listing: listing,
                onEdit: () => _showEditListing(listing),
                onDelete: () => _confirmRemoveListing(listing),
              ),
            ),
          const SizedBox(height: 24),
          const SpecDivider(label: 'PROFILE CHECKLIST'),
          const SizedBox(height: 12),
          _ChecklistRow(
            label: 'Business details',
            complete: profile.businessName.trim().isNotEmpty,
          ),
          _ChecklistRow(
            label: 'Industry sector',
            complete: profile.sector.trim().isNotEmpty,
          ),
          const _ChecklistRow(
            label: 'Profile ready for review',
            complete: true,
          ),
          _ChecklistRow(
            label: 'First marketplace listing',
            complete: hasListings,
          ),
          const SizedBox(height: 8),
          const Text(
            'Business details and listings are stored under your anonymous Supabase workspace. Add a verified identity workflow before treating this readiness status as formal verification.',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              height: 1.35,
            ),
          ),
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

  Future<void> _askProfileAi() async {
    if (_isProfileAiThinking) return;
    final question = _profileAiInput.text.trim();
    final profile = ref.read(appStateProvider).profile;
    final prompt = question.isEmpty
        ? 'Review this business profile and suggest the most useful next capability or resource action.'
        : question;
    setState(() => _isProfileAiThinking = true);
    try {
      final response = await _aiService.callAI(
        'You are IndustryHub Profile Advisor. Review a Malaysian industrial SME profile and answer the user question. Return exactly these JSON keys: assistant_message, priority_actions (array of concise strings), resource_opportunities (array of concise strings), caveats (array of concise strings). Use the profile and MSIC context only; do not claim government verification, legal compliance, or guaranteed business outcomes.',
        'Business: ${profile.businessName}\nSector: ${profile.sector}\nRole: ${profile.role}\nMSIC: ${profile.msicCode ?? 'not selected'} · ${profile.msicDescription ?? 'not selected'}\nUser question: $prompt',
      );
      if (!mounted) return;
      final assistantMessage = response['assistant_message'] is String
          ? (response['assistant_message'] as String).trim()
          : '';
      final priorities = response['priority_actions'] is List
          ? (response['priority_actions'] as List)
                .whereType<String>()
                .take(3)
                .join(' • ')
          : '';
      final opportunities = response['resource_opportunities'] is List
          ? (response['resource_opportunities'] as List)
                .whereType<String>()
                .take(3)
                .join(' • ')
          : '';
      setState(() {
        _isProfileAiThinking = false;
        _profileAiAnswer = [
          assistantMessage,
          if (priorities.isNotEmpty) 'Priority actions: $priorities',
          if (opportunities.isNotEmpty)
            'Resource opportunities: $opportunities',
        ].where((part) => part.isNotEmpty).join('\n');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProfileAiThinking = false;
        _profileAiAnswer =
            'The Profile AI assistant is unavailable. Configure and deploy the Supabase ai-chat function before using this feature.';
      });
      debugPrint('Profile AI review failed: $error');
    }
  }

  void _cancelEditing() {
    final profile = ref.read(appStateProvider).profile;
    _business.text = profile.businessName;
    _sector.text = profile.sector;
    setState(() => _editing = false);
  }

  Future<void> _saveProfile(
    String originalBusinessName,
    bool hasListings,
  ) async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    final businessName = _business.text.trim();
    final sector = _sector.text.trim();
    IndustrySector? selectedSector;
    for (final candidate in _industrySectors) {
      if (candidate.name == sector) {
        selectedSector = candidate;
        break;
      }
    }

    try {
      await ref
          .read(appStateProvider.notifier)
          .updateProfile(
            businessName: businessName,
            sector: sector,
            msicCode: selectedSector?.code,
            msicDescription: selectedSector?.name,
          );
      if (!mounted) return;
      setState(() => _editing = false);

      final message = hasListings && businessName != originalBusinessName
          ? 'Profile saved. Existing listings were updated with the new business name.'
          : 'Profile saved to your workspace.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile could not be saved. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showAddListing(BuildContext context) async {
    final material = TextEditingController();
    final quantity = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();
    final askingPricePerKg = TextEditingController();
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
                  const Text(
                    'This listing will be saved to your Supabase workspace and shown in ReSource Marketplace.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Listing type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'supply',
                        child: Text('I can supply'),
                      ),
                      DropdownMenuItem(
                        value: 'demand',
                        child: Text('I need to buy'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: material,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Material or by-product',
                    ),
                    validator: (value) => validateRequiredText(
                      value,
                      label: 'a material or by-product',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Quantity ($unit)',
                          ),
                          validator: _positiveQuantity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(
                              value: 'tonnes',
                              child: Text('tonnes'),
                            ),
                            DropdownMenuItem(
                              value: 'pieces',
                              child: Text('pieces'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => unit = value ?? unit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: askingPricePerKg,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Asking price per kg (optional)',
                    ),
                    validator: _nonNegativePrice,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: location,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: (value) => validateRequiredText(
                      value,
                      label: 'a location',
                      maxLength: 160,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText:
                          'Material condition or collection notes (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
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
                    askingPricePerKg: double.tryParse(
                      askingPricePerKg.text.trim(),
                    ),
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
    askingPricePerKg.dispose();

    if (draft == null || !mounted) return;
    try {
      await ref
          .read(appStateProvider.notifier)
          .addListing(
            type: draft.type,
            material: draft.material,
            quantity: draft.quantity,
            unit: draft.unit,
            askingPricePerKg: draft.askingPricePerKg,
            location: draft.location,
            description: draft.description,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing added to ReSource Marketplace.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Listing could not be published. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showEditListing(Listing listing) async {
    final material = TextEditingController(text: listing.material);
    final quantity = TextEditingController(text: listing.quantity.toString());
    final location = TextEditingController(text: listing.location);
    final description = TextEditingController(text: listing.description);
    final askingPricePerKg = TextEditingController(
      text: listing.askingPricePerKg?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var type = listing.type == 'demand' ? 'demand' : 'supply';
    var unit = ['kg', 'tonnes', 'pieces'].contains(listing.unit)
        ? listing.unit
        : 'kg';

    final draft = await showDialog<_ListingDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit resource listing'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Listing type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'supply',
                        child: Text('I can supply'),
                      ),
                      DropdownMenuItem(
                        value: 'demand',
                        child: Text('I need to buy'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: material,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Material or by-product',
                    ),
                    validator: (value) => validateRequiredText(
                      value,
                      label: 'a material or by-product',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Quantity ($unit)',
                          ),
                          validator: _positiveQuantity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(
                              value: 'tonnes',
                              child: Text('tonnes'),
                            ),
                            DropdownMenuItem(
                              value: 'pieces',
                              child: Text('pieces'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => unit = value ?? unit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: askingPricePerKg,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Asking price per kg (optional)',
                    ),
                    validator: _nonNegativePrice,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: location,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: (value) => validateRequiredText(
                      value,
                      label: 'a location',
                      maxLength: 160,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText:
                          'Material condition or collection notes (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
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
                    askingPricePerKg: double.tryParse(
                      askingPricePerKg.text.trim(),
                    ),
                    location: location.text.trim(),
                    description: description.text.trim(),
                  ),
                );
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    material.dispose();
    quantity.dispose();
    location.dispose();
    description.dispose();
    askingPricePerKg.dispose();

    if (draft == null || !mounted) return;
    try {
      await ref
          .read(appStateProvider.notifier)
          .updateListing(
            id: listing.id,
            type: draft.type,
            material: draft.material,
            quantity: draft.quantity,
            unit: draft.unit,
            askingPricePerKg: draft.askingPricePerKg,
            location: draft.location,
            description: draft.description,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing updated in ReSource Marketplace.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Listing could not be updated. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveListing(Listing listing) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Text(
          '${listing.material} will be removed from your Supabase workspace and no longer appear in ReSource Marketplace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep listing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove listing'),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;
    try {
      await ref.read(appStateProvider.notifier).removeListing(listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing removed from your Supabase workspace.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Listing could not be removed. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  String? _positiveQuantity(String? value) =>
      validatePositiveNumber(value, label: 'quantity');

  String? _nonNegativePrice(String? value) =>
      validateNonNegativeNumber(value, label: 'price');
}

class _ListingDraft {
  const _ListingDraft({
    required this.type,
    required this.material,
    required this.quantity,
    required this.unit,
    this.askingPricePerKg,
    required this.location,
    required this.description,
  });

  final String type;
  final String material;
  final double quantity;
  final String unit;
  final double? askingPricePerKg;
  final String location;
  final String description;
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.hasIdentity,
    required this.hasListings,
    required this.onAction,
  });

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
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFILE READINESS $complete / 2',
            style: AppTheme.eyebrowStyle.copyWith(
              color: AppColors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          if (complete < 2) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.white),
              ),
              icon: Icon(
                hasIdentity ? Icons.add_box_outlined : Icons.edit_outlined,
                size: 18,
              ),
              label: Text(hasIdentity ? 'Add listing' : 'Complete profile'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEditor extends StatelessWidget {
  const _ProfileEditor({
    required this.formKey,
    required this.business,
    required this.sector,
    required this.sectors,
    required this.isLoadingSectors,
    required this.onRefreshSectors,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController business;
  final TextEditingController sector;
  final List<IndustrySector> sectors;
  final bool isLoadingSectors;
  final VoidCallback onRefreshSectors;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: business,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Business name'),
            validator: (value) =>
                validateRequiredText(value, label: 'a business name'),
          ),
          const SizedBox(height: 12),
          if (isLoadingSectors)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (sectors.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: sectors.any((item) => item.name == sector.text)
                  ? sector.text
                  : null,
              decoration: InputDecoration(
                labelText: 'Industry sector',
                helperText: 'Official DOSM MSIC sector catalogue',
                suffixIcon: IconButton(
                  onPressed: onRefreshSectors,
                  tooltip: 'Refresh industry sectors',
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ),
              items: sectors
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.name,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) sector.text = value;
              },
              validator: (value) =>
                  validateRequiredText(value, label: 'an industry sector'),
            )
          else
            TextFormField(
              controller: sector,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Industry sector',
                helperText:
                    'MSIC catalogue unavailable; enter your sector manually.',
              ),
              validator: (value) =>
                  validateRequiredText(value, label: 'an industry sector'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Save profile'),
                ),
              ),
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
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 14)),
        ),
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
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.green,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'No marketplace listings yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Publish a supply or demand listing to make material opportunities visible in ReSource Marketplace.',
              style: TextStyle(color: AppColors.slate, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAddListing,
              icon: const Icon(Icons.add),
              label: const Text('Add first listing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.listing,
    required this.onEdit,
    required this.onDelete,
  });

  final Listing listing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isSupply = listing.type == 'supply';
    final color = isSupply ? AppColors.green : AppColors.rust;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Icon(
          isSupply ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
        ),
        title: Text(
          listing.material,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${listing.quantity.toStringAsFixed(0)} ${listing.unit} · ${listing.location}\n${isSupply ? 'Supply listing' : 'Demand listing'}${listing.askingPricePerKg == null ? '' : ' · RM ${listing.askingPricePerKg!.toStringAsFixed(2)}/kg'}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Listing actions',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit listing')),
            PopupMenuItem(value: 'delete', child: Text('Remove listing')),
          ],
        ),
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
    leading: Icon(
      complete ? Icons.check_circle : Icons.radio_button_unchecked,
      color: complete ? AppColors.green : AppColors.slate,
      size: 20,
    ),
    title: Text(label),
    trailing: Text(
      complete ? 'DONE' : 'NEXT',
      style: AppTheme.eyebrowStyle.copyWith(
        color: complete ? AppColors.green : AppColors.slate,
      ),
    ),
  );
}

class _ProfileAiAdvisor extends StatelessWidget {
  const _ProfileAiAdvisor({
    required this.controller,
    required this.answer,
    required this.isThinking,
    required this.onAsk,
  });

  final TextEditingController controller;
  final String? answer;
  final bool isThinking;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppColors.navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI PROFILE ADVISOR',
                    style: AppTheme.eyebrowStyle,
                  ),
                ),
                if (isThinking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Ask how your sector, skills, or material activity could shape your next IndustryHub action.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onAsk(),
              decoration: const InputDecoration(
                hintText:
                    'e.g. What skills should my aluminium business build next?',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isThinking ? null : onAsk,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(isThinking ? 'Reviewing…' : 'Ask Profile Advisor'),
              ),
            ),
            if (answer != null && answer!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.chalk,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  answer!,
                  style: const TextStyle(color: AppColors.ink, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
