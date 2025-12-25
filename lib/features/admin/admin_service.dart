import 'dart:convert';
import '../../core/api_client.dart';

class AdminService {
  AdminService(this.token);

  final String token;

  Future<List<Map<String, dynamic>>> listUsers() async {
    final client = ApiClient(token: token);
    final res = await client.get('/admin/users');
    if (res.statusCode != 200) {
      throw Exception('获取用户失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['users'] as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> createUser(String username, String password) async {
    final client = ApiClient(token: token);
    final res = await client.post('/admin/users', {
      'username': username,
      'password': password,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '创建失败');
    }
  }

  Future<void> resetPassword(String username, String newPassword) async {
    final client = ApiClient(token: token);
    final res = await client.post('/admin/users/reset', {
      'username': username,
      'new_password': newPassword,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '重置失败');
    }
  }

  Future<void> deleteUser(String username) async {
    final client = ApiClient(token: token);
    final res = await client.delete('/admin/users/$username');
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '删除失败');
    }
  }
}
