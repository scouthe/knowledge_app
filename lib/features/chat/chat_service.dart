import 'dart:convert';
import '../../core/api_client.dart';

class ChatService {
  ChatService(this.token);

  final String token;

  Future<String> ask(String query) async {
    final client = ApiClient(token: token);
    final res = await client.post('/api/chat', {'query': query});
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '提问失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }
}
