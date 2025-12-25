import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/auth_storage.dart';
import '../../widgets/primary_button.dart';
import '../admin/admin_page.dart';
import '../chat/chat_page.dart';
import '../summary/daily_summary_page.dart';
import '../timeline/recent_page.dart';
import 'category_service.dart';
import 'ingest_service.dart';

class IngestPage extends StatefulWidget {
  const IngestPage({super.key, required this.username});
  final String username;

  @override
  State<IngestPage> createState() => _IngestPageState();
}

class _IngestPageState extends State<IngestPage> {
  final _textCtrl = TextEditingController();
  final _newCategoryCtrl = TextEditingController();
  String _mode = 'note';
  bool _loading = false;
  String? _token;
  List<String> _categories = [];
  String _selectedCategory = '(默认)';

  @override
  void initState() {
    super.initState();
    _loadToken();
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
    super.dispose();
  }

  String _folderValue() {
    if (_selectedCategory == '(默认)') return '';
    final sub = _mode == 'note' ? 'Notes' : 'Articles';
    return '$_selectedCategory/$sub';
  }

  Future<void> _submit() async {
    if (_token == null || _token!.isEmpty) return;
    setState(() => _loading = true);
    try {
      final service = IngestService(_token!);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
            PrimaryButton(
              text: '语音输入',
              onPressed: () async {
                if (_token == null || _token!.isEmpty) return;
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );
                if (result == null || result.files.isEmpty) return;
                final file = result.files.first;
                final folder = _folderValue();
                try {
                  final service = IngestService(_token!);
                  final jobId = await service.uploadVoice(
                    file,
                    folder: folder.isEmpty ? null : folder,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已入队: $jobId')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
