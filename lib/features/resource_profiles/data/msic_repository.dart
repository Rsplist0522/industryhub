import 'package:supabase_flutter/supabase_flutter.dart';

class IndustrySector {
  const IndustrySector({required this.code, required this.name});

  final String code;
  final String name;

  factory IndustrySector.fromSupabase(Map<String, dynamic> data) => IndustrySector(
        code: data['item_code'] as String? ?? data['section'] as String? ?? '',
        name: data['description_en'] as String? ?? 'Unspecified industry',
      );
}

class MsicRepository {
  MsicRepository({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<IndustrySector>> fetchTopLevelSectors() async {
    final rows = await _supabase
        .from('msic_codes')
        .select('item_code, section, description_en')
        .eq('digits', 1)
        .order('item_code');
    return (rows as List)
        .map((row) => IndustrySector.fromSupabase(Map<String, dynamic>.from(row as Map)))
        .where((sector) => sector.name.isNotEmpty)
        .toList();
  }
}
