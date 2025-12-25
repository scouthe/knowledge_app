import 'dart:convert';
import '../../core/api_client.dart';

class TimelineService {
  TimelineService(this.token);

  final String token;

  Future<String> listByDay(int offsetDays) async {
    final client = ApiClient(token: token);
    final res = await client.get('/api/daily_list?offset=$offsetDays');
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '获取失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['content'] as String? ?? '';
  }
}
