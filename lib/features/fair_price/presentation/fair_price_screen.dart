// M2 FairPrice for IndustryHub.
// Design intent: a transparent negotiation simulator with explicit
// inputs, explainable reference adjustments, and no claim of live market pricing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';
import '../data/market_price_repository.dart';

class _Benchmark {
  const _Benchmark({required this.label, required this.low, required this.high, required this.note});

  final String label;
  final double low;
  final double high;
  final String note;

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

  String get rangeLabel => 'RM ${floor.toStringAsFixed(2)} — ${ceiling.toStringAsFixed(2)} / kg';
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

  bool _isRunning = false;
  bool _isSaved = false;
  int _round = 0;
  String _condition = 'Sorted & dry';
  String _collection = 'Buyer collects';
  _NegotiationResult? _result;
  final _marketPriceRepository = MarketPriceRepository();
  CommodityPriceObservation? _commoditySignal;
  PriceIndexObservation? _ppiSignal;
  bool _isLoadingMarketSignals = true;

  static const _conditions = ['Mixed / unsorted', 'Sorted & dry', 'Verified grade'];
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
      final commodity = await _marketPriceRepository.fetchLatestCommodity(product);
      final ppi = await _marketPriceRepository.fetchLatestMalaysiaPpi();
      if (!mounted) return;
      setState(() {
        _commoditySignal = commodity;
        _ppiSignal = ppi;
        _isLoadingMarketSignals = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _commoditySignal = null;
        _ppiSignal = null;
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
      _isRunning = true;
      _isSaved = false;
      _round = 1;
      _result = null;
      _messages
        ..clear()
        ..add(
          'Round 1 / Reference check: ${result.benchmark.label} is using an indicative in-app reference of RM ${result.benchmark.low.toStringAsFixed(2)}–${result.benchmark.high.toStringAsFixed(2)}/kg. Your offer is RM ${proposedPrice.toStringAsFixed(2)}/kg for ${quantity.toStringAsFixed(0)} kg.',
        );
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _round = 2;
      _messages.add(
        'Round 2 / Buyer response: ${_condition.toLowerCase()} material with ${_collection.toLowerCase()} changes the negotiation position. ${result.adjustments.join(' ')}',
      );
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _round = 3;
      _isRunning = false;
      _result = result;
      _messages.add('Round 3 / Recommendation: ${result.strategy}');
    });
  }

  _NegotiationResult _calculateResult({
    required String product,
    required double quantity,
    required double proposedPrice,
  }) {
    final benchmark = _benchmarkFor(product);
    var floor = benchmark.low;
    var ceiling = benchmark.high;
    final adjustments = <String>[];

    if (quantity >= 1000) {
      floor -= 0.50;
      ceiling -= 0.50;
      adjustments.add('Larger volume creates room for a modest buyer discount.');
    } else if (quantity < 250) {
      floor += 0.50;
      ceiling += 0.50;
      adjustments.add('Smaller volume supports a slightly higher handling allowance.');
    } else {
      adjustments.add('The quoted volume sits within the indicative reference band.');
    }

    switch (_condition) {
      case 'Sorted & dry':
        floor += 0.50;
        ceiling += 0.75;
        adjustments.add('Sorted, dry material strengthens your quality position.');
      case 'Verified grade':
        floor += 1.00;
        ceiling += 1.50;
        adjustments.add('Verified grade supports the strongest quality premium.');
      default:
        adjustments.add('Mixed material keeps the recommendation near the conservative end.');
    }

    if (_collection == 'Seller delivers') {
      floor -= 0.75;
      ceiling -= 0.75;
      adjustments.add('Seller delivery absorbs part of the logistics cost.');
    } else {
      adjustments.add('Buyer collection protects the offer from delivery-cost pressure.');
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

  _Benchmark _benchmarkFor(String product) {
    final lower = product.toLowerCase();
    if (lower.contains('copper')) {
      return const _Benchmark(
        label: 'Copper-bearing material / indicative reference',
        low: 24.00,
        high: 32.00,
        note: 'Use only as a demonstration reference; cable grade and contamination materially change value.',
      );
    }
    if (lower.contains('steel') || lower.contains('iron')) {
      return const _Benchmark(
        label: 'Ferrous offcuts / indicative reference',
        low: 0.90,
        high: 1.70,
        note: 'Use only as a demonstration reference; grade, preparation, and collection costs matter.',
      );
    }
    if (lower.contains('plastic') || lower.contains('polymer')) {
      return const _Benchmark(
        label: 'Recyclable plastic / indicative reference',
        low: 0.70,
        high: 1.40,
        note: 'Use only as a demonstration reference; resin type and contamination materially change value.',
      );
    }
    if (lower.contains('aluminium') || lower.contains('aluminum')) {
      return const _Benchmark(
        label: 'Aluminium machining offcuts / indicative reference',
        low: 42.00,
        high: 55.00,
        note: 'Use only as a demonstration reference; alloy, moisture, and collection terms change value.',
      );
    }
    return const _Benchmark(
      label: 'General industrial material / indicative reference',
      low: 18.00,
      high: 28.00,
      note: 'Use only as a demonstration reference until an approved material-specific benchmark is connected.',
    );
  }

  double _roundToFiftySen(double value) => (value * 2).round() / 2;

  void _saveRecommendation() {
    if (_result == null) return;
    if (_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This recommendation is already saved for this session.')));
      return;
    }

    setState(() => _isSaved = true);
    ref.read(appStateProvider.notifier).startNegotiation();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price recommendation saved to your profile.')));
  }

  void _resetScenario() {
    if (_isRunning) return;
    _product.text = 'Aluminium machining offcuts';
    _price.text = '48';
    _quantity.text = '500';
    setState(() {
      _condition = 'Sorted & dry';
      _collection = 'Buyer collects';
      _round = 0;
      _isSaved = false;
      _result = null;
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

  String? _requiredText(String? value) => value == null || value.trim().isEmpty ? 'Enter a material or product name.' : null;

  String? _positiveNumber(String? value, String fieldName) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return 'Enter a valid $fieldName above zero.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final previewBenchmark = _benchmarkFor(_product.text.trim());

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
            onPressed: _isRunning ? null : _resetScenario,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(
            eyebrow: 'M2 / FAIRPRICE',
            title: 'Measure before you negotiate.',
            description: 'Give the simulator a product, volume, offer, and trade terms. It pressure-tests the offer against a transparent indicative reference.',
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _product,
                  decoration: const InputDecoration(labelText: 'Product or material', prefixIcon: Icon(Icons.inventory_2_outlined)),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantity (kg)', prefixIcon: Icon(Icons.scale_outlined)),
                        validator: (value) => _positiveNumber(value, 'quantity'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Proposed RM/kg', prefixIcon: Icon(Icons.payments_outlined)),
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
                        decoration: const InputDecoration(labelText: 'Material condition'),
                        items: _conditions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                        onChanged: _isRunning ? null : (value) => setState(() => _condition = value ?? _condition),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _collection,
                        decoration: const InputDecoration(labelText: 'Collection terms'),
                        items: _collectionTerms.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                        onChanged: _isRunning ? null : (value) => setState(() => _collection = value ?? _collection),
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
                    label: Text(_isRunning ? 'Simulating buyer response…' : 'Run negotiation'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SpecDivider(label: 'INDICATIVE REFERENCE'),
          const SizedBox(height: 14),
          _BenchmarkCard(benchmark: previewBenchmark),
          if (_isLoadingMarketSignals || _commoditySignal != null || _ppiSignal != null) ...[
            const SizedBox(height: 12),
            _MarketSignalCard(
              commodity: _commoditySignal,
              ppi: _ppiSignal,
              isLoading: _isLoadingMarketSignals,
            ),
          ],
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SpecDivider(label: 'NEGOTIATION LOG'),
            const SizedBox(height: 14),
            ..._messages.map((message) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ChatBubble(text: message, isUser: false))),
            Row(
              children: [
                StatusChip(label: 'ROUND $_round / 3', color: _result == null ? AppColors.amber : AppColors.green),
                const SizedBox(width: 8),
                Text(_result == null ? 'Buyer persona active' : 'Recommendation ready', style: const TextStyle(color: AppColors.slate)),
              ],
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _PriceResult(result: _result!, isSaved: _isSaved, onSave: _saveRecommendation),
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
                Expanded(child: Text(benchmark.label, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Reference range: RM ${benchmark.low.toStringAsFixed(2)}–${benchmark.high.toStringAsFixed(2)}/kg', style: AppTheme.dataStyle.copyWith(fontSize: 14)),
            const SizedBox(height: 5),
            Text(benchmark.note, style: const TextStyle(color: AppColors.slate, fontSize: 12, height: 1.35)),
            const SizedBox(height: 10),
            const Text('Indicative in-app reference only — not a live Malaysian market quote.', style: TextStyle(color: AppColors.slate, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MarketSignalCard extends StatelessWidget {
  const _MarketSignalCard({required this.commodity, required this.ppi, required this.isLoading});

  final CommodityPriceObservation? commodity;
  final PriceIndexObservation? ppi;
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
                const Icon(Icons.public_outlined, color: AppColors.navy, size: 20),
                const SizedBox(width: 9),
                Expanded(child: Text('EXTERNAL MARKET SIGNALS', style: AppTheme.eyebrowStyle)),
                if (isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 10),
            if (commodity != null)
              _MarketSignalLine(
                label: commodity!.seriesName,
                value: '${commodity!.currency} ${commodity!.value.toStringAsFixed(2)} / ${commodity!.unit.split('/').last}',
                detail: 'World Bank Pink Sheet · ${_formatMonth(commodity!.observedOn)}',
              ),
            if (ppi != null) ...[
              if (commodity != null) const SizedBox(height: 9),
              _MarketSignalLine(
                label: 'Malaysia PPI',
                value: '${ppi!.indexValue.toStringAsFixed(1)} index points',
                detail: 'DOSM · base ${ppi!.baseYear} · ${_formatMonth(ppi!.observedOn)}',
              ),
            ],
            if (!isLoading && commodity == null && ppi == null)
              const Text('No external signal is available for this material yet.', style: TextStyle(color: AppColors.slate, height: 1.35)),
            const SizedBox(height: 10),
            const Text('Context only: global commodity data and the Malaysian PPI are not direct local scrap quotes. Confirm grade, currency, logistics, and counterparty terms before agreeing a price.', style: TextStyle(color: AppColors.slate, fontSize: 11, height: 1.35)),
          ],
        ),
      ),
    );
  }

  String _formatMonth(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

class _MarketSignalLine extends StatelessWidget {
  const _MarketSignalLine({required this.label, required this.value, required this.detail});

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
              Text(detail, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: AppTheme.dataStyle.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _PriceResult extends StatelessWidget {
  const _PriceResult({required this.result, required this.isSaved, required this.onSave});

  final _NegotiationResult result;
  final bool isSaved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECOMMENDED RANGE', style: AppTheme.eyebrowStyle.copyWith(color: AppColors.white.withValues(alpha: 0.65))),
            const SizedBox(height: 8),
            Text(result.rangeLabel, style: AppTheme.dataStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.white)),
            const SizedBox(height: 8),
            Text('Suggested opening point: RM ${result.target.toStringAsFixed(2)}/kg', style: TextStyle(color: AppColors.white.withValues(alpha: 0.86), fontSize: 13)),
            const SizedBox(height: 14),
            _RangeLine(floor: result.floor, target: result.target, ceiling: result.ceiling),
            const SizedBox(height: 15),
            Text(result.strategy, style: TextStyle(color: AppColors.white.withValues(alpha: 0.88), height: 1.4)),
            const SizedBox(height: 12),
            Text('Basis: ${result.product} · ${result.quantity.toStringAsFixed(0)} kg · ${result.benchmark.label}', style: TextStyle(color: AppColors.white.withValues(alpha: 0.66), fontSize: 11, height: 1.35)),
            const SizedBox(height: 15),
            isSaved
                ? const Text('SAVED FOR THIS SESSION', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 12))
                : OutlinedButton.icon(
                    onPressed: onSave,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.white, side: const BorderSide(color: AppColors.white)),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Save recommendation'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RangeLine extends StatelessWidget {
  const _RangeLine({required this.floor, required this.target, required this.ceiling});

  final double floor;
  final double target;
  final double ceiling;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('RM ${floor.toStringAsFixed(2)}', style: TextStyle(color: AppColors.white.withValues(alpha: 0.72), fontSize: 11)),
            const Spacer(),
            Text('RM ${target.toStringAsFixed(2)} target', style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('RM ${ceiling.toStringAsFixed(2)}', style: TextStyle(color: AppColors.white.withValues(alpha: 0.72), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 2, height: 16, color: AppColors.white),
            Expanded(child: Container(height: 2, color: AppColors.white.withValues(alpha: 0.76))),
            Container(width: 3, height: 14, color: AppColors.amber),
            Expanded(child: Container(height: 2, color: AppColors.white.withValues(alpha: 0.76))),
            Container(width: 2, height: 16, color: AppColors.white),
          ],
        ),
      ],
    );
  }
}
