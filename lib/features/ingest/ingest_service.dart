import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models/ingest.dart';

class IngestService {
  IngestService(this.token);

  final String token;

  Future<IngestResult> ingestText(String content, String mode,
      {String? folder}) async {
    final client = ApiClient(token: token);
    final body = {
      'content': content,
      'mode': mode,
    };
    if (folder != null && folder.isNotEmpty) {
      body['folder'] = folder;
    }
    final res = await client.post('/ingest', body);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '入库失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return IngestResult.fromJson(data);
  }

  Future<String> uploadFile(PlatformFile file, {String? folder}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '上传失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['job_id'] as String? ?? '';
  }

  Future<String> uploadVoice(PlatformFile file, {String? folder}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/ingest_voice');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '语音上传失败');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['job_id'] as String? ?? '';
  }

  Future<Map<String, dynamic>> checkStatus(String jobId) async {
    final client = ApiClient(token: token);
    final res = await client.get('/api/status/$jobId');
    if (res.statusCode != 200) {
      throw Exception('状态获取失败');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
