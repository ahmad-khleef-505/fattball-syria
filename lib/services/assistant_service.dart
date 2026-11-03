import 'package:cloud_functions/cloud_functions.dart';

class AssistantService {
  AssistantService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'me-central1');

  final FirebaseFunctions _functions;

  Future<String> ask({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'chatAssistant',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 35)),
      );
      final response = await callable.call<Map<String, dynamic>>({
        'message': message.trim(),
        'history': history,
      });
      final answer = response.data['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const AssistantServiceException(
          'وصل رد غير صالح من المساعد. حاول مرة أخرى.',
        );
      }
      return answer.trim();
    } on FirebaseFunctionsException catch (error) {
      throw AssistantServiceException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : _messageForCode(error.code),
      );
    }
  }

  String _messageForCode(String code) {
    return switch (code) {
      'unauthenticated' => 'سجّل الدخول لاستخدام المساعد.',
      'resource-exhausted' => 'وصلت إلى حد الاستخدام اليومي. حاول غداً.',
      'failed-precondition' => 'المساعد غير مهيأ حالياً. يرجى المحاولة لاحقاً.',
      'deadline-exceeded' => 'استغرق الرد وقتاً طويلاً. حاول مرة أخرى.',
      'unavailable' => 'المساعد غير متاح مؤقتاً. تحقق من اتصالك.',
      'invalid-argument' => 'تعذر فهم الرسالة. أعد صياغتها وحاول مجدداً.',
      _ => 'تعذر الاتصال بالمساعد. حاول مرة أخرى بعد قليل.',
    };
  }
}

class AssistantServiceException implements Exception {
  const AssistantServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
