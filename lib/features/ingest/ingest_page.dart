import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/auth_storage.dart';
import '../../core/notification_service.dart';
import '../../core/share_store.dart';
import '../../widgets/primary_button.dart';
import '../admin/admin_page.dart';
import '../chat/chat_page.dart';
import '../summary/daily_summary_page.dart';
import '../timeline/recent_page.dart';
import 'category_service.dart';
import 'ingest_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class IngestPage extends StatefulWidget {
  const IngestPage({super.key, required this.username});
  final String username;

  @override
  State<IngestPage> createState() => _IngestPageState();
}

class _IngestPageState extends State<IngestPage> {
  final _textCtrl = TextEditingController();
  final _newCategoryCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  String _mode = 'note';
  bool _loading = false;
  bool _recording = false;
  String? _imagePath;
  String? _recordPath;
  Timer? _timer;
  Timer? _waveTimer;
  int _recordSeconds = 0;
  List<double> _waveform = List.filled(24, 0.2);
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String? _token;
  List<String> _categories = [];
  String _selectedCategory = '(默认)';

  @override
  void initState() {
    super.initState();
    _loadToken();
    if (ShareStore.pendingText != null) {
      _textCtrl.text = ShareStore.pendingText!;
      ShareStore.pendingText = null;
    }
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((items) {
      String? text;
      for (final item in items) {
        if (item.type == SharedMediaType.text || item.type == SharedMediaType.url) {
          text = item.path;
          break;
        }
      }
      if (text != null && text.trim().isNotEmpty) {
        setState(() {
          _textCtrl.text = text!.trim();
        });
      }
    });
  }

  Future<void> _loadToken() async {
    final storage = AuthStorage();
    final token = await storage.readToken();
    setState(() => _token = token);
    if (token != null) {
      await _loadCategories(token);
    }
  }

  Future<void> _loadCategories(String token) async {
    try {
      final svc = CategoryService(token);
      final list = await svc.listCategories();
      setState(() {
        _categories = list;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = '(默认)';
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _newCategoryCtrl.dispose();
    _recorder.dispose();
    _timer?.cancel();
    _waveTimer?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  String _folderValue() {
    if (_selectedCategory == '(默认)') return '';
    final sub = _mode == 'note' ? 'Notes' : 'Articles';
    return '$_selectedCategory/$sub';
  }

  Future<void> _submit() async {
    if (_token == null || _token!.isEmpty) return;
    if (_textCtrl.text.trim().isEmpty && _imagePath == null) return;
    setState(() => _loading = true);
    try {
      final service = IngestService(_token!);
      if (_imagePath != null) {
        final category = _selectedCategory == '(默认)' ? '' : _selectedCategory;
        final jobId = await service.uploadImage(
          _imagePath!,
          text: _textCtrl.text.trim(),
          category: category,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已入队: $jobId')),
        );
        await NotificationService.instance.show('图片入库中', 'Job: $jobId');
        _notifyStatus(jobId);
        _textCtrl.clear();
        setState(() => _imagePath = null);
        return;
      }

      final folder = _folderValue();
      final res = await service.ingestText(
        _textCtrl.text,
        _mode,
        folder: folder.isEmpty ? null : folder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已入队: ${res.jobId}')),
      );
      await NotificationService.instance.show('入库任务已创建', 'Job: ${res.jobId}');
      _notifyStatus(res.jobId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      await NotificationService.instance.show('入库失败', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final compressed = await _compressImage(picked.path);
    if (!mounted) return;
    setState(() => _imagePath = compressed ?? picked.path);
  }

  Future<String?> _compressImage(String path) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        path,
        target,
        quality: 80,
        minWidth: 1600,
        minHeight: 1600,
      );
      return result?.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitWithMode(String mode) async {
    if (_loading) return;
    setState(() => _mode = mode);
    await _submit();
  }

  Future<void> _createCategory() async {
    if (_token == null || _token!.isEmpty) return;
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final svc = CategoryService(_token!);
      await svc.createCategory(name);
      await _loadCategories(_token!);
      _newCategoryCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('分类已创建')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _uploadFile() async {
    if (_token == null || _token!.isEmpty) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final folder = _folderValue();
    try {
      final service = IngestService(_token!);
      final jobId = await service.uploadFile(file, folder: folder.isEmpty ? null : folder);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已入队: $jobId')));
      await NotificationService.instance.show('文件入库中', 'Job: $jobId');
      _notifyStatus(jobId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      await NotificationService.instance.show('文件入库失败', e.toString());
    }
  }

  Future<void> _startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有麦克风权限')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordPath = path;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: path,
    );
    _recordSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds += 1);
    });
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      final rand = Random();
      setState(() {
        _waveform = _waveform
            .map((_) => 0.2 + rand.nextDouble() * 0.8)
            .toList();
      });
    });
    setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    _waveTimer?.cancel();
    setState(() => _recording = false);
    if (path == null || path.isEmpty) return;
    if (_token == null || _token!.isEmpty) return;
    final folder = _folderValue();
    try {
      final service = IngestService(_token!);
      final jobId = await service.uploadVoice(
        PlatformFile(name: File(path).uri.pathSegments.last, path: path, size: 0),
        folder: folder.isEmpty ? null : folder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已入队: $jobId')),
      );
      await NotificationService.instance.show('语音入库中', 'Job: $jobId');
      _notifyStatus(jobId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      await NotificationService.instance.show('语音入库失败', e.toString());
    }
  }

  Future<void> _notifyStatus(String jobId) async {
    if (_token == null || _token!.isEmpty) return;
    final service = IngestService(_token!);
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final info = await service.checkStatus(jobId);
        final status = info['status']?.toString() ?? '';
        if (status.contains('SUCCESS')) {
          await NotificationService.instance.show('入库成功', 'Job: $jobId');
          return;
        }
        if (status.contains('FAIL')) {
          await NotificationService.instance.show(
            '入库失败',
            info['error']?.toString() ?? '未知错误',
          );
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.stop();
    _timer?.cancel();
    _waveTimer?.cancel();
    if (_recordPath != null) {
      try {
        File(_recordPath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _recording = false;
      _recordSeconds = 0;
      _waveform = List.filled(24, 0.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎 ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.event_note),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecentPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailySummaryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              if (widget.username == 'scouthe') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '输入笔记或URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _imagePath == null
                        ? null
                        : () => setState(() => _imagePath = null),
                    child: const Text('清除图片'),
                  ),
                ),
              ],
            ),
            if (_imagePath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imagePath!),
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _submitWithMode('note'),
                    child: const Text('仅存笔记'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _submitWithMode('crawl'),
                    child: const Text('抓取网页'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _mode,
                    items: const [
                      DropdownMenuItem(value: 'note', child: Text('笔记')),
                      DropdownMenuItem(value: 'crawl', child: Text('网页')),
                    ],
                    onChanged: (v) => setState(() => _mode = v ?? 'note'),
                    decoration: const InputDecoration(labelText: '类型'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: [
                      const DropdownMenuItem(value: '(默认)', child: Text('(默认)')),
                      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    ],
                    onChanged: (v) => setState(() => _selectedCategory = v ?? '(默认)'),
                    decoration: const InputDecoration(labelText: '分类'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryCtrl,
                    decoration: const InputDecoration(labelText: '新分类名'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(text: '创建分类', onPressed: _createCategory),
                )
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: _loading ? '提交中...' : '发送到知识库',
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: '添加文件',
              onPressed: _uploadFile,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _recording ? Colors.red.shade200 : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _recording ? '录音中... 松开上传' : '长按录音',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            if (_recording) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('计时 ${_recordSeconds}s'),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelRecording,
                    child: const Text('取消'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _waveform
                      .map((v) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: 40 * v,
                              color: Colors.blueGrey.shade400,
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
