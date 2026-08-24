import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  const AiService();

  Future<Map<String, dynamic>> callAI(
    String systemPrompt,
    String userInput,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-chat',
        body: {'system_prompt': systemPrompt, 'user_input': userInput},
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('AI proxy returned HTTP ${response.status}.');
      }
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('AI proxy returned an invalid response.');
      }
      final result = Map<String, dynamic>.from(data);
      if (result['error'] is String) throw Exception(result['error'] as String);
      result['__source'] = 'ai';
      return result;
    } catch (error) {
      throw Exception(
        'The AI assistant is unavailable. Configure and deploy the Supabase ai-chat function before using this conversation. ($error)',
      );
    }
  }
}
