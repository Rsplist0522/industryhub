// Official Market Context: retrieves state-level manufacturing GDP data
// from Malaysia's data.gov.my catalogue API. It is contextual only and
// must not be used to calculate or override Marketplace listing matches.

import 'dart:convert';

import 'package:http/http.dart' as http;

class IndustrialContext {
  const IndustrialContext({
    required this.state,
    required this.referenceDate,
    required this.valueRmMillions,
  });

  final String state;
  final DateTime referenceDate;
  final double valueRmMillions;

  factory IndustrialContext.fromJson(Map<String, dynamic> json) {
    return IndustrialContext(
      state: json['state'] as String? ?? 'Malaysia',
      referenceDate: DateTime.parse(json['date'] as String),
      valueRmMillions: (json['value'] as num).toDouble(),
    );
  }
}

class IndustrialContextRepository {
  IndustrialContextRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, IndustrialContext?> _cache = {};

  /// Returns the newest official manufacturing GDP record for the state
  /// recognised inside [marketplaceLocation]. For example, "Bayan Lepas,
  /// Penang" maps to the official state label "Pulau Pinang".
  Future<IndustrialContext?> fetchManufacturingContext({required String marketplaceLocation}) async {
    final state = _normaliseState(marketplaceLocation);
    if (state == null) return null;
    if (_cache.containsKey(state)) return _cache[state];

    final uri = Uri.https(
      'api.data.gov.my',
      '/data-catalogue',
      {
        'id': 'gdp_state_real_supply',
        'ifilter': '$state@state',
        'filter': 'abs@series,p3@sector',
        'sort': '-date',
        'limit': '1',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Official data service returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      _cache[state] = null;
      return null;
    }

    final firstRecord = Map<String, dynamic>.from(decoded.first as Map);
    final context = IndustrialContext.fromJson(firstRecord);
    _cache[state] = context;
    return context;
  }

  String? _normaliseState(String location) {
    final value = location.toLowerCase();
    const stateLabels = <String, String>{
      'negeri sembilan': 'Negeri Sembilan',
      'pulau pinang': 'Pulau Pinang',
      'kuala lumpur': 'W.P. Kuala Lumpur',
      'putrajaya': 'W.P. Kuala Lumpur',
      'terengganu': 'Terengganu',
      'selangor': 'Selangor',
      'sarawak': 'Sarawak',
      'sabah': 'Sabah',
      'penang': 'Pulau Pinang',
      'pahang': 'Pahang',
      'perlis': 'Perlis',
      'perak': 'Perak',
      'melaka': 'Melaka',
      'malacca': 'Melaka',
      'kelantan': 'Kelantan',
      'kedah': 'Kedah',
      'johor': 'Johor',
    };

    for (final entry in stateLabels.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
