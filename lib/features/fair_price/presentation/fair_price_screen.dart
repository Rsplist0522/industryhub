// M2 FairPrice for IndustryHub.
// Design intent: a transparent negotiation simulator with explicit
// inputs, explainable reference adjustments, and no claim of live market pricing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/services.dart';
import '../../../core/widgets.dart';
import '../../../core/validators.dart';
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

  String get rangeLabel =>
      'RM ${floor.toStringAsFixed(2)} — ${ceiling.toStringAsFixed(2)} / kg';
}

class _PriceChatLine {
  const _PriceChatLine(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class _AiNegotiationAdvice {
  const _AiNegotiationAdvice({
    required this.buyerMessage,
    required this.strategy,
    required this.counterOffer,
    required this.riskFlags,
    required this.sourceLabel,
  });

  final String buyerMessage;
  final String strategy;
  final double? counterOffer;
  final List<String> riskFlags;
  final String sourceLabel;
}

class FairPriceScreen extends ConsumerStatefulWidget {
  const FairPriceScreen({super.key});

  @override
  ConsumerState<FairPriceScreen> createState() => _FairPriceScreenState();
}

class _FairPriceScreenState extends ConsumerState<FairPriceScreen> {
  final _product = TextEditingController(text: 'Aluminium machining offcuts');
  final _price = TextEditingController(text: '48');
  final _quantity = TextEditingController(text: '500');
  final _formKey = GlobalKey<FormState>();
  final _messages = <String>[];
  final _chatInput = TextEditingController();
  final _chatMessages = <_PriceChatLine>[];

  bool _isRunning = false;
  bool _isChatThinking = false;
  bool _isSavingRecommendation = false;
  bool _isSaved = false;
  String _selectedMaterial = 'Aluminium';
  int _round = 0;
  String _condition = 'Sorted & dry';
  String _collection = 'Buyer collects';
  _NegotiationResult? _result;
  final _marketPriceRepository = MarketPriceRepository();
  final _aiService = const AiService();
  _AiNegotiationAdvice? _aiAdvice;
  CommodityPriceObservation? _commoditySignal;
  PriceIndexObservation? _materialIndexSignal;
  PriceIndexObservation? _ppiSignal;
  List<LocalListingPrice> _localListingPrices = const [];
  bool _isLoadingMarketSignals = true;

  static const _materials = [
    'Aluminium',
    'Copper',
    'Steel / iron',
    'Plastic / polymer',
    'Paper / cardboard',
    'Other material',
  ];
  static const _conditions = [
    'Mixed / unsorted',
    'Sorted & dry',
    'Verified grade',
  ];
  static const _collectionTerms = ['Buyer collects', 'Seller delivers'];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadMarketSignals(_product.text.trim()));
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
      final localListingPrices = await _marketPriceRepository
          .fetchLatestLocalListingPrices(product);
      if (!mounted) return;
      setState(() {
        _commoditySignal = commodity;
        _materialIndexSignal = materialIndex;
        _ppiSignal = ppi;
        _localListingPrices = localListingPrices;
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

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    _quantity.dispose();
    _chatInput.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isRunning) return;

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
      _round = 0;
      _result = result;
      _aiAdvice = null;
      _chatMessages.clear();
      _messages
        ..clear()
        ..add(
          'Your negotiation workspace is ready. The reference band below uses live Supabase asking-price evidence when comparable listings exist. Type your first message below to ask FairPrice for a buyer response, counter-offer strategy, or risk review.',
        );
    });
  }

  Future<void> _sendChat() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty || _isChatThinking) return;
    final result = _result;
    if (result == null) {
      setState(
        () => _chatMessages.add(
          const _PriceChatLine(
            'Run the negotiation first, then ask me about a counter-offer, buyer objection, quality evidence, or logistics terms.',
            false,
          ),
        ),
      );
      return;
    }

    _chatInput.clear();
    setState(() {
      _chatMessages.add(_PriceChatLine(text, true));
      _isChatThinking = true;
    });

    try {
      final response = await _aiService.callAI(
        'You are FairPrice, a negotiation assistant for Malaysian industrial SMEs. Continue the conversation using only the supplied scenario and transparent range. Never claim a live quote, never invent a buyer or supplier, and never guarantee a price. Return exactly these JSON keys: buyer_message, recommended_strategy, counter_offer_rm_per_kg (number or null), risk_flags (array of concise strings).',
        _followUpPrompt(result, text),
      );
      if (!mounted) return;
      final advice = _adviceFromAi(response, result);
      setState(() {
        _isChatThinking = false;
        _aiAdvice = advice;
        _round += 1;
        _chatMessages.add(
          _PriceChatLine(
            '${advice.buyerMessage} ${advice.counterOffer == null ? '' : 'Suggested position: RM ${advice.counterOffer!.toStringAsFixed(2)}/kg.'} ${advice.strategy} Source: ${advice.sourceLabel}.',
            false,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isChatThinking = false;
        _chatMessages.add(
          const _PriceChatLine(
            'I could not respond right now. Check the AI Edge Function configuration and try again.',
            false,
          ),
        );
      });
      debugPrint('FairPrice follow-up chat failed: $error');
    }
  }

  String _followUpPrompt(_NegotiationResult result, String message) {
    final history = _chatMessages
        .take(8)
        .map((line) => '${line.isUser ? 'User' : 'Assistant'}: ${line.text}')
        .join('\n');
    return '''
Scenario:
${_negotiationPrompt(result)}

Conversation:
$history

New user message:
$message
''';
  }

  String _negotiationPrompt(_NegotiationResult result) =>
      '''
Material: ${result.product}
Quantity: ${result.quantity.toStringAsFixed(2)} kg
Proposed price: RM ${result.proposedPrice.toStringAsFixed(2)}/kg
Band context: ${result.benchmark.isLiveEvidence ? 'Live comparable asking-price band RM ${result.floor.toStringAsFixed(2)}–${result.ceiling.toStringAsFixed(2)}/kg.' : 'No numeric band is available because no comparable live asking-price evidence was found. Do not invent a numeric counter-offer.'}
Condition: $_condition
Collection terms: $_collection
Reference adjustments: ${result.adjustments.join(' ')}
External context loaded: ${_materialIndexSignal?.series ?? 'No material-specific price index'}; Malaysia PPI ${_ppiSignal?.indexValue.toStringAsFixed(1) ?? 'unavailable'}; local Supabase listing observations ${_localListingPrices.length}.
''';

  _AiNegotiationAdvice _adviceFromAi(
    Map<String, dynamic> response,
    _NegotiationResult result,
  ) {
    final counter = response['counter_offer_rm_per_kg'];
    final rawCounterOffer = counter is num ? counter.toDouble() : null;
    final safeCounterOffer =
        result.benchmark.isLiveEvidence && rawCounterOffer != null
        ? rawCounterOffer.clamp(result.floor, result.ceiling).toDouble()
        : null;
    final riskFlags = response['risk_flags'];
    return _AiNegotiationAdvice(
      buyerMessage: _responseText(
        response['buyer_message'],
        'The offer should be discussed against the transparent reference band and the stated quality and logistics terms.',
      ),
      strategy: _responseText(
        response['recommended_strategy'],
        result.strategy,
      ),
      counterOffer: safeCounterOffer,
      riskFlags: riskFlags is List
          ? riskFlags.whereType<String>().take(4).toList()
          : const ['Confirm local grade and logistics before agreement'],
      sourceLabel: response['__source'] == 'ai'
          ? 'AI negotiation assistant'
          : 'AI response source unavailable.',
    );
  }

  String _responseText(dynamic value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

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
          'Publish or select a comparable live marketplace listing with an asking price before using a numeric negotiation range.',
        ],
        strategy:
            'No numeric recommendation is available yet. The entered RM price is only your negotiation anchor; FairPrice can still discuss quality, evidence, and logistics in the AI chat.',
      );
    }

    var floor = benchmark.low;
    var ceiling = benchmark.high;
    final adjustments = <String>[];

    if (quantity >= 1000) {
      floor -= 0.50;
      ceiling -= 0.50;
      adjustments.add(
        'Larger volume creates room for a modest buyer discount.',
      );
    } else if (quantity < 250) {
      floor += 0.50;
      ceiling += 0.50;
      adjustments.add(
        'Smaller volume supports a slightly higher handling allowance.',
      );
    } else {
      adjustments.add(
        'The quoted volume sits within the indicative reference band.',
      );
    }

    switch (_condition) {
      case 'Sorted & dry':
        floor += 0.50;
        ceiling += 0.75;
        adjustments.add(
          'Sorted, dry material strengthens your quality position.',
        );
      case 'Verified grade':
        floor += 1.00;
        ceiling += 1.50;
        adjustments.add(
          'Verified grade supports the strongest quality premium.',
        );
      default:
        adjustments.add(
          'Mixed material keeps the recommendation near the conservative end.',
        );
    }

    if (_collection == 'Seller delivers') {
      floor -= 0.75;
      ceiling -= 0.75;
      adjustments.add('Seller delivery absorbs part of the logistics cost.');
    } else {
      adjustments.add(
        'Buyer collection protects the offer from delivery-cost pressure.',
      );
    }

    floor = _roundToFiftySen(floor);
    ceiling = _roundToFiftySen(ceiling);
    final target = _roundToFiftySen((floor + ceiling) / 2);

    final strategy = proposedPrice < floor
        ? 'Your proposed price is below the recommended floor. Open at RM ${target.toStringAsFixed(2)}/kg and avoid accepting below RM ${floor.toStringAsFixed(2)}/kg unless the terms improve.'
        : proposedPrice > ceiling
        ? 'Your proposed price is above the recommended ceiling. Lead with your quality evidence, but prepare to settle near RM ${target.toStringAsFixed(2)}/kg.'
        : 'Your proposed price is inside the recommended range. Open at RM ${target.toStringAsFixed(2)}/kg and use collection and quality terms to protect the floor.';

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
    );
  }

  _Benchmark _benchmarkFor(String product, double proposedPrice) {
    final prices =
        _localListingPrices
            .map((listing) => listing.pricePerKg)
            .where((price) => price > 0)
            .toList()
          ..sort();
    if (prices.isEmpty) {
      return _Benchmark(
        label: 'No live local benchmark loaded',
        low: proposedPrice,
        high: proposedPrice,
        note:
            'No comparable Supabase listing has published an asking price for this material. The entered price is a negotiation anchor, not a market quote.',
        isLiveEvidence: false,
      );
    }

    return _Benchmark(
      label: 'Live Supabase comparable listings',
      low: prices.first,
      high: prices.last,
      note:
          'Based on ${prices.length} published asking-price observation${prices.length == 1 ? '' : 's'} in the live marketplace. Confirm grade, quantity, and logistics before agreement.',
      isLiveEvidence: true,
    );
  }

  double _roundToFiftySen(double value) => (value * 2).round() / 2;

  Future<void> _saveRecommendation() async {
    final result = _result;
    if (result == null || _isSaved || _isSavingRecommendation) return;

    setState(() => _isSavingRecommendation = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .saveNegotiation(
            product: result.product,
            quantity: result.quantity,
            proposedPrice: result.proposedPrice,
            floorPrice: result.floor,
            targetPrice: result.target,
            ceilingPrice: result.ceiling,
            condition: _condition,
            collectionTerms: _collection,
            strategy: result.strategy,
            hasLiveEvidence: result.benchmark.isLiveEvidence,
          );
      if (!mounted) return;
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price recommendation saved to your profile.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Price recommendation could not be saved. Please check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingRecommendation = false);
    }
  }

  void _resetScenario() {
    if (_isRunning) return;
    _selectedMaterial = 'Aluminium';
    _product.text = 'Aluminium machining offcuts';
    _price.text = '48';
    _quantity.text = '500';
    setState(() {
      _condition = 'Sorted & dry';
      _collection = 'Buyer collects';
      _round = 0;
      _isSaved = false;
      _result = null;
      _aiAdvice = null;
      _chatMessages.clear();
      _messages.clear();
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  String? _requiredText(String? value) =>
      validateRequiredText(value, label: 'a material or product name');

  String? _positiveNumber(String? value, String fieldName) =>
      validatePositiveNumber(value, label: fieldName);

  @override
  Widget build(BuildContext context) {
    final previewBenchmark = _benchmarkFor(
      _product.text.trim(),
      double.tryParse(_price.text.trim()) ?? 0,
    );
    final liveMaterials = ref
        .watch(appStateProvider)
        .listings
        .map((listing) => listing.material.trim())
        .where((material) => material.isNotEmpty)
        .toSet();
    final materialOptions = [
      ..._materials,
      ...liveMaterials.where((material) => !_materials.contains(material)),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: _goBack,
        ),
        title: const Text('FairPrice Advisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset scenario',
            onPressed: (_isRunning || _isChatThinking) ? null : _resetScenario,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(
            eyebrow: 'M2 / FAIRPRICE',
            title: 'Measure before you negotiate.',
            description:
                'Give the simulator a product, volume, offer, and trade terms. It pressure-tests the offer against a transparent indicative reference.',
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Choose a material category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: materialOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _isRunning
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedMaterial = value;
                            if (value != 'Other material') {
                              _product.text = value;
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _product,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Specific product or material',
                    hintText: 'For example: 6061 aluminium machining offcuts',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity (kg)',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        validator: (value) =>
                            _positiveNumber(value, 'quantity'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Proposed RM/kg',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) => _positiveNumber(value, 'price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition,
                        decoration: const InputDecoration(
                          labelText: 'Material condition',
                        ),
                        items: _conditions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
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
                        decoration: const InputDecoration(
                          labelText: 'Collection terms',
                        ),
                        items: _collectionTerms
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
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
                    onPressed: _isRunning ? null : _start,
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(
                      _isRunning
                          ? 'Loading live market evidence…'
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
          if (_isLoadingMarketSignals ||
              _commoditySignal != null ||
              _materialIndexSignal != null ||
              _ppiSignal != null ||
              _localListingPrices.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MarketSignalCard(
              commodity: _commoditySignal,
              materialIndex: _materialIndexSignal,
              ppi: _ppiSignal,
              localListingPrices: _localListingPrices,
              isLoading: _isLoadingMarketSignals,
            ),
          ],
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SpecDivider(label: 'NEGOTIATION LOG'),
            const SizedBox(height: 14),
            ..._messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChatBubble(text: message, isUser: false),
              ),
            ),
            Row(
              children: [
                StatusChip(
                  label: _round == 0
                      ? 'AWAITING YOUR MESSAGE'
                      : 'USER TURN $_round',
                  color: _round == 0 ? AppColors.amber : AppColors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _result == null
                      ? 'Prepare the scenario first'
                      : 'Chat is user-driven',
                  style: const TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _PriceResult(
              result: _result!,
              advice: _aiAdvice,
              isSaved: _isSaved,
              isSaving: _isSavingRecommendation,
              onSave: _saveRecommendation,
            ),
            const SizedBox(height: 24),
            const SpecDivider(label: 'CHAT WITH FAIRPRICE'),
            const SizedBox(height: 12),
            if (_chatMessages.isEmpty)
              const Text(
                'Ask the AI about a counter-offer, buyer objection, quality evidence, or delivery terms.',
                style: TextStyle(color: AppColors.slate, height: 1.35),
              ),
            ..._chatMessages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChatBubble(text: message.text, isUser: message.isUser),
              ),
            ),
            _FairPriceComposer(
              controller: _chatInput,
              onSend: _sendChat,
              isThinking: _isChatThinking,
            ),
          ],
        ],
      ),
    );
  }
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
            const SizedBox(height: 12),
            Text(
              benchmark.isLiveEvidence
                  ? 'Live reference range: RM ${benchmark.low.toStringAsFixed(2)}–${benchmark.high.toStringAsFixed(2)}/kg'
                  : 'No numeric reference range available',
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
            const SizedBox(height: 10),
            Text(
              benchmark.isLiveEvidence
                  ? 'Live Supabase listing evidence — not a guaranteed Malaysian market quote.'
                  : 'No live local benchmark is available — the entered price is only a negotiation anchor.',
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketSignalCard extends StatelessWidget {
  const _MarketSignalCard({
    required this.commodity,
    required this.materialIndex,
    required this.ppi,
    required this.localListingPrices,
    required this.isLoading,
  });

  final CommodityPriceObservation? commodity;
  final PriceIndexObservation? materialIndex;
  final PriceIndexObservation? ppi;
  final List<LocalListingPrice> localListingPrices;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    'EXTERNAL MARKET SIGNALS',
                    style: AppTheme.eyebrowStyle,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (commodity != null)
              _MarketSignalLine(
                label: commodity!.seriesName,
                value:
                    '${commodity!.currency} ${commodity!.value.toStringAsFixed(2)} / ${commodity!.unit.split('/').last}',
                detail:
                    '${commodity!.sourceName} · ${_formatMonth(commodity!.observedOn)}',
              ),
            if (materialIndex != null) ...[
              if (commodity != null) const SizedBox(height: 9),
              _MarketSignalLine(
                label: materialIndex!.series,
                value:
                    '${materialIndex!.indexValue.toStringAsFixed(1)} index points',
                detail:
                    '${materialIndex!.sourceName} · base ${materialIndex!.baseYear} · ${_formatMonth(materialIndex!.observedOn)}',
              ),
            ],
            if (ppi != null) ...[
              if (commodity != null || materialIndex != null)
                const SizedBox(height: 9),
              _MarketSignalLine(
                label: 'Malaysia PPI',
                value: '${ppi!.indexValue.toStringAsFixed(1)} index points',
                detail:
                    'DOSM · base ${ppi!.baseYear} · ${_formatMonth(ppi!.observedOn)}',
              ),
            ],
            if (localListingPrices.isNotEmpty) ...[
              if (commodity != null || materialIndex != null || ppi != null)
                const SizedBox(height: 9),
              _MarketSignalLine(
                label: 'Local marketplace asking prices',
                value: '${localListingPrices.length} observations',
                detail:
                    'Live Supabase listings · used for the negotiation band',
              ),
            ],
            if (!isLoading &&
                commodity == null &&
                materialIndex == null &&
                ppi == null &&
                localListingPrices.isEmpty)
              const Text(
                'No external or local listing signal is available for this material yet.',
                style: TextStyle(color: AppColors.slate, height: 1.35),
              ),
            const SizedBox(height: 10),
            const Text(
              'Context only: indexes and marketplace asking prices are not guaranteed local quotes. Confirm grade, currency, logistics, and counterparty terms before agreeing a price.',
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

  String _formatMonth(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

class _MarketSignalLine extends StatelessWidget {
  const _MarketSignalLine({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(color: AppColors.slate, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _FairPriceComposer extends StatelessWidget {
  const _FairPriceComposer({
    required this.controller,
    required this.onSend,
    required this.isThinking,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'e.g. The buyer says the material is too wet…',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send message to FairPrice',
            onPressed: isThinking ? null : onSend,
            icon: isThinking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
          ),
        ],
      ),
    );
  }
}

class _PriceResult extends StatelessWidget {
  const _PriceResult({
    required this.result,
    required this.advice,
    required this.isSaved,
    required this.isSaving,
    required this.onSave,
  });

  final _NegotiationResult result;
  final _AiNegotiationAdvice? advice;
  final bool isSaved;
  final bool isSaving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.benchmark.isLiveEvidence
                  ? 'RECOMMENDED RANGE'
                  : 'LIVE PRICE EVIDENCE REQUIRED',
              style: AppTheme.eyebrowStyle.copyWith(
                color: AppColors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 8),
            if (result.benchmark.isLiveEvidence) ...[
              Text(
                result.rangeLabel,
                style: AppTheme.dataStyle.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Suggested opening point: RM ${result.target.toStringAsFixed(2)}/kg',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              _RangeLine(
                floor: result.floor,
                target: result.target,
                ceiling: result.ceiling,
              ),
            ] else ...[
              Text(
                'No numeric range yet',
                style: AppTheme.dataStyle.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entered price anchor: RM ${result.proposedPrice.toStringAsFixed(2)}/kg',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a comparable marketplace asking price to unlock a numeric range.',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 15),
            Text(
              result.strategy,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
            if (advice != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI NEGOTIATION GUIDANCE',
                      style: AppTheme.eyebrowStyle.copyWith(
                        color: AppColors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advice!.buyerMessage,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                    if (advice!.counterOffer != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suggested counter-position: RM ${advice!.counterOffer!.toStringAsFixed(2)}/kg',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Strategy: ${advice!.strategy}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                    if (advice!.riskFlags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Checks: ${advice!.riskFlags.join(' · ')}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Source: ${advice!.sourceLabel}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Basis: ${result.product} · ${result.quantity.toStringAsFixed(0)} kg · ${result.benchmark.label}',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.66),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 15),
            isSaved
                ? const Text(
                    'SAVED FOR THIS SESSION',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            onSave();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(isSaving ? 'Saving…' : 'Save recommendation'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RangeLine extends StatelessWidget {
  const _RangeLine({
    required this.floor,
    required this.target,
    required this.ceiling,
  });

  final double floor;
  final double target;
  final double ceiling;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'RM ${floor.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.72),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              'RM ${target.toStringAsFixed(2)} target',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'RM ${ceiling.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.72),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 2, height: 16, color: AppColors.white),
            Expanded(
              child: Container(
                height: 2,
                color: AppColors.white.withValues(alpha: 0.76),
              ),
            ),
            Container(width: 3, height: 14, color: AppColors.amber),
            Expanded(
              child: Container(
                height: 2,
                color: AppColors.white.withValues(alpha: 0.76),
              ),
            ),
            Container(width: 2, height: 16, color: AppColors.white),
          ],
        ),
      ],
    );
  }
}
