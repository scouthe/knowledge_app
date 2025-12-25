import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _defaultBaseUrl = 'http://100.124.74.26:8888';
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static const Duration requestTimeout = Duration(seconds: 20);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url') ?? _defaultBaseUrl;
  }

  static Future<void> updateBaseUrl(String url) async {
    if (url.isEmpty) return;
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
  }
}
