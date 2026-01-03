import 'package:flutter/material.dart';
import '../../core/auth_storage.dart';
import '../../core/config.dart';
import '../../widgets/primary_button.dart';
import '../ingest/ingest_page.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  final _storage = AuthStorage();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final token = await _storage.readToken();
    final user = await _storage.readUser();
    if (token != null && token.isNotEmpty && user != null && user.isNotEmpty) {
      try {
        final verifiedUser = await _auth.verifyToken(token);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => IngestPage(username: verifiedUser)),
        );
      } catch (_) {
        await _storage.clear();
      }
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.login(_userCtrl.text, _passCtrl.text);
      await _storage.saveToken(user.token, user.username);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => IngestPage(username: user.username)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testConnection(String url) async {
    try {
      final res = await _auth.ping(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('连接成功: $res')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('连接失败: $e')));
    }
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController(text: AppConfig.baseUrl);
        return AlertDialog(
          title: const Text('设置服务器地址'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'http://ip:port'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                await AppConfig.updateBaseUrl(url);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已设置为 ${AppConfig.baseUrl}')),
                );
              },
              child: const Text('保存'),
            ),
            TextButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                await _testConnection(url);
              },
              child: const Text('测试连接'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showAddressDialog,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: _loading ? '登录中...' : '登录',
              onPressed: _loading ? null : _handleLogin,
            ),
          ],
        ),
      ),
    );
  }
}
