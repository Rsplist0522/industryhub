



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/validators.dart';
import '../../../core/widgets.dart';
import '../../resource_marketplace/data/deal_request_repository.dart';
import '../data/fair_price_recommendation_repository.dart';
import '../data/market_price_repository.dart';

class _Benchmark {
  const _Benchmark({
    required this.label,
    required this.low,
    required this.high,
    required this.note,
    required this.isLiveEvidence,
  });

  final String label;
  final double low;
  final double high;
  final String note;
  final bool isLiveEvidence;

  double get midpoint => (low + high) / 2;
}

class _NegotiationResult {
  const _NegotiationResult({
    required this.benchmark,
    required this.product,
    required this.quantity,
    required this.proposedPrice,
    required this.floor,
    required this.target,
    required this.ceiling,
    required this.adjustments,
    required this.strategy,
    this.condition,
    this.collection,
    this.quantityAdjustment,
    this.conditionAdjustmentFloor,
    this.conditionAdjustmentCeiling,
    this.collectionAdjustment,
  });

  final _Benchmark benchmark;
  final String product;
  final double quantity;
  final double proposedPrice;
  final double floor;
  final double target;
  final double ceiling;
  final List<String> adjustments;
  final String strategy;
  final String? condition;
  final String? collection;
  final double? quantityAdjustment;
  final double? conditionAdjustmentFloor;
  final double? conditionAdjustmentCeiling;
  final double? collectionAdjustment;

  String get rangeLabel =>
      'RM ${floor.toStringAsFixed(2)} — ${ceiling.toStringAsFixed(2)} / kg';
}

class _PriceChatLine {
  const _PriceChatLine(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class FairPriceScreen extends ConsumerStatefulWidget {
  const FairPriceScreen({
    super.key,
    this.initialDeal,
    this.initialRecommendation,
  });

  final DealRequestRecord? initialDeal;
  final SavedFairPriceRecommendation? initialRecommendation;

  @override
  ConsumerState<FairPriceScreen> createState() => _FairPriceScreenState();
}

class _FairPriceScreenState extends ConsumerState<FairPriceScreen> {
  final _product = TextEditingController(text: 'Aluminium machining offcuts');
  final _price = TextEditingController(text: '48');
  final _quantity = TextEditingController(text: '500');
  final _formKey = GlobalKey<FormState>();

  final _chatInput = TextEditingController();
  final _chatMessages = <_PriceChatLine>[];

  final _marketPriceRepository = MarketPriceRepository();
  final _recommendationRepository = FairPriceRecommendationRepository();
  final _aiService = const AiService();

  bool _isRunning = false;
  bool _isChatThinking = false;
  bool _isSaving = false;
  bool _isSaved = false;
  bool _isLoadingMarketSignals = true;

  String _selectedMaterial = 'Aluminium';
  String _condition = 'Sorted & dry';
  String _collection = 'Buyer collects';

  _NegotiationResult? _result;
  String? _editingRecommendationId;

  CommodityPriceObservation? _commoditySignal;
  PriceIndexObservation? _materialIndexSignal;
  PriceIndexObservation? _ppiSignal;
  List<LocalListingPrice> _localListingPrices = const [];

  static const _materials = <String>[
    'Aluminium',
    'Copper',
    'Steel / iron',
    'Plastic / polymer',
    'Paper / cardboard',
    'Other material',
  ];

  static const _conditions = <String>[
    'Mixed / unsorted',
    'Sorted & dry',
    'Verified grade',
  ];

  static const _collectionTerms = <String>['Buyer collects', 'Seller delivers'];

  static const _documentationLinks = <(String, String, String)>[
    (
      'DOSM Producer Price Index',
      'Official Malaysian producer-price context.',
      'https://data.gov.my/data-catalogue/ppi',
    ),
    (
      'FRED producer-price series',
      'International material-price context used when available.',
      'https://fred.stlouisfed.org/',
    ),
  ];

  DealRequestRecord? get _deal => widget.initialDeal;

  bool get _openedFromAcceptedDeal =>
      _deal != null && _deal!.status == 'ACCEPTED';

  @override
  void initState() {
    super.initState();
    _applyInitialScenario();

    Future<void>.microtask(() => _loadMarketSignals(_product.text.trim()));
  }

  @override
  void didUpdateWidget(covariant FairPriceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialDeal?.id != widget.initialDeal?.id ||
        oldWidget.initialRecommendation?.id !=
            widget.initialRecommendation?.id) {
      _applyInitialScenario();
      Future<void>.microtask(() => _loadMarketSignals(_product.text.trim()));
    }
  }

  void _applyInitialScenario() {
    final recommendation = widget.initialRecommendation;
    if (recommendation != null) {
      _editingRecommendationId = recommendation.id;
      _selectedMaterial = recommendation.materialCategory.isNotEmpty
          ? recommendation.materialCategory
          : 'Other material';
      _product.text = recommendation.product;
      _quantity.text = _numberText(recommendation.quantity);
      _price.text = recommendation.proposedPricePerKg.toStringAsFixed(2);
      _condition = recommendation.materialCondition;
      _collection = recommendation.collectionTerms;
      _result = null;
      _isSaved = false;
      _chatMessages.clear();
      return;
    }

    _editingRecommendationId = null;
    final deal = _deal;

    if (deal == null || deal.status != 'ACCEPTED') {
      _selectedMaterial = 'Aluminium';
      _product.text = 'Aluminium machining offcuts';
      _quantity.text = '500';
      _price.text = '48';
      return;
    }

    _product.text = deal.material.trim().isEmpty
        ? 'Matched marketplace material'
        : deal.material.trim();

    final quantityValue = deal.quantityValue ?? _parseQuantity(deal.quantity);

    if (quantityValue != null && quantityValue > 0) {
      _quantity.text = _numberText(quantityValue);
    } else {
      _quantity.clear();
    }

    if (deal.askingPricePerKg != null && deal.askingPricePerKg! > 0) {
      _price.text = deal.askingPricePerKg!.toStringAsFixed(2);
    } else {


      _price.clear();
    }

    _selectedMaterial = _materialCategoryFor(_product.text);
    _condition = 'Sorted & dry';
    _collection = 'Buyer collects';
    _result = null;
    _isSaved = false;
    _chatMessages.clear();
  }

  double? _parseQuantity(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  String _numberText(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _materialCategoryFor(String material) {
    final lower = material.toLowerCase();

    if (lower.contains('aluminium') || lower.contains('aluminum')) {
      return 'Aluminium';
    }
    if (lower.contains('copper')) return 'Copper';
    if (lower.contains('steel') ||
        lower.contains('iron') ||
        lower.contains('ferrous')) {
      return 'Steel / iron';
    }
    if (lower.contains('plastic') ||
        lower.contains('polymer') ||
        lower.contains('hdpe') ||
        lower.contains('ldpe') ||
        lower.contains('pet')) {
      return 'Plastic / polymer';
    }
    if (lower.contains('paper') || lower.contains('cardboard')) {
      return 'Paper / cardboard';
    }
    return 'Other material';
  }

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    _quantity.dispose();
    _chatInput.dispose();
    super.dispose();
  }

  Future<void> _loadMarketSignals(String product) async {
    if (!mounted) return;

    setState(() => _isLoadingMarketSignals = true);

    try {
      final commodity = await _marketPriceRepository.fetchLatestCommodity(
        product,
      );
      final materialIndex = await _marketPriceRepository
          .fetchLatestMaterialIndex(product);
      final ppi = await _marketPriceRepository.fetchLatestMalaysiaPpi();
      final localPrices = await _marketPriceRepository
          .fetchLatestLocalListingPrices(product);

      if (!mounted) return;

      setState(() {
        _commoditySignal = commodity;
        _materialIndexSignal = materialIndex;
        _ppiSignal = ppi;
        _localListingPrices = localPrices;
        _isLoadingMarketSignals = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _commoditySignal = null;
        _materialIndexSignal = null;
        _ppiSignal = null;
        _localListingPrices = const [];
        _isLoadingMarketSignals = false;
      });

      debugPrint('FairPrice market signals could not be loaded: $error');
    }
  }

  String? _requiredText(String? value) =>
      validateRequiredText(value, label: 'a material or product name');

  String? _positiveNumber(String? value, String label) =>
      validatePositiveNumber(value, label: label);

  Future<void> _prepareNegotiation() async {
    if (_isRunning) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!ref.read(appStateProvider).profile.hasRequiredProfileIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete your business profile before running a FairPrice negotiation.',
          ),
        ),
      );
      return;
    }

    final product = _product.text.trim();
    final quantity = double.parse(_quantity.text.trim());
    final proposedPrice = double.parse(_price.text.trim());

    setState(() => _isRunning = true);

    await _loadMarketSignals(product);
    if (!mounted) return;

    final result = _calculateResult(
      product: product,
      quantity: quantity,
      proposedPrice: proposedPrice,
    );

    setState(() {
      _isRunning = false;
      _isSaved = false;
      _result = result;
      _chatMessages.clear();
    });
  }

  _NegotiationResult _calculateResult({
    required String product,
    required double quantity,
    required double proposedPrice,
  }) {
    final benchmark = _benchmarkFor(product, proposedPrice);

    if (!benchmark.isLiveEvidence) {
      return _NegotiationResult(
        benchmark: benchmark,
        product: product,
        quantity: quantity,
        proposedPrice: proposedPrice,
        floor: 0,
        target: 0,
        ceiling: 0,
        adjustments: const [
          'No comparable live asking-price observations were available.',
        ],
        strategy:
            'The entered price is your negotiation anchor only. Confirm grade, quantity, logistics, and counterparty terms before agreement.',
      );
    }

    var floor = benchmark.low;
    var ceiling = benchmark.high;
    final adjustments = <String>[];
    var quantityAdjustment = 0.0;
    var conditionAdjustmentFloor = 0.0;
    var conditionAdjustmentCeiling = 0.0;
    var collectionAdjustment = 0.0;

    if (quantity >= 1000) {
      quantityAdjustment = -0.50;
      floor += quantityAdjustment;
      ceiling += quantityAdjustment;
      adjustments.add(
        'Larger volume creates room for a modest buyer discount.',
      );
    } else if (quantity < 250) {
      quantityAdjustment = 0.50;
      floor += quantityAdjustment;
      ceiling += quantityAdjustment;
      adjustments.add('Smaller volume supports a handling allowance.');
    } else {
      adjustments.add(
        'The quantity sits within the indicative reference band.',
      );
    }

    switch (_condition) {
      case 'Sorted & dry':
        conditionAdjustmentFloor = 0.50;
        conditionAdjustmentCeiling = 0.75;
        floor += conditionAdjustmentFloor;
        ceiling += conditionAdjustmentCeiling;
        adjustments.add(
          'Sorted, dry material strengthens the quality position.',
        );
      case 'Verified grade':
        conditionAdjustmentFloor = 1.00;
        conditionAdjustmentCeiling = 1.50;
        floor += conditionAdjustmentFloor;
        ceiling += conditionAdjustmentCeiling;
        adjustments.add(
          'Verified grade supports the strongest quality premium.',
        );
      default:
        adjustments.add(
          'Mixed material keeps the recommendation conservative.',
        );
    }

    if (_collection == 'Seller delivers') {
      collectionAdjustment = -0.75;
      floor += collectionAdjustment;
      ceiling += collectionAdjustment;
      adjustments.add('Seller delivery absorbs part of the logistics cost.');
    } else {
      adjustments.add(
        'Buyer collection protects the offer from delivery-cost pressure.',
      );
    }

    floor = _roundToFiftySen(floor < 0 ? 0 : floor);
    ceiling = _roundToFiftySen(ceiling < floor ? floor : ceiling);
    final target = _roundToFiftySen((floor + ceiling) / 2);

    final strategy = proposedPrice < floor
        ? 'The proposed price is below the indicative floor. Consider opening near RM ${target.toStringAsFixed(2)}/kg and only moving lower if the commercial terms improve.'
        : proposedPrice > ceiling
        ? 'The proposed price is above the indicative ceiling. Support it with quality evidence, while preparing to negotiate toward RM ${target.toStringAsFixed(2)}/kg.'
        : 'The proposed price is inside the indicative range. Use quality, collection, and quantity terms to negotiate around RM ${target.toStringAsFixed(2)}/kg.';

    return _NegotiationResult(
      benchmark: benchmark,
      product: product,
      quantity: quantity,
      proposedPrice: proposedPrice,
      floor: floor,
      target: target,
      ceiling: ceiling,
      adjustments: adjustments,
      strategy: strategy,
      condition: _condition,
      collection: _collection,
      quantityAdjustment: quantityAdjustment,
      conditionAdjustmentFloor: conditionAdjustmentFloor,
      conditionAdjustmentCeiling: conditionAdjustmentCeiling,
      collectionAdjustment: collectionAdjustment,
    );
  }

  _Benchmark _benchmarkFor(String product, double proposedPrice) {
    final prices =
        _localListingPrices
            .map((item) => item.pricePerKg)
            .where((price) => price > 0)
            .toList()
          ..sort();

    if (prices.isEmpty) {
      return _Benchmark(
        label: 'No live local benchmark loaded',
        low: proposedPrice,
        high: proposedPrice,
        note:
            'No comparable active marketplace listing currently publishes an asking price for this material.',
        isLiveEvidence: false,
      );
    }

    return _Benchmark(
      label: 'Live Supabase comparable listings',
      low: prices.first,
      high: prices.last,
      note:
          'Based on ${prices.length} published asking-price observation${prices.length == 1 ? '' : 's'} from active marketplace listings.',
      isLiveEvidence: true,
    );
  }

  double _roundToFiftySen(double value) => (value * 2).round() / 2;

  Future<void> _sendChat() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty || _isChatThinking) return;

    final result = _result;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prepare the negotiation before asking FairPrice.'),
        ),
      );
      return;
    }

    _chatInput.clear();

    setState(() {
      _chatMessages.add(_PriceChatLine(text, true));
      _isChatThinking = true;
    });

    final dealContext = _deal == null
        ? 'No Marketplace deal context.'
        : '''
Marketplace accepted deal:
Request id: ${_deal!.id}
Business: ${_deal!.owner}
Material: ${_deal!.material}
Quantity: ${_deal!.quantity}
Location: ${_deal!.location}
Original request message: ${_deal!.note.isEmpty ? 'none' : _deal!.note}
''';

    try {
      final response = await _aiService.callAI(
        'You are FairPrice, a negotiation assistant for Malaysian industrial SMEs. Use only the supplied scenario, deal context, and evidence. Do not invent a buyer, supplier, completed payment, or guaranteed market price. Give concise, practical negotiation guidance. Return exactly these JSON keys: buyer_message, recommended_strategy, counter_offer_rm_per_kg (number or null), risk_flags (array of concise strings).',
        '''
$dealContext
Material: ${result.product}
Quantity: ${result.quantity.toStringAsFixed(2)} kg
Proposed price: RM ${result.proposedPrice.toStringAsFixed(2)}/kg
Reference: ${result.benchmark.label}
Indicative range: ${result.benchmark.isLiveEvidence ? result.rangeLabel : 'No numeric live range available'}
Condition: $_condition
Collection terms: $_collection

User message:
$text
''',
      );

      if (!mounted) return;

      final buyerMessage = response['buyer_message'] is String
          ? (response['buyer_message'] as String).trim()
          : '';

      final strategy = response['recommended_strategy'] is String
          ? (response['recommended_strategy'] as String).trim()
          : '';

      final counter = response['counter_offer_rm_per_kg'];
      final counterText = counter is num && result.benchmark.isLiveEvidence
          ? ' Suggested position: RM ${counter.toDouble().clamp(result.floor, result.ceiling).toStringAsFixed(2)}/kg.'
          : '';

      final risks = response['risk_flags'] is List
          ? (response['risk_flags'] as List)
                .whereType<String>()
                .take(4)
                .join(' · ')
          : '';

      final answer = [
        if (buyerMessage.isNotEmpty) buyerMessage,
        if (strategy.isNotEmpty) strategy,
        if (counterText.isNotEmpty) counterText.trim(),
        if (risks.isNotEmpty) 'Checks: $risks',
      ].join(' ');

      setState(() {
        _isChatThinking = false;
        _chatMessages.add(
          _PriceChatLine(
            answer.isEmpty
                ? 'Review the live evidence, quality, and logistics terms before changing your offer.'
                : answer,
            false,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isChatThinking = false;
        _chatMessages.add(
          _PriceChatLine(
            'AI response unavailable. ${describeAiError(error)}',
            false,
          ),
        );
      });
    }
  }

  Future<void> _saveRecommendation() async {
    final result = _result;
    if (result == null || _isSaved || _isSaving) return;

    setState(() => _isSaving = true);
    final isUpdating = _editingRecommendationId != null;

    try {
      final recommendation = isUpdating
          ? await _recommendationRepository.updateRecommendation(
              id: _editingRecommendationId!,
              materialCategory: _selectedMaterial,
              product: result.product,
              quantity: result.quantity,
              proposedPricePerKg: result.proposedPrice,
              materialCondition: _condition,
              collectionTerms: _collection,
              recommendedLow: result.floor,
              recommendedHigh: result.ceiling,
              suggestedTarget: result.target,
              strategy: result.strategy,
              peerObservationCount: _localListingPrices.length,
              notes: result.strategy,
              hasLiveEvidence: result.benchmark.isLiveEvidence,
            )
          : await _recommendationRepository.createRecommendation(
              materialCategory: _selectedMaterial,
              product: result.product,
              quantity: result.quantity,
              proposedPricePerKg: result.proposedPrice,
              materialCondition: _condition,
              collectionTerms: _collection,
              recommendedLow: result.floor,
              recommendedHigh: result.ceiling,
              suggestedTarget: result.target,
              strategy: result.strategy,
              peerObservationCount: _localListingPrices.length,
              notes: result.strategy,
              hasLiveEvidence: result.benchmark.isLiveEvidence,
            );

      await ref.read(appStateProvider.notifier).refreshSupabaseData();

      if (!mounted) return;

      setState(() {
        _editingRecommendationId = recommendation.id;
        _isSaved = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdating
                ? 'Recommendation updated successfully.'
                : 'Recommendation saved successfully.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('FairPrice recommendation save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recommendation could not be saved. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  void _resetScenario() {
    if (_isRunning || _isChatThinking) return;

    setState(() {
      _result = null;
      _chatMessages.clear();
      _isSaved = false;
      _condition = 'Sorted & dry';
      _collection = 'Buyer collects';
      _applyInitialScenario();
    });

    Future<void>.microtask(() => _loadMarketSignals(_product.text.trim()));
  }

  Future<void> _openDocumentation(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The documentation link could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewBenchmark = _benchmarkFor(
      _product.text.trim(),
      double.tryParse(_price.text.trim()) ?? 0,
    );

    return AppShell(
      title: 'FairPrice Advisor',
      showBack: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_border),
          tooltip: 'Saved recommendations',
          onPressed: () => context.push('/fair-price/recommendations'),
        ),
        IconButton(
          tooltip: _openedFromAcceptedDeal
              ? 'Reset to accepted deal'
              : 'Reset scenario',
          onPressed: (_isRunning || _isChatThinking) ? null : _resetScenario,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(
            eyebrow: 'M2 / FAIRPRICE',
            title: 'Measure before you negotiate.',
            description:
                'Pressure-test a proposed price against transparent marketplace evidence and trade terms.',
          ),
          if (_openedFromAcceptedDeal) ...[
            const SizedBox(height: 18),
            _AcceptedDealCard(deal: _deal!),
          ],
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedMaterial,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Material category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    helperText: _openedFromAcceptedDeal
                        ? 'Auto-selected from the accepted Marketplace deal.'
                        : null,
                  ),
                  items: _materials
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _isRunning
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedMaterial = value);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _product,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Specific product or material',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    helperText: _openedFromAcceptedDeal
                        ? 'Auto-filled from the accepted deal.'
                        : null,
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText:
                        'Quantity (${_deal?.unit.trim().isNotEmpty == true ? _deal!.unit : 'kg'})',
                    prefixIcon: const Icon(Icons.scale_outlined),
                    helperText: _openedFromAcceptedDeal
                        ? 'Auto-filled from the accepted deal.'
                        : null,
                  ),
                  validator: (value) => _positiveNumber(value, 'quantity'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Proposed RM/kg',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    helperText: _openedFromAcceptedDeal
                        ? (_deal!.askingPricePerKg != null
                              ? 'Pre-filled with the listing asking price. You can change it before analysis.'
                              : 'The listing had no asking price. Enter the price you want to test.')
                        : 'Enter the price you want FairPrice to test.',
                  ),
                  validator: (value) => _positiveNumber(value, 'price'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Material condition',
                        ),
                        items: _conditions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isRunning
                            ? null
                            : (value) => setState(
                                () => _condition = value ?? _condition,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _collection,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Collection terms',
                        ),
                        items: _collectionTerms
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isRunning
                            ? null
                            : (value) => setState(
                                () => _collection = value ?? _collection,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRunning ? null : _prepareNegotiation,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compare_arrows),
                    label: Text(
                      _isRunning
                          ? 'Loading live evidence…'
                          : 'Prepare negotiation',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SpecDivider(label: 'INDICATIVE REFERENCE'),
          const SizedBox(height: 14),
          _BenchmarkCard(benchmark: previewBenchmark),
          const SizedBox(height: 12),
          _MarketSignalsCard(
            commodity: _commoditySignal,
            materialIndex: _materialIndexSignal,
            ppi: _ppiSignal,
            localPrices: _localListingPrices,
            isLoading: _isLoadingMarketSignals,
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _PriceResultCard(
              result: _result!,
              isSaved: _isSaved,
              isEditing: _editingRecommendationId != null,
              isSaving: _isSaving,
              onSave: _saveRecommendation,
            ),
            const SizedBox(height: 24),
            const SpecDivider(label: 'CHAT WITH FAIRPRICE'),
            const SizedBox(height: 12),
            if (_chatMessages.isEmpty)
              const Text(
                'Ask about a counter-offer, buyer objection, quality evidence, or delivery terms.',
                style: TextStyle(color: AppColors.slate, height: 1.35),
              ),
            ..._chatMessages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChatBubble(text: message.text, isUser: message.isUser),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInput,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendChat(),
                    decoration: const InputDecoration(
                      hintText: 'Ask FairPrice about this deal…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _isChatThinking ? null : _sendChat,
                  icon: _isChatThinking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _EvidenceCard(links: _documentationLinks, onOpen: _openDocumentation),
        ],
      ),
    );
  }
}

class _AcceptedDealCard extends StatelessWidget {
  const _AcceptedDealCard({required this.deal});

  final DealRequestRecord deal;

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
                const Icon(Icons.check_circle_outline, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Accepted Marketplace deal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const StatusChip(label: 'ACCEPTED', color: AppColors.green),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Known deal details were loaded automatically. Review them before preparing the price analysis.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            _DealLine(label: 'Business', value: deal.owner),
            _DealLine(label: 'Material', value: deal.material),
            _DealLine(label: 'Quantity', value: deal.quantity),
            _DealLine(label: 'Location', value: deal.location),
            _DealLine(
              label: 'Asking price',
              value: deal.askingPricePerKg == null
                  ? 'Not provided in the listing'
                  : 'RM ${deal.askingPricePerKg!.toStringAsFixed(2)}/kg',
            ),
          ],
        ),
      ),
    );
  }
}

class _DealLine extends StatelessWidget {
  const _DealLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _BenchmarkCard extends StatelessWidget {
  const _BenchmarkCard({required this.benchmark});

  final _Benchmark benchmark;

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
                const Icon(Icons.insights_outlined, color: AppColors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benchmark.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              benchmark.isLiveEvidence
                  ? 'Live reference range: RM ${benchmark.low.toStringAsFixed(2)}–${benchmark.high.toStringAsFixed(2)}/kg'
                  : 'No numeric live reference range available',
              style: AppTheme.dataStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              benchmark.note,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketSignalsCard extends StatelessWidget {
  const _MarketSignalsCard({
    required this.commodity,
    required this.materialIndex,
    required this.ppi,
    required this.localPrices,
    required this.isLoading,
  });

  final CommodityPriceObservation? commodity;
  final PriceIndexObservation? materialIndex;
  final PriceIndexObservation? ppi;
  final List<LocalListingPrice> localPrices;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (commodity != null)
        '${commodity!.seriesName}: ${commodity!.currency} ${commodity!.value.toStringAsFixed(2)}',
      if (materialIndex != null)
        '${materialIndex!.series}: ${materialIndex!.indexValue.toStringAsFixed(1)} index points',
      if (ppi != null)
        'Malaysia PPI: ${ppi!.indexValue.toStringAsFixed(1)} index points',
      if (localPrices.isNotEmpty)
        '${localPrices.length} live local asking-price observation${localPrices.length == 1 ? '' : 's'}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.public_outlined,
                  color: AppColors.navy,
                  size: 20,
                ),
                const SizedBox(width: 9),
                const Expanded(child: Eyebrow('EXTERNAL MARKET SIGNALS')),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isLoading && lines.isEmpty)
              const Text(
                'No external or local signal is available for this material yet.',
                style: TextStyle(color: AppColors.slate),
              )
            else
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Context only: indexes and asking prices are not guaranteed quotes. Confirm material grade, logistics, and counterparty terms.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceResultCard extends StatelessWidget {
  const _PriceResultCard({
    required this.result,
    required this.isSaved,
    required this.isEditing,
    required this.isSaving,
    required this.onSave,
  });

  final _NegotiationResult result;
  final bool isSaved;
  final bool isEditing;
  final bool isSaving;
  final Future<void> Function() onSave;

  String _adjustmentLabel(double? value) {
    if (value == null || value == 0) return 'No adjustment';
    final sign = value > 0 ? '+' : '−';
    return '$sign RM ${value.abs().toStringAsFixed(2)}/kg';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.benchmark.isLiveEvidence
                  ? 'RECOMMENDED RANGE'
                  : 'LIVE PRICE EVIDENCE REQUIRED',
              style: AppTheme.eyebrowStyle.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.benchmark.isLiveEvidence
                  ? result.rangeLabel
                  : 'No numeric range yet',
              style: AppTheme.dataStyle.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
            if (result.benchmark.isLiveEvidence) ...[
              const SizedBox(height: 6),
              Text(
                'Suggested midpoint: RM ${result.target.toStringAsFixed(2)}/kg',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRICE CALCULATION',
                      style: AppTheme.eyebrowStyle.copyWith(
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Peer benchmark: RM ${result.benchmark.low.toStringAsFixed(2)}–${result.benchmark.high.toStringAsFixed(2)}/kg',
                      style: const TextStyle(color: AppColors.white),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Quantity (${result.quantity.toStringAsFixed(0)} kg): ${_adjustmentLabel(result.quantityAdjustment)}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Condition (${result.condition ?? 'Unspecified'}): floor ${_adjustmentLabel(result.conditionAdjustmentFloor)}, ceiling ${_adjustmentLabel(result.conditionAdjustmentCeiling)}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Collection (${result.collection ?? 'Unspecified'}): ${_adjustmentLabel(result.collectionAdjustment)}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Final range: ${result.rangeLabel}; midpoint RM ${result.target.toStringAsFixed(2)}/kg',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              result.strategy,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              result.adjustments.join(' '),
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (isSaved)
              const Text(
                'SAVED',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: isSaving ? null : onSave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.white),
                ),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(
                  isSaving
                      ? 'Saving…'
                      : isEditing
                      ? 'Update saved recommendation'
                      : 'Save recommendation',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.links, required this.onOpen});

  final List<(String, String, String)> links;
  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('EVIDENCE LIBRARY'),
            const SizedBox(height: 6),
            const Text(
              'Use the sources behind the price context to verify the evidence.',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            ...links.map(
              (link) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(link.$1),
                subtitle: Text(link.$2),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => onOpen(link.$3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
