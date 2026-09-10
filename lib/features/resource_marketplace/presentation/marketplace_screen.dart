import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';
import '../../../core/services.dart';
import '../data/deal_request_repository.dart';
import '../data/industrial_context_repository.dart';
import '../presentation/marketplace_industry_context_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key, this.onHome});

  final VoidCallback? onHome;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _SavedMarketplaceSearch {
  const _SavedMarketplaceSearch({
    required this.query,
    required this.type,
    required this.material,
    required this.location,
    required this.verifiedOnly,
    required this.minimumQuantity,
  });

  final String query;
  final String type;
  final String? material;
  final String? location;
  final bool verifiedOnly;
  final double minimumQuantity;
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  final _dealRequestRepository = DealRequestRepository();
  final _industrialContextRepository = IndustrialContextRepository();
  final _transactions = <DealRequestRecord>[];
  final _incomingRequests = <DealRequestRecord>[];
  final _requestedListingKeys = <String>{};
  final _knownTerminalRequestIds = <String>{};
  final _marketplaceAiInput = TextEditingController();
  final _aiService = const AiService();
  StreamSubscription<List<DealRequestRecord>>? _outgoingSubscription;
  StreamSubscription<List<DealRequestRecord>>? _incomingSubscription;

  String _filter = 'all';
  String _sort = 'default';
  String? _material;
  String? _location;
  bool _verifiedOnly = false;
  double _minimumQuantity = 0;
  _SavedMarketplaceSearch? _savedSearch;
  bool _isLoadingHistory = true;
  bool _isLoadingIncoming = true;
  bool _isSendingRequest = false;
  bool _isRespondingToRequest = false;
  String? _historyError;
  String? _incomingError;
  IndustrialContext? _industrialContext;
  bool _isLoadingIndustrialContext = true;
  String? _industrialContextError;
  String? _marketplaceAiAnswer;
  bool _isMarketplaceAiThinking = false;
  bool _isLoadingPresentationListings = false;
  String _industrialContextLocation = 'Malaysia';
  String _selectedOfficialContextState = 'Pulau Pinang';

  static const _officialContextStates = <String>[
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'W.P. Kuala Lumpur',
    'W.P. Labuan',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToRequests();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadIndustrialContext(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _marketplaceAiInput.dispose();
    _outgoingSubscription?.cancel();
    _incomingSubscription?.cancel();
    super.dispose();
  }

  // Live Supabase Realtime subscriptions replace the old "fetch once, wait
  // for a manual refresh" flow: outgoing status changes (accepted/rejected/
  // cancelled) and new incoming requests now update the screen on their own.
  void _subscribeToRequests() {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
      _isLoadingIncoming = true;
      _incomingError = null;
    });

    _outgoingSubscription?.cancel();
    _outgoingSubscription = _dealRequestRepository.watchOutgoingRequests().listen(
      (requests) {
        if (!mounted) return;
        final terminalIds = requests
            .where(
              (request) =>
                  request.status == 'ACCEPTED' || request.status == 'REJECTED',
            )
            .map((request) => request.id)
            .toSet();
        final hasNewTerminalRequest =
            terminalIds.difference(_knownTerminalRequestIds).isNotEmpty;
        _knownTerminalRequestIds
          ..clear()
          ..addAll(terminalIds);
        setState(() {
          _transactions
            ..clear()
            ..addAll(requests);
          _requestedListingKeys
            ..clear()
            ..addAll(
              requests
                  .where((request) => request.status == 'REQUEST SENT')
                  .map((request) => request.listingId)
                  .where((listingId) => listingId.isNotEmpty),
            );
          _isLoadingHistory = false;
          _historyError = null;
        });
        if (hasNewTerminalRequest) {
          Future<void>.microtask(
            () => ref.read(appStateProvider.notifier).refreshSupabaseData(),
          );
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingHistory = false;
          _historyError = 'Supabase request history could not be loaded.';
        });
        debugPrint('Marketplace outgoing stream failed: $error');
      },
    );

    _incomingSubscription?.cancel();
    _incomingSubscription = _dealRequestRepository.watchIncomingRequests().listen(
      (requests) {
        if (!mounted) return;
        setState(() {
          _incomingRequests
            ..clear()
            ..addAll(requests);
          _isLoadingIncoming = false;
          _incomingError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingIncoming = false;
          _incomingError = 'Incoming requests could not be loaded.';
        });
        debugPrint('Marketplace incoming stream failed: $error');
      },
    );
  }

  int get _pendingIncomingCount => _incomingRequests
      .where((request) => request.status == 'REQUEST SENT')
      .length;

  Future<void> _respondToIncomingRequest(
    DealRequestRecord request, {
    required bool accept,
  }) async {
    if (_isRespondingToRequest) return;
    var rejectionReason = '';
    if (!accept) {
      final reason = await _askRejectionReason();
      if (reason == null || !mounted) return;
      rejectionReason = reason;
    }
    setState(() => _isRespondingToRequest = true);
    try {
      await _dealRequestRepository.respondToRequest(
        request.id,
        accept: accept,
        reason: rejectionReason,
      );
      await ref.read(appStateProvider.notifier).refreshSupabaseData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Request from ${request.requesterName} accepted. The listing is now unavailable.'
                : 'Request from ${request.requesterName} declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        StateError stateError => stateError.message.toString(),
        PostgrestException postgrestError => postgrestError.message,
        _ => '$error',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not ${accept ? 'accept' : 'decline'} this request: $message',
          ),
        ),
      );
      debugPrint('Marketplace respond to request failed: $error');
    } finally {
      if (mounted) setState(() => _isRespondingToRequest = false);
    }
  }

  Future<String?> _askRejectionReason() async {
    const reasons = <String>[
      'Quantity no longer available',
      'Price or terms not suitable',
      'Material requirements do not match',
      'Accepted another business',
      'Unable to fulfil at this time',
      'Other',
    ];

    final noteController = TextEditingController();
    String? selectedReason;
    String? validationMessage;

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Decline this request?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a reason so the requester receives a useful explanation.',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Decline reason *',
                    errorText: validationMessage,
                  ),
                  items: reasons
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(
                            reason,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    selectedReason = value;
                    validationMessage = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Additional note (optional)',
                    hintText: 'Add a short explanation if helpful.',
                    alignLabelWithHint: true,
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
                if (selectedReason == null) {
                  setDialogState(() {
                    validationMessage = 'Choose a decline reason.';
                  });
                  return;
                }

                final note = noteController.text.trim();
                final storedReason = note.isEmpty
                    ? selectedReason!
                    : '${selectedReason!}\nAdditional note: $note';
                Navigator.pop(dialogContext, storedReason);
              },
              child: const Text('Decline request'),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
    return result;
  }

  Future<void> _loadIndustrialContext({String? marketplaceLocation}) async {
    final targetLocation =
        marketplaceLocation ?? _location ?? _selectedOfficialContextState;

    setState(() {
      _isLoadingIndustrialContext = true;
      _industrialContextError = null;
      _industrialContextLocation = targetLocation;
    });

    try {
      final result = await _industrialContextRepository
          .fetchManufacturingContext(marketplaceLocation: targetLocation);
      if (!mounted) return;
      setState(() {
        _industrialContext = result;
        if (result != null && _officialContextStates.contains(result.state)) {
          _selectedOfficialContextState = result.state;
        }
        _isLoadingIndustrialContext = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingIndustrialContext = false;
        _industrialContextError =
            'Official industry data is temporarily unavailable.';
      });
      debugPrint('Marketplace industry context could not be loaded: $error');
    }
  }

  Future<void> _loadPresentationListings() async {
    if (_isLoadingPresentationListings) return;
    setState(() => _isLoadingPresentationListings = true);
    try {
      final created = await ref
          .read(appStateProvider.notifier)
          .createPresentationListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 0
                ? 'Presentation examples are already loaded.'
                : '$created clearly labelled presentation listings added to your workspace.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final details = error.toString().toLowerCase();
      final message =
          details.contains('permission') ||
              details.contains('row-level security') ||
              details.contains('42501')
          ? 'Supabase denied the listing write. Apply the latest migration, then sign out and sign back in.'
          : 'Could not load presentation listings. Check your connection and try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoadingPresentationListings = false);
    }
  }

  Future<void> _askMarketplaceAi(List<Listing> listings) async {
    if (_isMarketplaceAiThinking) return;
    final question = _marketplaceAiInput.text.trim();
    final prompt = question.isEmpty
        ? 'Which visible listing should I review first and what should I verify before contacting the business?'
        : question;
    setState(() => _isMarketplaceAiThinking = true);
    final visibleListings = listings
        .take(8)
        .map(
          (listing) => {
            'id': listing.id,
            'type': listing.type,
            'material': listing.material,
            'quantity':
                '${listing.quantityLabel} ${listing.unit}',
            'location': listing.location,
            'owner': listing.owner,
            'asking_price_per_kg': listing.askingPricePerKg,
            'verified': listing.verified,
            'description': listing.description,
          },
        )
        .toList();
    try {
      final response = await _aiService.callAI(
        'You are the ReSource Marketplace advisor for Malaysian industrial SMEs. Use only the supplied listing records and official context. Do not invent businesses, prices, availability, verification, or completed deals. Return exactly these JSON keys: assistant_message, recommended_listing_ids (array of strings), considerations (array of concise strings).',
        'User question: $prompt\nSelected search: ${_search.text.trim()}\nSelected type: $_filter\nOfficial context: ${_industrialContext == null ? 'unavailable' : '${_industrialContext!.state}, RM ${_industrialContext!.valueRmMillions.toStringAsFixed(1)} million'}\nVisible listings JSON: ${jsonEncode(visibleListings)}',
      );
      if (!mounted) return;
      final answer = response['assistant_message'] is String
          ? (response['assistant_message'] as String).trim()
          : '';
      final considerations = response['considerations'] is List
          ? (response['considerations'] as List)
                .whereType<String>()
                .take(4)
                .join(' • ')
          : '';
      setState(() {
        _isMarketplaceAiThinking = false;
        _marketplaceAiAnswer = [
          answer,
          if (considerations.isNotEmpty) 'Checks: $considerations',
          'Source: AI Marketplace advisor using the visible live records.',
        ].where((item) => item.isNotEmpty).join('\n');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isMarketplaceAiThinking = false;
        _marketplaceAiAnswer =
            'Marketplace AI unavailable. ${describeAiError(error)}';
      });
      debugPrint('Marketplace AI review failed: $error');
    }
  }

  Future<void> _refreshMarketplace() async {
    try {
      await ref.read(appStateProvider.notifier).refreshSupabaseData();

      if (!mounted) return;

      // Reconnect the live request streams so the request inbox/history is
      // refreshed together with the marketplace listings.
      _subscribeToRequests();

      await _loadIndustrialContext(
        marketplaceLocation: _location ?? _selectedOfficialContextState,
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('Marketplace pull-to-refresh failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marketplace could not be refreshed. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceListings = ref.watch(appStateProvider).listings;
    final listings = _filteredListings(sourceListings);

    return AppShell(
      title: 'ReSource Marketplace',
      showBack: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Return to Home Dashboard',
          onPressed: _goHome,
        ),
        PopupMenuButton<String>(
          tooltip: 'Sort listings',
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'default', child: Text('Default order')),
            PopupMenuItem(
              value: 'relevance',
              child: Text('Best match first'),
            ),
            PopupMenuItem(value: 'quantity', child: Text('Highest quantity')),
            PopupMenuItem(value: 'location', child: Text('Location A–Z')),
          ],
          icon: const Icon(Icons.sort_outlined),
        ),
        // Keep this in M4: it is a pending-work counter, not the global
        // unread-notification counter shown on the Home dashboard.
        IconButton(
          icon: Badge.count(
            count: _pendingIncomingCount,
            isLabelVisible: _pendingIncomingCount > 0,
            backgroundColor: AppColors.amber,
            textColor: AppColors.white,
            child: const Icon(Icons.inbox_outlined),
          ),
          tooltip: 'Pending deal requests for your listings',
          onPressed: _showIncomingRequests,
        ),
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined),
          tooltip: 'View your outgoing requests',
          onPressed: _showHistory,
        ),
        const SizedBox(width: 6),
      ],
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: RefreshIndicator(
        onRefresh: _refreshMarketplace,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
          const PageIntro(
            eyebrow: 'M4 / RESOURCE MARKETPLACE',
            title: 'Materials in motion.',
            description:
                'Discover verified industrial by-products, close local supply loops, and turn disposal into opportunity.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search material, business, or location',
              suffixIcon: IconButton(
                tooltip: 'Open marketplace filters',
                icon: Badge(
                  isLabelVisible: _hasAdvancedFilters,
                  smallSize: 8,
                  child: const Icon(Icons.tune_outlined),
                ),
                onPressed: () => _showFilters(sourceListings),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All listings',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Supply',
                  selected: _filter == 'supply',
                  color: AppColors.green,
                  onTap: () => setState(() => _filter = 'supply'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Demand',
                  selected: _filter == 'demand',
                  color: AppColors.rust,
                  onTap: () => setState(() => _filter = 'demand'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showFilters(sourceListings),
                  icon: const Icon(Icons.tune_outlined, size: 17),
                  label: const Text('More filters'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saveCurrentSearch,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                  label: const Text('Save search'),
                ),
              ],
            ),
          ),
          if (_hasAdvancedFilters) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_material != null)
                  _ActiveFilter(
                    label: _material!,
                    onClear: () => setState(() => _material = null),
                  ),
                if (_location != null)
                  _ActiveFilter(
                    label: _location!,
                    onClear: () => setState(() => _location = null),
                  ),
                if (_verifiedOnly)
                  _ActiveFilter(
                    label: 'Verified only',
                    onClear: () => setState(() => _verifiedOnly = false),
                  ),
                if (_minimumQuantity > 0)
                  _ActiveFilter(
                    label:
                        'At least ${_minimumQuantity.toStringAsFixed(0)} units',
                    onClear: () => setState(() => _minimumQuantity = 0),
                  ),
                TextButton.icon(
                  onPressed: _clearAdvancedFilters,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
          if (_savedSearch != null) ...[
            const SizedBox(height: 10),
            _SavedSearchBanner(
              onApply: _applySavedSearch,
              onClear: () => setState(() => _savedSearch = null),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('M4 / MARKETPLACE AI'),
                  const SizedBox(height: 6),
                  Text(
                    'Ask before you contact.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ask the advisor to compare the currently visible listings using only their published details.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _marketplaceAiInput,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Which listing best fits a buyer in Penang?',
                    ),
                  ),
                  if (_marketplaceAiAnswer != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.chalk,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _marketplaceAiAnswer!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isMarketplaceAiThinking
                        ? null
                        : () {
                            _askMarketplaceAi(listings);
                          },
                    icon: _isMarketplaceAiThinking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: Text(
                      _isMarketplaceAiThinking
                          ? 'Reviewing listings…'
                          : 'Ask Marketplace AI',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Visual separation between Marketplace AI and the official
          // public/regional dataset section.
          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            initialValue: _selectedOfficialContextState,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Official data region',
              helperText: 'Choose a state to view its manufacturing context.',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: _officialContextStates
                .map(
                  (state) => DropdownMenuItem(value: state, child: Text(state)),
                )
                .toList(),
            onChanged: (state) {
              if (state == null || state == _selectedOfficialContextState) {
                return;
              }
              setState(() => _selectedOfficialContextState = state);
              _loadIndustrialContext(marketplaceLocation: state);
            },
          ),
          const SizedBox(height: 12),
          MarketplaceIndustryContextCard(
            context: _industrialContext,
            selectedLocation: _industrialContextLocation,
            isLoading: _isLoadingIndustrialContext,
            errorMessage: _industrialContextError,
            onRefresh: _loadIndustrialContext,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('LIVE LISTINGS'),
              Text(
                '${listings.length} result${listings.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.slate, fontSize: 12),
              ),
            ],
          ),
          if (_hasMatchCriteria) ...[
            const SizedBox(height: 4),
            const Text(
              'Results include partial matches and are ranked by how closely they fit your active criteria.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (sourceListings.isEmpty)
            _MarketplaceEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'The exchange is waiting for its first listing.',
              description:
                  'Create a real listing from ReSource Profile, or load clearly labelled presentation examples to demonstrate M4 without pretending they are verified market records.',
              actionLabel: _isLoadingPresentationListings
                  ? 'Loading examples…'
                  : 'Load presentation examples',
              onAction: _isLoadingPresentationListings
                  ? null
                  : _loadPresentationListings,
            )
          else if (listings.isEmpty)
            _MarketplaceEmptyState(
              icon: Icons.search_off_outlined,
              title: 'No listings match the selected criteria.',
              description:
                  'No listing currently matches even one active search or filter criterion. Try changing or clearing some criteria.',
              actionLabel: 'Reset filters',
              onAction: _resetAllFilters,
            )
          else
            ...listings.map(
              (listing) => _MarketplaceCard(
                listing: listing,
                requested: _requestedListingKeys.contains(_listingKey(listing)),
                showMatchScore: _hasMatchCriteria,
                matchScore: _matchScore(listing),
                matchLabel: _matchLabel(listing),
                onTap: () => _showDetail(listing),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasAdvancedFilters =>
      _material != null ||
      _location != null ||
      _verifiedOnly ||
      _minimumQuantity > 0;

  /// A match score is only meaningful when the user has actually supplied
  /// something to match against. This prevents every unfiltered listing from
  /// showing an arbitrary baseline percentage.
  bool get _hasMatchCriteria =>
      _search.text.trim().isNotEmpty ||
      _filter != 'all' ||
      _hasAdvancedFilters;

  /// Returns marketplace listings using PARTIAL-MATCH behaviour.
  ///
  /// When no search/filter criteria are active, every listing is shown.
  /// When criteria are active, a listing stays visible as long as it matches
  /// at least one active criterion. This is intentional: the match percentage
  /// then tells the user how closely each listing fits the full set of
  /// requirements instead of hiding every imperfect alternative.
  List<Listing> _filteredListings(List<Listing> source) {
    final filtered = _hasMatchCriteria
        ? source.where((listing) => _matchScore(listing) > 0).toList()
        : List<Listing>.from(source);

    switch (_sort) {
      case 'relevance':
        if (_hasMatchCriteria) {
          filtered.sort((a, b) {
            final scoreComparison =
                _matchScore(b).compareTo(_matchScore(a));
            if (scoreComparison != 0) return scoreComparison;
            return b.quantity.compareTo(a.quantity);
          });
        }
        break;
      case 'quantity':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'location':
        filtered.sort(
          (a, b) =>
              a.location.toLowerCase().compareTo(b.location.toLowerCase()),
        );
        break;
      case 'default':
        // Once criteria are selected, ranking partial matches by score is the
        // most useful default. Without criteria, keep the original order.
        if (_hasMatchCriteria) {
          filtered.sort((a, b) {
            final scoreComparison =
                _matchScore(b).compareTo(_matchScore(a));
            if (scoreComparison != 0) return scoreComparison;
            return b.quantity.compareTo(a.quantity);
          });
        }
        break;
    }
    return filtered;
  }

  /// Calculates a transparent 0-100 match score using only criteria that
  /// the user has actively selected.
  ///
  /// Weighting:
  /// - Search text:        40 points
  /// - Material filter:    20 points
  /// - Location filter:    15 points
  /// - Supply/demand type: 10 points
  /// - Verified only:      10 points
  /// - Minimum quantity:    5 points
  ///
  /// The denominator contains only active criteria. A listing that satisfies
  /// every active criterion receives 100%. A listing that satisfies only some
  /// criteria remains visible with a lower percentage.
  int _matchScore(Listing listing) {
    if (!_hasMatchCriteria) return 0;

    final query = _search.text.trim().toLowerCase();
    var earnedPoints = 0.0;
    var possiblePoints = 0.0;

    if (query.isNotEmpty) {
      possiblePoints += 40;
      earnedPoints += _queryMatchPoints(listing, query);
    }

    if (_material != null) {
      possiblePoints += 20;
      if (listing.material == _material) {
        earnedPoints += 20;
      }
    }

    if (_location != null) {
      possiblePoints += 15;
      if (listing.location == _location) {
        earnedPoints += 15;
      }
    }

    if (_filter != 'all') {
      possiblePoints += 10;
      if (listing.type == _filter) {
        earnedPoints += 10;
      }
    }

    if (_verifiedOnly) {
      possiblePoints += 10;
      if (listing.verified) {
        earnedPoints += 10;
      }
    }

    if (_minimumQuantity > 0) {
      possiblePoints += 5;
      if (listing.quantity >= _minimumQuantity) {
        earnedPoints += 5;
      }
    }

    if (possiblePoints == 0) return 0;

    return ((earnedPoints / possiblePoints) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  /// Gives the search-text portion of the score a different strength based on
  /// where the query matched. A material match is strongest because the
  /// marketplace primarily connects material supply and demand.
  double _queryMatchPoints(Listing listing, String query) {
    final material = listing.material.toLowerCase();
    final location = listing.location.toLowerCase();
    final owner = listing.owner.toLowerCase();
    final description = listing.description.toLowerCase();

    if (material == query) return 40;
    if (material.contains(query)) return 38;
    if (location.contains(query)) return 32;
    if (owner.contains(query)) return 26;
    if (description.contains(query)) return 22;

    return 0;
  }

  /// Explains the strongest reasons behind the displayed match score so the
  /// percentage is not a black-box number.
  String _matchLabel(Listing listing) {
    if (!_hasMatchCriteria) {
      return 'No match criteria selected';
    }

    final query = _search.text.trim().toLowerCase();
    final reasons = <String>[];

    if (query.isNotEmpty) {
      final material = listing.material.toLowerCase();
      final location = listing.location.toLowerCase();
      final owner = listing.owner.toLowerCase();
      final description = listing.description.toLowerCase();

      if (material == query) {
        reasons.add('Exact material search');
      } else if (material.contains(query)) {
        reasons.add('Material search');
      } else if (location.contains(query)) {
        reasons.add('Location search');
      } else if (owner.contains(query)) {
        reasons.add('Business search');
      } else if (description.contains(query)) {
        reasons.add('Description search');
      }
    }

    if (_material != null && listing.material == _material) {
      reasons.add('Material filter');
    }

    if (_location != null && listing.location == _location) {
      reasons.add('Location filter');
    }

    if (_filter != 'all' && listing.type == _filter) {
      reasons.add(_filter == 'supply' ? 'Supply filter' : 'Demand filter');
    }

    if (_verifiedOnly && listing.verified) {
      reasons.add('Verified');
    }

    if (_minimumQuantity > 0 && listing.quantity >= _minimumQuantity) {
      reasons.add('Quantity');
    }

    if (reasons.isEmpty) {
      return 'Matches current criteria';
    }

    return reasons.take(3).join(' • ');
  }

  void _goHome() {
    if (widget.onHome != null) {
      widget.onHome!();
      return;
    }

    context.go('/home');
  }

  Future<void> _showDetail(Listing listing) async {
    final isSupply = listing.type == 'supply';
    final requested = _requestedListingKeys.contains(_listingKey(listing));
    final isOwnListing = listing.ownerId == ref.read(appStateProvider).userId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.material,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    StatusChip(
                      label: isSupply ? 'SUPPLY' : 'DEMAND',
                      color: isSupply ? AppColors.green : AppColors.rust,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailLine(label: 'Business', value: listing.owner),
                _DetailLine(
                  label: 'Quantity',
                  value:
                      '${listing.quantityLabel} ${listing.unit}',
                ),
                if (listing.askingPricePerKg != null)
                  _DetailLine(
                    label: 'Asking price',
                    value:
                        'RM ${listing.askingPricePerKg!.toStringAsFixed(2)}/kg',
                  ),
                _DetailLine(label: 'Location', value: listing.location),
                _DetailLine(label: 'Description', value: listing.description),
                if (listing.verified)
                  const _DetailLine(
                    label: 'Trust status',
                    value: 'Verified ReSource business',
                  ),
                if (_hasMatchCriteria) ...[
                  _DetailLine(
                    label: 'Match score',
                    value: '${_matchScore(listing)}% · ${_matchLabel(listing)}',
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Weighted prototype match score based on the active search and filter criteria. Partial matches remain visible so alternatives can be compared. It is not a quality, trust, or market-value rating.',
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isOwnListing)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Your listing'),
                    ),
                  )
                else if (requested)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Request already sent'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSendingRequest
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 300),
                              );
                              if (!mounted) return;
                              await _showDealRequestDialog(listing);
                            },
                      icon: const Icon(Icons.handshake_outlined),
                      label: Text(
                        _isSendingRequest
                            ? 'Saving request…'
                            : 'Send deal request',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _goHome();
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Home Dashboard'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDealRequestDialog(Listing listing) async {
    if (listing.ownerId == ref.read(appStateProvider).userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot send a request to your own listing.')),
      );
      return;
    }
    if (!ref.read(appStateProvider).profile.hasRequiredProfileIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete your business profile before sending a deal request.',
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final note = TextEditingController();
    final submittedNote = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send a deal request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request will be sent to ${listing.owner} for ${listing.material}.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Optional message',
                hintText: 'For example: We can collect this week.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.chalk,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Request summary: ${listing.quantityLabel} ${listing.unit} of ${listing.material} from ${listing.owner}. A sent request is not a completed deal; both businesses must agree separately.',
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, note.text.trim()),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    // Keep the controller alive until the modal route has fully closed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    note.dispose();
    if (submittedNote == null || !mounted) return;

    setState(() => _isSendingRequest = true);
    try {
      final request = await _dealRequestRepository.sendRequest(
        listing: listing,
        note: submittedNote,
      );
      if (!mounted) return;
      setState(() {
        _requestedListingKeys.add(_listingKey(listing));
        _transactions.insert(0, request);
        _isSendingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deal request sent to ${listing.owner}. Await their direct response.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _isSendingRequest = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The deal request could not be saved. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showFilters(List<Listing> sourceListings) async {
    final materials =
        sourceListings.map((listing) => listing.material).toSet().toList()
          ..sort();
    final locations =
        sourceListings.map((listing) => listing.location).toSet().toList()
          ..sort();
    var draftMaterial = _material;
    var draftLocation = _location;
    var draftVerifiedOnly = _verifiedOnly;
    var draftMinimumQuantity = _minimumQuantity;
    final maximumQuantity = sourceListings.isEmpty
        ? 100.0
        : sourceListings
              .map((listing) => listing.quantity)
              .reduce((a, b) => a > b ? a : b)
              .toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refine marketplace results',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the criteria that matter to you. Results can match one or more criteria, then they are ranked by match percentage instead of requiring a perfect match.',
                    style: TextStyle(color: AppColors.slate, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: draftMaterial ?? 'all',
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Any material'),
                      ),
                      ...materials.map(
                        (material) => DropdownMenuItem(
                          value: material,
                          child: Text(material),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(
                      () => draftMaterial = value == 'all' ? null : value,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: draftLocation ?? 'all',
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Any location'),
                      ),
                      ...locations.map(
                        (location) => DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(
                      () => draftLocation = value == 'all' ? null : value,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified businesses only'),
                    subtitle: const Text(
                      'Show supply and demand from verified ReSource profiles.',
                    ),
                    value: draftVerifiedOnly,
                    onChanged: (value) =>
                        setSheetState(() => draftVerifiedOnly = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Minimum listed quantity: ${draftMinimumQuantity.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: draftMinimumQuantity.clamp(0, maximumQuantity),
                    min: 0,
                    max: maximumQuantity == 0 ? 1 : maximumQuantity,
                    divisions: maximumQuantity >= 5 ? 5 : null,
                    label: draftMinimumQuantity.toStringAsFixed(0),
                    onChanged: (value) =>
                        setSheetState(() => draftMinimumQuantity = value),
                  ),
                  const Text(
                    'Quantity is compared using each listing’s displayed unit. Add standardised units before using this as a production matching rule.',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              draftMaterial = null;
                              draftLocation = null;
                              draftVerifiedOnly = false;
                              draftMinimumQuantity = 0;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final selectedLocation = draftLocation;
                            setState(() {
                              _material = draftMaterial;
                              _location = draftLocation;
                              _verifiedOnly = draftVerifiedOnly;
                              _minimumQuantity = draftMinimumQuantity;
                            });
                            Navigator.pop(sheetContext);
                            if (selectedLocation != null) {
                              _loadIndustrialContext(
                                marketplaceLocation: selectedLocation,
                              );
                            }
                          },
                          child: const Text('Rank matches'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return AppColors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.rust;
      default:
        return AppColors.amber;
    }
  }

  Future<void> _showHistory() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction history',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Outgoing deal requests saved to your Supabase workspace.',
                  style: TextStyle(color: AppColors.slate),
                ),
                const SizedBox(height: 14),
                if (_isLoadingHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_historyError != null)
                  _MarketplaceEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Request history is unavailable.',
                    description: _historyError!,
                    actionLabel: 'Try again',
                    onAction: () {
                      Navigator.pop(sheetContext);
                      _subscribeToRequests();
                    },
                  )
                else if (_transactions.isEmpty)
                  const _MarketplaceEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No deal requests yet.',
                    description:
                        'Open a listing and send a request to create a persistent outgoing request.',
                  )
                else
                  ..._transactions.map(
                    (request) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.handshake_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          request.material,
                                          style: Theme.of(
                                            sheetContext,
                                          ).textTheme.titleSmall,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: request.status,
                                        color: _statusColor(request.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${request.owner} · ${request.quantity}',
                                    style: const TextStyle(
                                      color: AppColors.slate,
                                    ),
                                  ),
                                  Text(
                                    request.location,
                                    style: const TextStyle(
                                      color: AppColors.slate,
                                    ),
                                  ),
                                  if (request.note.isNotEmpty)
                                    Text(
                                      request.note,
                                      style: const TextStyle(
                                        color: AppColors.slate,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (request.responseNote.isNotEmpty)
                                    Text(
                                      'Decline reason: ${request.responseNote}',
                                      style: const TextStyle(
                                        color: AppColors.slate,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          switch (request.status) {
                                            'CANCELLED' =>
                                              'This request was cancelled.',
                                            'ACCEPTED' =>
                                              '${request.owner} accepted this request. The marketplace listing is now matched.',
                                            'REJECTED' =>
                                              '${request.owner} declined this request.',
                                            _ =>
                                              'Awaiting a direct business response.',
                                          },
                                          style: const TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (request.status == 'REQUEST SENT')
                                        TextButton(
                                          onPressed: () {
                                            _cancelDealRequest(request);
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                      Text(
                                        _formatTime(request.sentAt),
                                        style: const TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Transaction history is a persistent record,
                                  // but completed outcomes should still give the
                                  // user a sensible next action.
                                  if (request.status == 'ACCEPTED') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withValues(
                                          alpha: 0.07,
                                        ),
                                        border: Border.all(
                                          color: AppColors.green.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            color: AppColors.green,
                                            size: 19,
                                          ),
                                          SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              'Match confirmed. Review the proposed price and commercial terms before finalising the deal.',
                                              style: TextStyle(
                                                color: AppColors.slate,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          Navigator.pop(sheetContext);
                                          context.push('/fair-price', extra: request);
                                        },
                                        icon: const Icon(
                                          Icons.compare_arrows,
                                          size: 17,
                                        ),
                                        label: const Text(
                                          'Continue with FairPrice',
                                        ),
                                      ),
                                    ),
                                  ] else if (request.status == 'REJECTED') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.rust.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: AppColors.rust.withValues(
                                            alpha: 0.20,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.search_outlined,
                                            color: AppColors.rust,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              request.responseNote.trim().isEmpty
                                                  ? 'Request declined. This request stays in your history. Return to the marketplace to compare other partial matches.'
                                                  : 'Request declined. Review the response above, then return to the marketplace to compare other partial matches.',
                                              style: const TextStyle(
                                                color: AppColors.slate,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          // Transaction history is already opened
                                          // on top of the Marketplace screen, so
                                          // closing the sheet returns directly to
                                          // the marketplace results.
                                          Navigator.pop(sheetContext);
                                        },
                                        icon: const Icon(
                                          Icons.search_outlined,
                                          size: 17,
                                        ),
                                        label: const Text(
                                          'Find another marketplace match',
                                        ),
                                      ),
                                    ),
                                  ] else if (request.status == 'CANCELLED') ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(sheetContext);
                                        },
                                        icon: const Icon(
                                          Icons.storefront_outlined,
                                          size: 17,
                                        ),
                                        label: const Text(
                                          'Return to marketplace listings',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _goHome();
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Home Dashboard'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelDealRequest(DealRequestRecord request) async {
    try {
      await _dealRequestRepository.cancelRequest(request.id);
      if (!mounted) return;
      setState(() {
        final index = _transactions.indexWhere((item) => item.id == request.id);
        if (index >= 0) {
          _transactions[index] = request.copyWith(status: 'CANCELLED');
        }
        _requestedListingKeys.remove(request.listingId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deal request cancelled.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The deal request could not be cancelled. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showIncomingRequests() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requests for your listings',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Deal requests other businesses have sent to material you listed. Accept to move a discussion forward, or decline it.',
                    style: TextStyle(color: AppColors.slate, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingIncoming)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_incomingError != null)
                    _MarketplaceEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Incoming requests are unavailable.',
                      description: _incomingError!,
                      actionLabel: 'Try again',
                      onAction: () {
                        Navigator.pop(sheetContext);
                        _subscribeToRequests();
                      },
                    )
                  else if (_incomingRequests.isEmpty)
                    const _MarketplaceEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No requests yet.',
                      description:
                          'When a business sends a request for one of your listings, it will show up here for you to accept or decline.',
                    )
                  else
                    ..._incomingRequests.map(
                      (request) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.handshake_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            request.material,
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusChip(
                                          label: request.status,
                                          color: _statusColor(request.status),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'From ${request.requesterName} · ${request.quantity}',
                                      style: const TextStyle(
                                        color: AppColors.slate,
                                      ),
                                    ),
                                    Text(
                                      request.location,
                                      style: const TextStyle(
                                        color: AppColors.slate,
                                      ),
                                    ),
                                    if (request.note.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                        ),
                                        child: Text(
                                          '"${request.note}"',
                                          style: const TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    if (request.responseNote.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Decline reason: ${request.responseNote}',
                                          style: const TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    if (request.status == 'REQUEST SENT')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _isRespondingToRequest
                                                  ? null
                                                  : () async {
                                                      await _respondToIncomingRequest(
                                                        request,
                                                        accept: false,
                                                      );
                                                      setSheetState(() {});
                                                    },
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: _isRespondingToRequest
                                                  ? null
                                                  : () async {
                                                      await _respondToIncomingRequest(
                                                        request,
                                                        accept: true,
                                                      );
                                                      setSheetState(() {});
                                                    },
                                              child: const Text('Accept'),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        switch (request.status) {
                                          'ACCEPTED' =>
                                            'You accepted this request.',
                                          'REJECTED' =>
                                            'You declined this request.',
                                          _ =>
                                            'This request was cancelled by the requester.',
                                        },
                                        style: const TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _formatTime(request.sentAt),
                                        style: const TextStyle(
                                          color: AppColors.slate,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _goHome();
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Return to Home Dashboard'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearAdvancedFilters() {
    setState(() {
      _material = null;
      _location = null;
      _verifiedOnly = false;
      _minimumQuantity = 0;
    });
  }

  void _saveCurrentSearch() {
    final query = _search.text.trim();
    final hasCriteria =
        query.isNotEmpty || _filter != 'all' || _hasAdvancedFilters;
    if (!hasCriteria) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a search term or filter before saving a search.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _savedSearch = _SavedMarketplaceSearch(
        query: query,
        type: _filter,
        material: _material,
        location: _location,
        verifiedOnly: _verifiedOnly,
        minimumQuantity: _minimumQuantity,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search saved for this session.')),
    );
  }

  void _applySavedSearch() {
    final search = _savedSearch;
    if (search == null) return;
    _search.text = search.query;
    setState(() {
      _filter = search.type;
      _material = search.material;
      _location = search.location;
      _verifiedOnly = search.verifiedOnly;
      _minimumQuantity = search.minimumQuantity;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved search applied.')));
  }

  void _resetAllFilters() {
    _search.clear();
    setState(() {
      _filter = 'all';
      _sort = 'default';
      _material = null;
      _location = null;
      _verifiedOnly = false;
      _minimumQuantity = 0;
    });
  }

  String _listingKey(Listing listing) => listing.id;

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.navy,
  });

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
        decoration: BoxDecoration(
          color: selected ? color : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Remove $label filter',
      child: InputChip(
        label: Text(label),
        onDeleted: onClear,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.listing,
    required this.requested,
    required this.showMatchScore,
    required this.matchScore,
    required this.matchLabel,
    required this.onTap,
  });

  final Listing listing;
  final bool requested;
  final bool showMatchScore;
  final int matchScore;
  final String matchLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSupply = listing.type == 'supply';
    final isPresentationSample = listing.description.startsWith(
      '[PRESENTATION SAMPLE]',
    );
    final color = isSupply ? AppColors.green : AppColors.rust;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(
                    label: isSupply ? 'SUPPLY' : 'DEMAND',
                    color: color,
                  ),
                  if (isPresentationSample) ...[
                    const SizedBox(width: 6),
                    const StatusChip(
                      label: 'DEMO SAMPLE',
                      color: AppColors.amber,
                    ),
                  ],
                  const Spacer(),
                  if (requested)
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.green,
                    )
                  else if (listing.verified)
                    const Tooltip(
                      message: 'Verified ReSource business',
                      child: Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: AppColors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                listing.material,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${listing.quantityLabel} ${listing.unit}',
                    style: AppTheme.dataStyle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.slate,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      listing.location,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.owner,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (showMatchScore) ...[
                    Text(
                      'Match $matchScore%',
                      style: AppTheme.dataStyle.copyWith(
                        color: AppColors.green,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: AppColors.slate,
                  ),
                ],
              ),
              if (showMatchScore) ...[
                const SizedBox(height: 5),
                Text(
                  matchLabel,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  const _MarketplaceEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.green, size: 28),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.slate,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _SavedSearchBanner extends StatelessWidget {
  const _SavedSearchBanner({required this.onApply, required this.onClear});

  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_added_outlined,
            color: AppColors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'A marketplace search is saved for this session.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(onPressed: onApply, child: const Text('Apply')),
          IconButton(
            onPressed: onClear,
            tooltip: 'Remove saved search',
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}


