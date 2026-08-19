import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';
import '../data/deal_request_repository.dart';

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
  final _transactions = <DealRequestRecord>[];
  final _requestedListingKeys = <String>{};

  String _filter = 'all';
  String _sort = 'default';
  String? _material;
  String? _location;
  bool _verifiedOnly = false;
  double _minimumQuantity = 0;
  _SavedMarketplaceSearch? _savedSearch;
  bool _isLoadingHistory = true;
  bool _isSendingRequest = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadOutgoingRequests);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOutgoingRequests() async {
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
      });
    }
    try {
      final requests = await _dealRequestRepository.fetchOutgoingRequests();
      if (!mounted) return;
      setState(() {
        _transactions
          ..clear()
          ..addAll(requests);
        _requestedListingKeys
          ..clear()
          ..addAll(requests.map((request) => request.listingId));
        _isLoadingHistory = false;
        _historyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = 'Firestore request history could not be loaded.';
      });
      debugPrint('Marketplace request history could not be loaded: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceListings = ref.watch(appStateProvider).listings;
    final listings = _filteredListings(sourceListings);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: _goBack,
        ),
        title: const Text('ReSource Marketplace'),
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
              PopupMenuItem(value: 'relevance', child: Text('Best match first')),
              PopupMenuItem(value: 'quantity', child: Text('Highest quantity')),
              PopupMenuItem(value: 'location', child: Text('Location A–Z')),
            ],
            icon: const Icon(Icons.sort_outlined),
          ),
          IconButton(
            icon: Badge.count(
              count: _transactions.length,
              isLabelVisible: _transactions.isNotEmpty,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            tooltip: 'View transaction history',
            onPressed: _showHistory,
          ),
        const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: const _MarketplaceNavigationBar(),
      body: ListView(
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
                if (_material != null) _ActiveFilter(label: _material!, onClear: () => setState(() => _material = null)),
                if (_location != null) _ActiveFilter(label: _location!, onClear: () => setState(() => _location = null)),
                if (_verifiedOnly) _ActiveFilter(label: 'Verified only', onClear: () => setState(() => _verifiedOnly = false)),
                if (_minimumQuantity > 0)
                  _ActiveFilter(
                    label: 'At least ${_minimumQuantity.toStringAsFixed(0)} units',
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
            _SavedSearchBanner(onApply: _applySavedSearch, onClear: () => setState(() => _savedSearch = null)),
          ],
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
          const SizedBox(height: 10),
          if (sourceListings.isEmpty)
            const _MarketplaceEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'The exchange is waiting for its first listing.',
              description: 'Add a supply or demand listing from your ReSource profile to make materials discoverable here.',
            )
          else if (listings.isEmpty)
            _MarketplaceEmptyState(
              icon: Icons.search_off_outlined,
              title: 'No listings match these filters.',
              description: 'Try a broader search or reset the current filters to see more material opportunities.',
              actionLabel: 'Reset filters',
              onAction: _resetAllFilters,
            )
          else
            ...listings.map(
              (listing) => _MarketplaceCard(
                listing: listing,
                requested: _requestedListingKeys.contains(_listingKey(listing)),
                matchScore: _matchScore(listing),
                matchLabel: _matchLabel(listing),
                onTap: () => _showDetail(listing),
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasAdvancedFilters => _material != null || _location != null || _verifiedOnly || _minimumQuantity > 0;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  List<Listing> _filteredListings(List<Listing> source) {
    final query = _search.text.trim().toLowerCase();
    final filtered = source.where((listing) {
      final matchesType = _filter == 'all' || listing.type == _filter;
      final searchableText = '${listing.material} ${listing.location} ${listing.owner} ${listing.description}'.toLowerCase();
      final matchesSearch = query.isEmpty || searchableText.contains(query);
      final matchesMaterial = _material == null || listing.material == _material;
      final matchesLocation = _location == null || listing.location == _location;
      final matchesVerified = !_verifiedOnly || listing.verified;
      final matchesQuantity = listing.quantity >= _minimumQuantity;
      return matchesType && matchesSearch && matchesMaterial && matchesLocation && matchesVerified && matchesQuantity;
    }).toList();

    switch (_sort) {
      case 'relevance':
        filtered.sort((a, b) => _matchScore(b).compareTo(_matchScore(a)));
        break;
      case 'quantity':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'location':
        filtered.sort((a, b) => a.location.toLowerCase().compareTo(b.location.toLowerCase()));
        break;
      case 'default':
        break;
    }
    return filtered;
  }

  int _matchScore(Listing listing) {
    final query = _search.text.trim().toLowerCase();
    var score = 45;
    if (query.isNotEmpty && listing.material.toLowerCase().contains(query)) score += 25;
    if (query.isNotEmpty && listing.location.toLowerCase().contains(query)) score += 10;
    if (_material == listing.material) score += 8;
    if (_location == listing.location) score += 6;
    if (_filter != 'all' && listing.type == _filter) score += 4;
    if (listing.verified) score += 7;
    if (_minimumQuantity > 0 && listing.quantity >= _minimumQuantity) score += 3;
    return score.clamp(45, 98).toInt();
  }

  String _matchLabel(Listing listing) {
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty && listing.material.toLowerCase().contains(query)) return 'Material search match';
    if (_material == listing.material) return 'Material filter match';
    if (_location == listing.location) return 'Location filter match';
    if (listing.verified) return 'Verified ReSource business';
    return 'Prototype marketplace match';
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(listing.material, style: Theme.of(sheetContext).textTheme.titleLarge)),
                  StatusChip(label: isSupply ? 'SUPPLY' : 'DEMAND', color: isSupply ? AppColors.green : AppColors.rust),
                ],
              ),
              const SizedBox(height: 14),
              _DetailLine(label: 'Business', value: listing.owner),
              _DetailLine(label: 'Quantity', value: '${listing.quantity.toStringAsFixed(0)} ${listing.unit}'),
              _DetailLine(label: 'Location', value: listing.location),
              _DetailLine(label: 'Description', value: listing.description),
              if (listing.verified) const _DetailLine(label: 'Trust status', value: 'Verified ReSource business'),
              _DetailLine(label: 'Local match signal', value: '${_matchScore(listing)}% · ${_matchLabel(listing)}'),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Prototype match signal only — confirm material grade, unit and collection terms directly with the business.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
              ),
              const SizedBox(height: 16),
              if (requested)
                const _RequestStatus()
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSendingRequest
                        ? null
                        : () async {
                      Navigator.pop(sheetContext);
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                      if (!mounted) return;
                      await _showDealRequestDialog(listing);
                    },
                    icon: const Icon(Icons.handshake_outlined),
                    label: Text(_isSendingRequest ? 'Saving request…' : 'Send deal request'),
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
    final note = TextEditingController();
    final submittedNote = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send a deal request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your request will be sent to ${listing.owner} for ${listing.material}.'),
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
              decoration: BoxDecoration(color: AppColors.chalk, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Request summary: ${listing.quantity.toStringAsFixed(0)} ${listing.unit} of ${listing.material} from ${listing.owner}. A sent request is not a completed deal; both businesses must agree separately.',
                style: const TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, note.text.trim()), child: const Text('Send request')),
        ],
      ),
    );

    // Keep the controller alive until the modal route has fully closed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    note.dispose();
    if (submittedNote == null || !mounted) return;

    setState(() => _isSendingRequest = true);
    try {
      final request = await _dealRequestRepository.sendRequest(listing: listing, note: submittedNote);
      if (!mounted) return;
      setState(() {
        _requestedListingKeys.add(_listingKey(listing));
        _transactions.insert(0, request);
        _isSendingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deal request sent to ${listing.owner}. Await their direct response.'),
          action: SnackBarAction(label: 'History', onPressed: _showHistory),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _isSendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The deal request could not be saved. Please check your connection and try again.')));
    }
  }

  Future<void> _showFilters(List<Listing> sourceListings) async {
    final materials = sourceListings.map((listing) => listing.material).toSet().toList()..sort();
    final locations = sourceListings.map((listing) => listing.location).toSet().toList()..sort();
    var draftMaterial = _material;
    var draftLocation = _location;
    var draftVerifiedOnly = _verifiedOnly;
    var draftMinimumQuantity = _minimumQuantity;
    final maximumQuantity = sourceListings.isEmpty
        ? 100.0
        : sourceListings.map((listing) => listing.quantity).reduce((a, b) => a > b ? a : b).toDouble();

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
                  Text('Refine marketplace results', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Use the filters below to focus on a viable supply or demand match.', style: TextStyle(color: AppColors.slate, height: 1.35)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: draftMaterial ?? 'all',
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Any material')),
                      ...materials.map((material) => DropdownMenuItem(value: material, child: Text(material))),
                    ],
                    onChanged: (value) => setSheetState(() => draftMaterial = value == 'all' ? null : value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: draftLocation ?? 'all',
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Any location')),
                      ...locations.map((location) => DropdownMenuItem(value: location, child: Text(location))),
                    ],
                    onChanged: (value) => setSheetState(() => draftLocation = value == 'all' ? null : value),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified businesses only'),
                    subtitle: const Text('Show supply and demand from verified ReSource profiles.'),
                    value: draftVerifiedOnly,
                    onChanged: (value) => setSheetState(() => draftVerifiedOnly = value),
                  ),
                  const SizedBox(height: 8),
                  Text('Minimum listed quantity: ${draftMinimumQuantity.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleSmall),
                  Slider(
                    value: draftMinimumQuantity.clamp(0, maximumQuantity),
                    min: 0,
                    max: maximumQuantity == 0 ? 1 : maximumQuantity,
                    divisions: maximumQuantity >= 5 ? 5 : null,
                    label: draftMinimumQuantity.toStringAsFixed(0),
                    onChanged: (value) => setSheetState(() => draftMinimumQuantity = value),
                  ),
                  const Text('Quantity is compared using each listing’s displayed unit. Add standardised units before using this as a production matching rule.', style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
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
                            setState(() {
                              _material = draftMaterial;
                              _location = draftLocation;
                              _verifiedOnly = draftVerifiedOnly;
                              _minimumQuantity = draftMinimumQuantity;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Show results'),
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

  Future<void> _showHistory() async {
    await _loadOutgoingRequests();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction history', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Outgoing deal requests saved to your Firestore account.', style: TextStyle(color: AppColors.slate)),
              const SizedBox(height: 14),
              if (_isLoadingHistory)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_historyError != null)
                _MarketplaceEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Request history is unavailable.',
                  description: _historyError!,
                  actionLabel: 'Try again',
                  onAction: () {
                    Navigator.pop(sheetContext);
                    _showHistory();
                  },
                )
              else if (_transactions.isEmpty)
                const _MarketplaceEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No deal requests yet.',
                  description: 'Open a listing and send a request to create a persistent outgoing request.',
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
                          const CircleAvatar(child: Icon(Icons.handshake_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(request.material, style: Theme.of(sheetContext).textTheme.titleSmall)),
                                    const SizedBox(width: 8),
                                    StatusChip(label: request.status, color: AppColors.amber),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text('${request.owner} · ${request.quantity}', style: const TextStyle(color: AppColors.slate)),
                                Text(request.location, style: const TextStyle(color: AppColors.slate)),
                                if (request.note.isNotEmpty) Text(request.note, style: const TextStyle(color: AppColors.slate, fontSize: 12)),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Expanded(child: Text('Awaiting a direct business response.', style: TextStyle(color: AppColors.slate, fontSize: 12))),
                                    Text(_formatTime(request.sentAt), style: const TextStyle(color: AppColors.slate, fontSize: 12)),
                                  ],
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
    final hasCriteria = query.isNotEmpty || _filter != 'all' || _hasAdvancedFilters;
    if (!hasCriteria) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a search term or filter before saving a search.')));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search saved for this session.')));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved search applied.')));
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
        decoration: BoxDecoration(
          color: selected ? color : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? AppColors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w600),
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
  const _MarketplaceCard({required this.listing, required this.requested, required this.matchScore, required this.matchLabel, required this.onTap});

  final Listing listing;
  final bool requested;
  final int matchScore;
  final String matchLabel;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(label: isSupply ? 'SUPPLY' : 'DEMAND', color: color),
                  const Spacer(),
                  if (requested)
                    const Icon(Icons.check_circle_outline, size: 18, color: AppColors.green)
                  else if (listing.verified)
                    const Tooltip(message: 'Verified ReSource business', child: Icon(Icons.verified_outlined, size: 18, color: AppColors.green)),
                ],
              ),
              const SizedBox(height: 11),
              Text(listing.material, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit}', style: AppTheme.dataStyle.copyWith(fontSize: 14)),
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.slate),
                  const SizedBox(width: 3),
                  Expanded(child: Text(listing.location, style: const TextStyle(color: AppColors.slate, fontSize: 12))),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(child: Text(listing.owner, style: const TextStyle(color: AppColors.slate, fontSize: 12))),
                  Text('$matchScore%', style: AppTheme.dataStyle.copyWith(color: AppColors.green, fontSize: 12)),
                  const SizedBox(width: 6),
                  if (requested) const Text('REQUEST SENT', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 5),
              Text(matchLabel, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  const _MarketplaceEmptyState({required this.icon, required this.title, required this.description, this.actionLabel, this.onAction});

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
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.35)),
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

class _RequestStatus extends StatelessWidget {
  const _RequestStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.green),
          SizedBox(width: 10),
          Expanded(child: Text('Deal request sent. You can review it in transaction history.')),
        ],
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
            SizedBox(width: 86, child: Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14, height: 1.35))),
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
      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.08), border: Border.all(color: AppColors.green.withOpacity(0.25)), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.bookmark_added_outlined, color: AppColors.green, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('A marketplace search is saved for this session.', style: TextStyle(fontSize: 12))),
          TextButton(onPressed: onApply, child: const Text('Apply')),
          IconButton(onPressed: onClear, tooltip: 'Remove saved search', icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}

class _MarketplaceNavigationBar extends StatelessWidget {
  const _MarketplaceNavigationBar();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 1,
      onDestinationSelected: (index) {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/marketplace');
        if (index == 2) context.go('/resource-profile');
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Console'),
        NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Market'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
