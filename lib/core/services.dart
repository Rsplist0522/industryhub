import 'package:supabase_flutter/supabase_flutter.dart';

String describeAiError(Object error) {
  final text = error
      .toString()
      .replaceFirst(RegExp(r'^Exception:\\s*'), '')
      .trim();
  if (text.isEmpty) return 'The AI service did not return a diagnostic.';
  return text.length > 320 ? '${text.substring(0, 320)}…' : text;
}

class AiService {
  const AiService();

  Future<Map<String, dynamic>> callAI(
    String systemPrompt,
    String userInput,
  ) async {
    final trimmedSystemPrompt = systemPrompt.trim();
    final trimmedUserInput = userInput.trim();
    if (trimmedSystemPrompt.isEmpty || trimmedUserInput.isEmpty) {
      throw ArgumentError('AI prompts must not be empty.');
    }
    final safeSystemPrompt = trimmedSystemPrompt.length > 12000
        ? trimmedSystemPrompt.substring(0, 12000)
        : trimmedSystemPrompt;
    final safeUserInput = trimmedUserInput.length > 20000
        ? trimmedUserInput.substring(0, 20000)
        : trimmedUserInput;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-chat',
        body: {'system_prompt': safeSystemPrompt, 'user_input': safeUserInput},
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('AI proxy returned HTTP ${response.status}.');
      }
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('AI proxy returned an invalid response.');
      }
      final result = Map<String, dynamic>.from(data);
      if (result['error'] is String) {
        final providerMessage = result['provider_message'] is String
            ? (result['provider_message'] as String).trim()
            : '';
        final providerModel = result['provider_model'] is String
            ? (result['provider_model'] as String).trim()
            : '';
        final details = [
          result['error'] as String,
          if (providerMessage.isNotEmpty) providerMessage,
          if (providerModel.isNotEmpty) 'Model: $providerModel',
        ].join(' ');
        throw Exception(details);
      }
      result['__source'] = 'ai';
      return result;
    } catch (error) {
      throw Exception(
        'The AI assistant is unavailable. Configure and deploy the Supabase ai-chat function before using this conversation. ($error)',
      );
    }
  }
}
