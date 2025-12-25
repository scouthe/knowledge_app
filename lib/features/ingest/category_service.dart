import 'dart:convert';
import '../../core/api_client.dart';

class CategoryService {
  CategoryService(this.token);

  final String token;

  Future<void> createCategory(String name) async {
    final client = ApiClient(token: token);
    final res = await client.post('/api/category', {'name': name});
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '创建失败');
    }
  }

  Future<List<String>> listCategories() async {
    final client = ApiClient(token: token);
    final res = await client.get('/api/categories');
    if (res.statusCode != 200) {
      throw Exception('获取分类失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['categories'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }
}
