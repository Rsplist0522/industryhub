import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  const AiService();

  Future<Map<String, dynamic>> callAI(String systemPrompt, String userInput) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-chat',
        body: {'system_prompt': systemPrompt, 'user_input': userInput},
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('AI proxy returned HTTP ${response.status}.');
      }
      final data = response.data;
      if (data is! Map) throw const FormatException('AI proxy returned an invalid response.');
      final result = Map<String, dynamic>.from(data);
      if (result['error'] is String) throw Exception(result['error'] as String);
      result['__source'] = 'ai';
      return result;
    } catch (_) {
      return {..._localFallback(userInput), '__source': 'local_fallback'};
    }
  }

  Map<String, dynamic> _localFallback(String input) {
    if (input.startsWith('FAIRPRICE_NEGOTIATION')) {
      return {
        'buyer_message': 'The offer should be discussed against the transparent reference band, material condition, volume, and logistics rather than treated as a fixed market quote.',
        'counter_offer_rm_per_kg': null,
        'recommended_strategy': 'Use the calculated target as your opening position and protect the floor unless quality or collection terms improve.',
        'risk_flags': ['AI proxy unavailable', 'Confirm local grade and logistics before agreement'],
      };
    }

    final lower = input.toLowerCase();
    return {
      'skills': [if (lower.contains('quality')) 'Quality systems' else 'CNC machining', 'Lean manufacturing'],
      'experience_level': 'Entry to intermediate',
      'certifications': ['HRD Corp claimable preferred'],
    };
  }
}
