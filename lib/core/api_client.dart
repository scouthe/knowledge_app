import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class AuthExpiredException implements Exception {
  AuthExpiredException([this.message = 'Token expired']);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token});

  final String? token;

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> post(String path, Map<String, dynamic> body,
      {Duration? timeout}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final res = await http
        .post(uri, headers: _headers(), body: jsonEncode(body))
        .timeout(timeout ?? AppConfig.requestTimeout);
    if (res.statusCode == 401) {
      throw AuthExpiredException();
    }
    return res;
  }

  Future<http.Response> get(String path, {Duration? timeout}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final res = await http
        .get(uri, headers: _headers())
        .timeout(timeout ?? AppConfig.requestTimeout);
    if (res.statusCode == 401) {
      throw AuthExpiredException();
    }
    return res;
  }

  Future<http.Response> delete(String path, {Duration? timeout}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final res = await http
        .delete(uri, headers: _headers())
        .timeout(timeout ?? AppConfig.requestTimeout);
    if (res.statusCode == 401) {
      throw AuthExpiredException();
    }
    return res;
  }
}
