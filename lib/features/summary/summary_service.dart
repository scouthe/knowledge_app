import 'dart:convert';
import '../../core/api_client.dart';
import '../../core/models/daily_summary.dart';

class SummaryService {
  SummaryService(this.token);

  final String token;

  Future<DailySummaryResult> generateDailySummary() async {
    final client = ApiClient(token: token);
    final res = await client.post('/api/daily_summary', {});
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '生成失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DailySummaryResult.fromJson(data);
  }
}
