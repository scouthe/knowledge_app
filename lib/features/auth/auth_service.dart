import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models/user.dart';

class AuthService {
  Future<User> login(String username, String password) async {
    final client = ApiClient();
    final res = await client.post('/auth/login', {
      'username': username,
      'password': password,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '登录失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<void> resetPassword(
      String username, String oldPass, String newPass) async {
    final client = ApiClient();
    final res = await client.post('/auth/reset', {
      'username': username,
      'old_password': oldPass,
      'new_password': newPass,
    });
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '重置失败');
    }
  }

  Future<String> ping(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/healthz');
    final res = await http.get(uri).timeout(AppConfig.requestTimeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res.body;
  }
}
