import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

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
  bool _isRunning = false;
  bool _hasResult = false;
  int _round = 0;
  final _messages = <String>[];

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isRunning = true;
      _hasResult = false;
      _round = 1;
      _messages
        ..clear()
        ..add('Buyer benchmark: comparable aluminium offcuts are trading around RM 42–55/kg in Selangor. Your proposal is within range, but collection terms matter.');
    });
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _round = 3;
      _hasResult = true;
      _messages.add('The buyer persona has completed three rounds. The recommended range balances your material quality, volume, and the benchmark midpoint.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Advisor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const PageIntro(
            eyebrow: 'M2 / FAIRPRICE',
            title: 'Measure before you negotiate.',
            description: 'Give the simulator a product, volume, and proposed price. It uses a local benchmark to pressure-test the offer.',
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(controller: _product, decoration: const InputDecoration(labelText: 'Product or material', prefixIcon: Icon(Icons.inventory_2_outlined)), validator: _required),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: TextFormField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (kg)'), validator: _required)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Proposed RM/kg'), validator: _required))]),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _isRunning ? null : _start, icon: const Icon(Icons.compare_arrows), label: Text(_isRunning ? 'Negotiating…' : 'Run negotiation'))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SpecDivider(label: 'BENCHMARK / SELANGOR'),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [const Icon(Icons.insights_outlined, color: AppColors.amber), const SizedBox(width: 12), Expanded(child: Text('Reference midpoint: RM 48.50/kg\nComparable range: RM 42–55/kg', style: AppTheme.dataStyle.copyWith(fontSize: 14)))]),
            ),
          ),
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SpecDivider(label: 'NEGOTIATION LOG'),
            const SizedBox(height: 14),
            ..._messages.map((message) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ChatBubble(text: message, isUser: false))),
            Row(children: [StatusChip(label: 'ROUND $_round / 3', color: _hasResult ? AppColors.green : AppColors.amber), const SizedBox(width: 8), Text(_hasResult ? 'Complete' : 'Buyer persona active', style: const TextStyle(color: AppColors.slate))]),
          ],
          if (_hasResult) ...[
            const SizedBox(height: 24),
            _PriceResult(onSave: () { ref.read(appStateProvider.notifier).startNegotiation(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price recommendation saved to profile.'))); }),
          ],
        ],
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}

class _PriceResult extends StatelessWidget {
  const _PriceResult({required this.onSave});
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
            Text('RM 45 — 52', style: GoogleFonts.archivo(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.white)),
            const SizedBox(height: 12),
            Row(children: [const SizedBox(width: 2, height: 18, child: VerticalDivider(width: 1, color: AppColors.white)), Expanded(child: Container(height: 1, color: AppColors.white.withValues(alpha: 0.75))), Container(width: 2, height: 8, color: AppColors.amber), Expanded(child: Container(height: 1, color: AppColors.white.withValues(alpha: 0.75))), const SizedBox(width: 2, height: 18, child: VerticalDivider(width: 1, color: AppColors.white))]),
            const SizedBox(height: 15),
            Text('The strongest position is RM 49/kg when the buyer collects. Hold the upper end when the material is sorted and dry.', style: TextStyle(color: AppColors.white.withValues(alpha: 0.84), height: 1.4)),
            const SizedBox(height: 15),
            OutlinedButton(onPressed: onSave, style: OutlinedButton.styleFrom(foregroundColor: AppColors.white, side: const BorderSide(color: AppColors.white)), child: const Text('Save recommendation')),
          ],
        ),
      ),
    );
  }
}

// Kept local to avoid introducing a second typography dependency into the result card's layout.
class GoogleFonts {
  static TextStyle archivo({double? fontSize, FontWeight? fontWeight, Color? color}) => TextStyle(fontFamily: 'Archivo', fontSize: fontSize, fontWeight: fontWeight, color: color);
}
