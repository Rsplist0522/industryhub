import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  const AiService();

  Future<Map<String, dynamic>> callAI(String systemPrompt, String userInput) async {
    final baseUrl = dotenv.env['AI_BASE_URL'];
    final apiKey = dotenv.env['AI_API_KEY'];
    final model = dotenv.env['AI_MODEL'] ?? 'gpt-4o-mini';
    if (baseUrl == null || apiKey == null || apiKey.isEmpty) {
      return _localFallback(userInput);
    }

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': model,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': '$systemPrompt Return JSON only. Do not use markdown fences or a preamble.'},
          {'role': 'user', 'content': userInput},
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI service returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = ((decoded['choices'] as List).first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    final text = (content['content'] as String).replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Map<String, dynamic> _localFallback(String input) {
    final lower = input.toLowerCase();
    return {
      'skills': [if (lower.contains('quality')) 'Quality systems' else 'CNC machining', 'Lean manufacturing'],
      'experience_level': 'Entry to intermediate',
      'certifications': ['HRD Corp claimable preferred'],
    };
  }
}

class FirebaseService {
  const FirebaseService();

  Future<void> initialize() async {
    // Add Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
    // after running `flutterfire configure` for the target project.
  }
}
