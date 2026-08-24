import 'package:supabase_flutter/supabase_flutter.dart';

class CommodityPriceObservation {
  const CommodityPriceObservation({
    required this.seriesName,
    required this.observedOn,
    required this.value,
    required this.unit,
    required this.currency,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String seriesName;
  final DateTime observedOn;
  final double value;
  final String unit;
  final String currency;
  final String sourceName;
  final String sourceUrl;

  factory CommodityPriceObservation.fromSupabase(Map<String, dynamic> data) => CommodityPriceObservation(
        seriesName: data['series_name'] as String? ?? 'Commodity signal',
        observedOn: DateTime.tryParse(data['observed_on'] as String? ?? '') ?? DateTime.now(),
        value: (data['value'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] as String? ?? 'source unit',
        currency: data['currency'] as String? ?? 'USD',
        sourceName: data['source_name'] as String? ?? 'External commodity source',
        sourceUrl: data['source_url'] as String? ?? '',
      );
}

class PriceIndexObservation {
  const PriceIndexObservation({
    required this.series,
    required this.observedOn,
    required this.indexValue,
    required this.baseYear,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String series;
  final DateTime observedOn;
  final double indexValue;
  final int baseYear;
  final String sourceName;
  final String sourceUrl;

  factory PriceIndexObservation.fromSupabase(Map<String, dynamic> data) => PriceIndexObservation(
        series: data['series'] as String? ?? 'External price index',
        observedOn: DateTime.tryParse(data['observed_on'] as String? ?? '') ?? DateTime.now(),
        indexValue: (data['index_value'] as num?)?.toDouble() ?? 0,
        baseYear: (data['base_year'] as num?)?.toInt() ?? 2010,
        sourceName: data['source_name'] as String? ?? 'External price index',
        sourceUrl: data['source_url'] as String? ?? '',
      );
}

class LocalListingPrice {
  const LocalListingPrice({
    required this.material,
    required this.pricePerKg,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.observedOn,
  });

  final String material;
  final double pricePerKg;
  final double quantity;
  final String unit;
  final String location;
  final DateTime observedOn;

  factory LocalListingPrice.fromSupabase(Map<String, dynamic> data) => LocalListingPrice(
        material: data['material'] as String? ?? 'Material',
        pricePerKg: (data['asking_price_per_kg'] as num?)?.toDouble() ?? 0,
        quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] as String? ?? 'kg',
        location: data['location'] as String? ?? 'Malaysia',
        observedOn: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class MarketPriceRepository {
  MarketPriceRepository({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<CommodityPriceObservation?> fetchLatestCommodity(String product) async {
    final series = _seriesFor(product);
    if (series == null) return null;

    final rows = await _supabase
        .from('commodity_price_observations')
        .select()
        .eq('series_name', series)
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return CommodityPriceObservation.fromSupabase(Map<String, dynamic>.from(rows.first));
  }

  Future<PriceIndexObservation?> fetchLatestMaterialIndex(String product) async {
    final datasetId = _fredDatasetFor(product);
    if (datasetId == null) return null;

    final rows = await _supabase
        .from('price_index_observations')
        .select()
        .eq('dataset_id', datasetId)
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return PriceIndexObservation.fromSupabase(Map<String, dynamic>.from(rows.first));
  }

  Future<PriceIndexObservation?> fetchLatestMalaysiaPpi() async {
    final rows = await _supabase
        .from('price_index_observations')
        .select()
        .eq('dataset_id', 'ppi')
        .eq('series', 'abs')
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return PriceIndexObservation.fromSupabase(Map<String, dynamic>.from(rows.first));
  }

  Future<List<LocalListingPrice>> fetchLatestLocalListingPrices(String product) async {
    final query = product.trim();
    if (query.isEmpty) return const [];
    final rows = await _supabase
        .from('listings')
        .select('material, asking_price_per_kg, quantity, unit, location, created_at')
        .ilike('material', '%$query%')
        .not('asking_price_per_kg', 'is', null)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => LocalListingPrice.fromSupabase(Map<String, dynamic>.from(row as Map)))
        .where((listing) => listing.pricePerKg > 0)
        .toList();
  }

  String? _fredDatasetFor(String product) {
    final lower = product.toLowerCase();
    if (lower.contains('aluminium') || lower.contains('aluminum')) return 'fred_WPU102402';
    if (lower.contains('copper')) return 'fred_WPU102301';
    if (lower.contains('iron') || lower.contains('steel') || lower.contains('ferrous')) return 'fred_WPU1012';
    return null;
  }

  String? _seriesFor(String product) {
    final lower = product.toLowerCase();
    if (lower.contains('aluminium') || lower.contains('aluminum')) return 'Aluminum';
    if (lower.contains('copper')) return 'Copper';
    if (lower.contains('iron') || lower.contains('steel') || lower.contains('ferrous')) return 'Iron ore, cfr spot';
    return null;
  }
}
