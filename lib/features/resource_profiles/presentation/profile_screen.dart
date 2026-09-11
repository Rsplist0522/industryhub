



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../../../core/validators.dart';
import '../data/msic_repository.dart';


const List<String> _suggestedMaterials = [
  'Sawdust',
  'Wood offcuts',
  'Scrap metal',
  'Aluminium offcuts',
  'Plastic scraps',
  'Cardboard',
  'Used pallets',
  'Textile offcuts',
];

const List<String> _integerUnits = ['pieces', 'bags', 'boxes', 'pallets', 'drums', 'rolls', 'sheets', 'bundles'];
const List<String> _allUnits = [
  'g',
  'kg',
  'tonnes',
  'L',
  'm³',
  'pieces',
  'bags',
  'boxes',
  'pallets',
  'drums',
  'rolls',
  'sheets',
  'bundles',
];

String? _materialValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter a material or by-product.';
  if (text.length < 2) return 'Material name must be at least 2 characters.';
  if (text.length > 120) return 'Material name cannot exceed 120 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(text)) return 'Enter a valid material or by-product name.';
  return null;
}

String? _quantityValidator(String? value, String unit) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter a quantity.';
  final num? parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite) return 'Enter a valid number.';
  if (parsed <= 0) return 'Quantity must be greater than 0.';
  if (_integerUnits.contains(unit)) {
    if (parsed % 1 != 0) return 'Use a whole number for $unit.';
  }
  return null;
}

String? _priceValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final num? parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite) return 'Enter a valid price.';
  if (parsed < 0) return 'Price must be zero or greater.';
  return null;
}

String? _cityValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > 80) return 'City/District cannot exceed 80 characters.';

  return null;
}

const List<String> _malaysiaStates = [
  'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan', 'Pahang', 'Perak', 'Perlis', 'Pulau Pinang', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu', 'Kuala Lumpur', 'Labuan', 'Putrajaya'
];

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
  bool _isRefreshing = false;
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

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await Future.wait<void>([
        ref.read(appStateProvider.notifier).refreshSupabaseData(),
        _loadIndustrySectors(),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
        .where((item) => item.ownerId == state.userId)
        .toList();
    final hasIdentity =
        profile.businessName.trim().isNotEmpty &&
        profile.sector.trim().isNotEmpty;
    final hasListings = ownListings.isNotEmpty;
    var emailVerified = false;
    try {
      emailVerified =
          Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
    } catch (_) {

    }

    return AppShell(
      title: 'My Profile',
      showBack: true,
      actions: [
        _isRefreshing
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Refresh profile',
                onPressed: _refreshProfile,
                icon: const Icon(Icons.refresh_outlined),
              ),
      ],
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
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
                          profile.businessName.trim().isEmpty
                              ? 'Business profile'
                              : profile.businessName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      StatusChip(
                        label: hasIdentity
                            ? 'PROFILE READY'
                            : 'PROFILE INCOMPLETE',
                        color: hasIdentity ? AppColors.green : AppColors.rust,
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
                    _ProfileLine(
                      label: 'Email verified',
                      value: emailVerified ? 'Yes' : 'No',
                    ),
                    _ProfileLine(
                      label: 'Business verified',
                      value: profile.verified
                          ? 'Yes — reviewed by IndustryHub'
                          : 'No — pending independent review',
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
          _ChecklistRow(
            label: 'Profile ready for review',
            complete: hasIdentity,
          ),
          _ChecklistRow(label: 'Email verified', complete: emailVerified),
          _ChecklistRow(
            label: 'Business independently verified',
            complete: profile.verified,
          ),
          _ChecklistRow(
            label: 'First marketplace listing',
            complete: hasListings,
          ),
          const SizedBox(height: 8),
          const Text(
            'Email verification confirms control of the sign-in address. Business verification is a separate IndustryHub review and cannot be granted by editing this profile.',
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
        _profileAiAnswer = 'Profile AI unavailable. ${describeAiError(error)}';
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
            clearMsic:
                selectedSector == null &&
                sector != ref.read(appStateProvider).profile.sector,
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
    final profileReady = ref
        .read(appStateProvider)
        .profile
        .hasRequiredProfileIdentity;
    if (!profileReady) {
      _startEditing();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete your business name and industry sector before publishing a listing.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final material = TextEditingController();
    final quantity = TextEditingController();
    final city = TextEditingController();
    final description = TextEditingController();
    final askingPricePerKg = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var type = 'supply';
    var unit = 'kg';
    String selectedState = _malaysiaStates.first;


        final materialFocus = FocusNode();
        final quantityFocus = FocusNode();
        final priceFocus = FocusNode();
        final cityFocus = FocusNode();
        final descriptionFocus = FocusNode();

        var touchedMaterial = false;
        var touchedQuantity = false;
        var touchedPrice = false;
        var touchedCity = false;
        var touchedDescription = false;


        var materialChanged = false;
        var quantityChanged = false;
        var priceChanged = false;
        var cityChanged = false;
        var descriptionChanged = false;


        var quantityListenerAttached = false;
        var priceListenerAttached = false;
        var cityListenerAttached = false;
        var descriptionListenerAttached = false;
        var materialListenerAttached = false;

        final draft = await showDialog<_ListingDraft>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Add resource listing'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.disabled,
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
                            onChanged: (value) => setDialogState(() => type = value ?? type),
                          ),
                          const SizedBox(height: 12),


                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final input = textEditingValue.text.trim();
                              if (input.isEmpty) return const Iterable<String>.empty();
                              return _suggestedMaterials.where((s) => s.toLowerCase().contains(input.toLowerCase()));
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              if (controller.text != material.text) {
                                controller.text = material.text;
                                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                              }
                              if (!materialListenerAttached) {
                                controller.addListener(() {
                                  if (!materialChanged && controller.text != material.text) {
                                    materialChanged = true;
                                  }
                                  material.text = controller.text;
                                });

                                materialFocus.addListener(() {
                                  if (!materialFocus.hasFocus &&
                                      _materialValidator(material.text) != null) {
                                    setDialogState(() => touchedMaterial = true);
                                  }
                                });
                                materialListenerAttached = true;
                              }
                              return TextFormField(
                                controller: controller,
                                focusNode: materialFocus,
                                maxLength: 120,
                                decoration: InputDecoration(
                                  labelText: 'Material or by-product',
                                  errorMaxLines: 2,
                                  errorText: (touchedMaterial && materialChanged) ? _materialValidator(material.text) : null,
                                ),
                              );
                            },
                            onSelected: (selection) => material.text = selection,
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {

                                    if (!quantityListenerAttached) {
                                      quantityFocus.addListener(() {
                                        if (!quantityFocus.hasFocus) {
                                          if (_quantityValidator(quantity.text, unit) != null) setDialogState(() => touchedQuantity = true);
                                        }
                                      });
                                      quantityListenerAttached = true;
                                    }
                                    return TextFormField(
                                      controller: quantity,
                                      focusNode: quantityFocus,
                                      onChanged: (v) {
                                        quantityChanged = true;
                                        final err = _quantityValidator(v, unit);
                                        setDialogState(() => touchedQuantity = err != null);
                                      },
                                      keyboardType: TextInputType.numberWithOptions(decimal: !_integerUnits.contains(unit)),
                                      decoration: InputDecoration(
                                        labelText: 'Quantity ($unit)',
                                        errorMaxLines: 2,
                                        errorText: (touchedQuantity && quantityChanged) ? _quantityValidator(quantity.text, unit) : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: unit,
                                  decoration: const InputDecoration(labelText: 'Unit', errorMaxLines: 2),
                                  items: _allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (value) => setDialogState(() => unit = value ?? unit),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              if (!priceListenerAttached) {
                                priceFocus.addListener(() {
                                  if (!priceFocus.hasFocus) {
                                    if (_priceValidator(askingPricePerKg.text) != null) setDialogState(() => touchedPrice = true);
                                  }
                                });
                                priceListenerAttached = true;
                              }
                              return TextFormField(
                                controller: askingPricePerKg,
                                focusNode: priceFocus,
                                onChanged: (v) {
                                  priceChanged = true;
                                  final err = _priceValidator(v);
                                  setDialogState(() => touchedPrice = err != null);
                                },
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: type == 'supply' ? 'Selling price per kg (optional)' : 'Preferred buying price per kg (optional)',
                                  errorMaxLines: 2,
                                  errorText: (touchedPrice && priceChanged) ? _priceValidator(askingPricePerKg.text) : null,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            initialValue: selectedState,
                            decoration: const InputDecoration(labelText: 'State / Federal Territory *'),
                            items: _malaysiaStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (value) => setDialogState(() => selectedState = value ?? selectedState),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              if (!cityListenerAttached) {
                                cityFocus.addListener(() {
                                  if (!cityFocus.hasFocus) {
                                    if (_cityValidator(city.text) != null) setDialogState(() => touchedCity = true);
                                  }
                                });
                                cityListenerAttached = true;
                              }
                              return TextFormField(
                                controller: city,
                                focusNode: cityFocus,
                                onChanged: (v) {
                                  cityChanged = true;
                                  final err = _cityValidator(v);
                                  setDialogState(() => touchedCity = err != null);
                                },
                                decoration: InputDecoration(
                                  labelText: 'City / District (optional)',
                                                                  errorMaxLines: 3,
                                                                  helperMaxLines: 3,
                                  errorText: (touchedCity && cityChanged) ? _cityValidator(city.text) : null,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              if (!descriptionListenerAttached) {
                                descriptionFocus.addListener(() {
                                  if (!descriptionFocus.hasFocus) {
                                    if (description.text.trim().length > 240) setDialogState(() => touchedDescription = true);
                                  }
                                });
                                descriptionListenerAttached = true;
                              }
                              return TextFormField(
                                controller: description,
                                focusNode: descriptionFocus,
                                onChanged: (v) {
                                  descriptionChanged = true;
                                  final err = v.trim().length > 240 ? 'Description cannot exceed 240 characters.' : null;
                                  setDialogState(() => touchedDescription = err != null);
                                },
                                maxLines: 3,
                                maxLength: 240,
                                decoration: InputDecoration(
                                  labelText: 'Description / condition & collection notes (optional)',
                                  alignLabelWithHint: true,
                                  helperText: 'Example: clean/dry condition, contamination, packaging or collection requirements.',
                                                                  helperMaxLines: 3,
                                                                  errorMaxLines: 3,
                                  errorText: (touchedDescription && descriptionChanged && description.text.trim().length > 240) ? 'Description cannot exceed 240 characters.' : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {

                    final materialText = material.text.trim();
                    final qtyText = quantity.text.trim();
                    setDialogState(() {
                      touchedMaterial = true;
                      touchedQuantity = true;
                      touchedPrice = true;
                      touchedCity = true;
                      touchedDescription = true;
                    });

                    if (materialText.isEmpty || _materialValidator(materialText) != null || _quantityValidator(qtyText, unit) != null || _priceValidator(askingPricePerKg.text) != null) {

                      if (_materialValidator(materialText) != null) {
                        materialFocus.requestFocus();
                      } else if (_quantityValidator(qtyText, unit) != null) {
                        quantityFocus.requestFocus();
                      } else if (_priceValidator(askingPricePerKg.text) != null) {
                        priceFocus.requestFocus();
                      }
                      return;
                    }

                    final qtyParsed = double.tryParse(qtyText) ?? 0.0;
                    final finalQty = _integerUnits.contains(unit) ? qtyParsed.floorToDouble() : qtyParsed;
                    final price = double.tryParse(askingPricePerKg.text.trim());
                    final cityText = city.text.trim();
                    final locationStr = cityText.isEmpty ? selectedState : '$cityText, $selectedState';

                    Navigator.pop(
                      dialogContext,
                      _ListingDraft(
                        type: type,
                        material: materialText,
                        quantity: finalQty,
                        unit: unit,
                        askingPricePerKg: price,
                        location: locationStr,
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




    await Future<void>.delayed(const Duration(milliseconds: 300));
    material.dispose();
    quantity.dispose();


    try {
      city.dispose();
    } catch (_) {}
    description.dispose();
    askingPricePerKg.dispose();

    if (draft == null || !mounted) return;


    final stateNow = ref.read(appStateProvider);
    final userId = stateNow.userId;
    final normalized = draft.material.trim().toLowerCase();
    final ownMatches = stateNow.listings.where((l) => l.ownerId == userId && l.material.trim().toLowerCase() == normalized).toList();

    if (ownMatches.isNotEmpty) {
      if (!context.mounted) return;
      final updateAll = ownMatches.length > 1;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Existing listing detected'),
          content: Text(updateAll
              ? 'You already have ${ownMatches.length} listings for "${draft.material}". Update all existing listing(s) with these details or cancel?'
              : 'You already have a listing for "${draft.material}". Update the existing listing with these details or cancel?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, updateAll ? 'update_all' : 'update'),
              child: const Text('Update existing'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;

      try {
        for (final existing in ownMatches) {
          await ref.read(appStateProvider.notifier).updateListing(
                id: existing.id,
                type: draft.type,
                material: draft.material,
                quantity: draft.quantity,
                unit: draft.unit,
                location: draft.location,
                description: draft.description,
                askingPricePerKg: draft.askingPricePerKg,
              );
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updateAll ? 'Updated ${ownMatches.length} existing listings.' : 'Existing listing updated.')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update existing listing(s). Please check your connection and try again.'),
          ),
        );
      }

      return;
    }

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
    final city = TextEditingController();
    final description = TextEditingController(text: listing.description);
    final askingPricePerKg = TextEditingController(
      text: listing.askingPricePerKg?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var type = listing.type == 'demand' ? 'demand' : 'supply';
    var unit = _allUnits.contains(listing.unit) ? listing.unit : 'kg';


    String selectedState = _malaysiaStates.first;
    if (listing.location.trim().isNotEmpty) {
      final parts = listing.location.split(',');
      if (parts.length >= 2) {
        final left = parts.sublist(0, parts.length - 1).join(',').trim();
        final right = parts.last.trim();
        if (_malaysiaStates.contains(right)) {
          selectedState = right;
          city.text = left;
        } else if (_malaysiaStates.contains(listing.location.trim())) {
          selectedState = listing.location.trim();
        }
      } else {
        if (_malaysiaStates.contains(listing.location.trim())) {
          selectedState = listing.location.trim();
        }
      }
    }

    final materialFocusEdit = FocusNode();
    final quantityFocusEdit = FocusNode();
    final priceFocusEdit = FocusNode();
    final cityFocusEdit = FocusNode();
    final descriptionFocusEdit = FocusNode();

    var touchedMaterialEdit = false;
    var touchedQuantityEdit = false;
    var touchedPriceEdit = false;
    var touchedCityEdit = false;
    var touchedDescriptionEdit = false;

    var materialChangedEdit = false;
    var quantityChangedEdit = false;

    var materialListenerAttachedEdit = false;
    var quantityListenerAttachedEdit = false;

    final draft = await showDialog<_ListingDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit resource listing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.disabled,
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
                        onChanged: (value) => setDialogState(() => type = value ?? type),
                      ),
                      const SizedBox(height: 12),

                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final input = textEditingValue.text.trim();
                          if (input.isEmpty) return const Iterable<String>.empty();
                          return _suggestedMaterials.where((s) => s.toLowerCase().contains(input.toLowerCase()));
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != material.text) {
                            controller.text = material.text;
                            controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                          }
                          controller.addListener(() {
                           if (!materialChangedEdit && controller.text != (material.text)) materialChangedEdit = true;
                           material.text = controller.text;
                           if (materialChangedEdit && _materialValidator(controller.text) != null) setDialogState(() => touchedMaterialEdit = true);
                          });
                          if (!materialListenerAttachedEdit) {
                           materialFocusEdit.addListener(() {
                             if (!materialFocusEdit.hasFocus) {
                               if (_materialValidator(material.text) != null) setDialogState(() => touchedMaterialEdit = true);
                             }
                           });
                           materialListenerAttachedEdit = true;
                          }
                          return TextFormField(
                           controller: controller,
                           focusNode: materialFocusEdit,
                           maxLength: 120,
                           decoration: InputDecoration(
                             labelText: 'Material or by-product',
                             errorMaxLines: 2,
                             errorText: (touchedMaterialEdit && materialChangedEdit) ? _materialValidator(material.text) : null,
                           ),
                          );
                        },
                        onSelected: (selection) => material.text = selection,
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                if (!quantityListenerAttachedEdit) {
                                  quantityFocusEdit.addListener(() {
                                    if (!quantityFocusEdit.hasFocus) {
                                      if (_quantityValidator(quantity.text, unit) != null) setDialogState(() => touchedQuantityEdit = true);
                                    }
                                  });
                                  quantityListenerAttachedEdit = true;
                                }
                                return TextFormField(
                                  controller: quantity,
                                  focusNode: quantityFocusEdit,
                                  onChanged: (v) {
                                    quantityChangedEdit = true;
                                    final err = _quantityValidator(v, unit);
                                    setDialogState(() => touchedQuantityEdit = err != null);
                                  },
                                  keyboardType: TextInputType.numberWithOptions(decimal: !_integerUnits.contains(unit)),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity ($unit)',
                                    errorText: (touchedQuantityEdit && quantityChangedEdit) ? _quantityValidator(quantity.text, unit) : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              items: _allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (value) => setDialogState(() => unit = value ?? unit),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: askingPricePerKg,
                        focusNode: priceFocusEdit,
                        onChanged: (_) => setDialogState(() => touchedPriceEdit = true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: type == 'supply' ? 'Selling price per kg (optional)' : 'Preferred buying price per kg (optional)',
                          errorText: touchedPriceEdit ? _priceValidator(askingPricePerKg.text) : null,
                        ),
                      ),

                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedState,
                        decoration: const InputDecoration(labelText: 'State / Federal Territory *'),
                        items: _malaysiaStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (value) => setDialogState(() => selectedState = value ?? selectedState),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: city,
                        focusNode: cityFocusEdit,
                        onChanged: (_) => setDialogState(() => touchedCityEdit = true),
                        decoration: InputDecoration(
                          labelText: 'City / District (optional)',
                          errorMaxLines: 3,
                          helperMaxLines: 3,
                          errorText: touchedCityEdit ? _cityValidator(city.text) : null,
                        ),
                      ),

                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        focusNode: descriptionFocusEdit,
                        onChanged: (_) => setDialogState(() => touchedDescriptionEdit = true),
                        maxLines: 3,
                        maxLength: 240,
                        decoration: InputDecoration(
                          labelText: 'Description / condition & collection notes (optional)',
                          alignLabelWithHint: true,
                          helperText: 'Example: clean/dry condition, contamination, packaging or collection requirements.',
                          helperMaxLines: 3,
                          errorMaxLines: 3,
                          errorText: (touchedDescriptionEdit && description.text.trim().length > 240) ? 'Description cannot exceed 240 characters.' : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {

                setDialogState(() {
                  touchedMaterialEdit = true;
                  touchedQuantityEdit = true;
                  touchedPriceEdit = true;
                  touchedCityEdit = true;
                  touchedDescriptionEdit = true;
                });

                final materialText = material.text.trim();
                final qtyText = quantity.text.trim();

                if (_materialValidator(materialText) != null || _quantityValidator(qtyText, unit) != null || _priceValidator(askingPricePerKg.text) != null) {
                  if (_materialValidator(materialText) != null) {
                    materialFocusEdit.requestFocus();
                  } else if (_quantityValidator(qtyText, unit) != null) {
                    quantityFocusEdit.requestFocus();
                  } else if (_priceValidator(askingPricePerKg.text) != null) {
                    priceFocusEdit.requestFocus();
                  }
                  return;
                }

                final qtyParsed = double.tryParse(qtyText) ?? 0.0;
                final finalQty = _integerUnits.contains(unit) ? qtyParsed.floorToDouble() : qtyParsed;
                final price = double.tryParse(askingPricePerKg.text.trim());
                final cityText = city.text.trim();
                final locationStr = cityText.isEmpty ? selectedState : '$cityText, $selectedState';

                Navigator.pop(
                  dialogContext,
                  _ListingDraft(
                    type: type,
                    material: materialText,
                    quantity: finalQty,
                    unit: unit,
                    askingPricePerKg: price,
                    location: locationStr,
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
    city.dispose();
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
          '${listing.material} will be removed and no longer appear in ReSource Marketplace.',
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
          content: Text('Listing removed from ReSource Marketplace.'),
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
              isExpanded: true,
              itemHeight: null,
              menuMaxHeight: (MediaQuery.sizeOf(context).height * 0.6)
                  .clamp(280.0, 520.0)
                  .toDouble(),
              decoration: InputDecoration(
                labelText: 'Industry sector',
                helperText: 'Official DOSM MSIC sector catalogue',
                suffixIcon: IconButton(
                  onPressed: onRefreshSectors,
                  tooltip: 'Refresh industry sectors',
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ),
              selectedItemBuilder: (context) => sectors
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              items: sectors
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.name,
                      child: Text(
                        item.name,
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) sector.text = value;
              },
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Select an industry sector.'
                  : null,
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
          '${listing.quantityLabel} ${listing.unit} · ${listing.location}\n${isSupply ? 'Supply listing' : 'Demand listing'}${listing.askingPricePerKg == null ? '' : ' · RM ${listing.askingPricePerKg!.toStringAsFixed(2)}/kg'}',
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
