import 'dart:convert';
import 'package:http/http.dart' as http;

class AssistantServiceException implements Exception {
  const AssistantServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AssistantService {
final String _apiKey = 'YOUR_API_KEY_HERE';
  Future<String> ask({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final formattedHistory = history.map((msg) {
        return {
          "role": msg['role'] == 'model' ? 'assistant' : 'user', 
          "content": msg['content'] ?? ''
        };
      }).toList();

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://fattball-syria.web.app',
          'X-Title': 'Fattball App',
        },
        body: jsonEncode({
          "model": "google/gemini-2.0-flash-exp:free",
          "messages": [
            {
              "role": "system", 
              "content": "أنت مساعد ذكي لتطبيق 'Fattball' لحجز ملاعب كرة القدم في سوريا. أجب على أسئلة المستخدمين باللغة العربية بأسلوب رياضي وودود ومختصر."
            },
            ...formattedHistory,
            {"role": "user", "content": message}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        return reply.toString().trim();
      } else {
        throw const AssistantServiceException('عذراً، حدث خطأ في الاتصال بالخادم. يرجى المحاولة لاحقاً.');
      }
    } catch (e) {
      if (e is AssistantServiceException) rethrow;
      throw const AssistantServiceException('تعذر جلب الرد. تحقق من اتصالك بالإنترنت.');
    }
  }
}