import 'dart:convert';

import 'package:http/http.dart' as http;
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

  factory CommodityPriceObservation.fromSupabase(Map<String, dynamic> data) =>
      CommodityPriceObservation(
        seriesName: data['series_name'] as String? ?? 'Commodity signal',
        observedOn:
            DateTime.tryParse(data['observed_on'] as String? ?? '') ??
            DateTime.now(),
        value: (data['value'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] as String? ?? 'source unit',
        currency: data['currency'] as String? ?? 'USD',
        sourceName:
            data['source_name'] as String? ?? 'External commodity source',
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

  factory PriceIndexObservation.fromSupabase(Map<String, dynamic> data) =>
      PriceIndexObservation(
        series: data['series'] as String? ?? 'External price index',
        observedOn:
            DateTime.tryParse(data['observed_on'] as String? ?? '') ??
            DateTime.now(),
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
    this.ownerId = '',
  });

  final String material;
  final double pricePerKg;
  final double quantity;
  final String unit;
  final String location;
  final DateTime observedOn;
  final String ownerId;

  factory LocalListingPrice.fromSupabase(Map<String, dynamic> data) =>
      LocalListingPrice(
        material: data['material'] as String? ?? 'Material',
        pricePerKg: (data['asking_price_per_kg'] as num?)?.toDouble() ?? 0,
        quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] as String? ?? 'kg',
        location: data['location'] as String? ?? 'Malaysia',
        observedOn:
            DateTime.tryParse(data['created_at'] as String? ?? '') ??
            DateTime.now(),
        ownerId: data['owner_id'] as String? ?? '',
      );
}

PriceIndexObservation? parseDataGovPpiResponse(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return null;
  PriceIndexObservation? latest;
  for (final raw in decoded) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    if (row['series'] != 'abs') continue;
    final observedOn = DateTime.tryParse('${row['date'] ?? ''}');
    final value = (row['index'] as num?)?.toDouble();
    if (observedOn == null || value == null || !value.isFinite) continue;
    if (latest == null || observedOn.isAfter(latest.observedOn)) {
      latest = PriceIndexObservation(
        series: 'abs',
        observedOn: observedOn,
        indexValue: value,
        baseYear: 2010,
        sourceName: 'Department of Statistics Malaysia via data.gov.my',
        sourceUrl: 'https://data.gov.my/data-catalogue/ppi',
      );
    }
  }
  return latest;
}

class MarketPriceRepository {
  MarketPriceRepository({SupabaseClient? supabase, http.Client? client})
    : _supabase = supabase ?? Supabase.instance.client,
      _client = client ?? http.Client();

  final SupabaseClient _supabase;
  final http.Client _client;

  Future<CommodityPriceObservation?> fetchLatestCommodity(
    String product,
  ) async {
    final series = _seriesFor(product);
    if (series == null) return null;

    final rows = await _supabase
        .from('commodity_price_observations')
        .select()
        .eq('series_name', series)
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return CommodityPriceObservation.fromSupabase(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<PriceIndexObservation?> fetchLatestMaterialIndex(
    String product,
  ) async {
    final datasetId = _fredDatasetFor(product);
    if (datasetId == null) return null;

    final rows = await _supabase
        .from('price_index_observations')
        .select()
        .eq('dataset_id', datasetId)
        .order('observed_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return PriceIndexObservation.fromSupabase(
      Map<String, dynamic>.from(rows.first),
    );
  }

  Future<PriceIndexObservation?> fetchLatestMalaysiaPpi() async {
    try {
      final rows = await _supabase
          .from('price_index_observations')
          .select()
          .eq('dataset_id', 'ppi')
          .eq('series', 'abs')
          .order('observed_on', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        return PriceIndexObservation.fromSupabase(
          Map<String, dynamic>.from(rows.first),
        );
      }
    } catch (_) {

    }
    try {
      final dataGovRecord = await _fetchLatestMalaysiaPpiFromDataGovMy();
      if (dataGovRecord != null) return dataGovRecord;
    } catch (_) {

    }
    return _fetchLatestMalaysiaPpiFromPublicCsv();
  }

  Future<PriceIndexObservation?> _fetchLatestMalaysiaPpiFromDataGovMy() async {
    final response = await _client
        .get(
          Uri.https('api.data.gov.my', '/data-catalogue', {
            'id': 'ppi',
            'limit': '10000',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('data.gov.my PPI returned HTTP ${response.statusCode}.');
    }

    return parseDataGovPpiResponse(response.body);
  }

  Future<PriceIndexObservation?> _fetchLatestMalaysiaPpiFromPublicCsv() async {
    final response = await _client
        .get(Uri.parse('https://storage.dosm.gov.my/ppi/ppi.csv'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('DOSM PPI returned HTTP ${response.statusCode}.');
    }

    PriceIndexObservation? latest;
    for (final line in response.body.split('\n').skip(1)) {
      final columns = line.trim().split(',');
      if (columns.length < 3 || columns[0].trim() != 'abs') continue;
      final observedOn = DateTime.tryParse(columns[1].trim());
      final value = double.tryParse(columns[2].trim());
      if (observedOn == null || value == null || !value.isFinite) continue;
      if (latest == null || observedOn.isAfter(latest.observedOn)) {
        latest = PriceIndexObservation(
          series: 'abs',
          observedOn: observedOn,
          indexValue: value,
          baseYear: 2010,
          sourceName: 'Department of Statistics Malaysia',
          sourceUrl: 'https://data.gov.my/data-catalogue/ppi',
        );
      }
    }
    return latest;
  }

  static List<LocalListingPrice> filterPeerComparableListings(
    List<LocalListingPrice> listings,
    String? currentUserId,
  ) {
    if (currentUserId == null || currentUserId.isEmpty) return listings;
    return listings
        .where((listing) => listing.ownerId != currentUserId)
        .toList();
  }

  Future<List<LocalListingPrice>> fetchLatestLocalListingPrices(
    String product,
  ) async {
    final query = product.trim();
    if (query.isEmpty) return const [];

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    var supabaseQuery = _supabase
        .from('listings')
        .select(
          'owner_id, material, asking_price_per_kg, quantity, unit, location, created_at',
        )
        .ilike('material', '%$query%')
        .eq('status', 'ACTIVE')
        .not('asking_price_per_kg', 'is', null);

    if (currentUserId != null && currentUserId.isNotEmpty) {
      supabaseQuery = supabaseQuery.neq('owner_id', currentUserId);
    }

    final rows = await supabaseQuery
        .order('created_at', ascending: false)
        .limit(50);
    final listings = (rows as List)
        .map(
          (row) => LocalListingPrice.fromSupabase(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((listing) => listing.pricePerKg > 0)
        .toList();
    return filterPeerComparableListings(listings, currentUserId);
  }

  String? _fredDatasetFor(String product) {
    final lower = product.toLowerCase();
    if (lower.contains('aluminium') || lower.contains('aluminum')) {
      return 'fred_WPU102402';
    }
    if (lower.contains('copper')) return 'fred_WPU102301';
    if (lower.contains('iron') ||
        lower.contains('steel') ||
        lower.contains('ferrous')) {
      return 'fred_WPU1012';
    }
    return null;
  }

  String? _seriesFor(String product) {
    final lower = product.toLowerCase();
    if (lower.contains('aluminium') || lower.contains('aluminum')) {
      return 'Aluminum';
    }
    if (lower.contains('copper')) return 'Copper';
    if (lower.contains('iron') ||
        lower.contains('steel') ||
        lower.contains('ferrous')) {
      return 'Iron ore, cfr spot';
    }
    return null;
  }
}
