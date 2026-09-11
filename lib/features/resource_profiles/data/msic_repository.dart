import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class IndustrySector {
  const IndustrySector({required this.code, required this.name});

  final String code;
  final String name;

  factory IndustrySector.fromSupabase(Map<String, dynamic> data) =>
      IndustrySector(
        code: data['item_code'] as String? ?? data['section'] as String? ?? '',
        name: data['description_en'] as String? ?? 'Unspecified industry',
      );
}

class MsicRepository {
  MsicRepository({SupabaseClient? supabase, http.Client? client})
    : _supabase = supabase ?? Supabase.instance.client,
      _client = client ?? http.Client();

  final SupabaseClient _supabase;
  final http.Client _client;

  Future<List<IndustrySector>> fetchTopLevelSectors() async {
    try {
      final rows = await _supabase
          .from('msic_codes')
          .select('item_code, section, description_en')
          .eq('digits', 1)
          .order('item_code');
      final sectors = (rows as List)
          .map(
            (row) => IndustrySector.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((sector) => sector.name.isNotEmpty)
          .toList();
      if (sectors.isNotEmpty) return sectors;
    } catch (_) {

    }

    final response = await _client
        .get(
          Uri.parse(
            'https://api.data.gov.my/data-catalogue?id=msic&limit=10000',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('DOSM MSIC returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('DOSM MSIC response was not a list.');
    }

    return decoded
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((row) => row['digits'] == 1)
        .map(
          (row) => IndustrySector(
            code: '${row['section'] ?? row['item'] ?? ''}',
            name: '${row['desc_en'] ?? ''}'.trim(),
          ),
        )
        .where((sector) => sector.name.isNotEmpty)
        .toList();
  }
}
