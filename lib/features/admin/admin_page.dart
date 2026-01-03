import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../core/auth_storage.dart';
import '../../widgets/primary_button.dart';
import 'admin_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  final _newUserCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _resetUserCtrl = TextEditingController();
  final _resetPassCtrl = TextEditingController();
  final _delUserCtrl = TextEditingController();

  @override
  void dispose() {
    _newUserCtrl.dispose();
    _newPassCtrl.dispose();
    _resetUserCtrl.dispose();
    _resetPassCtrl.dispose();
    _delUserCtrl.dispose();
    super.dispose();
  }

  Future<AdminService> _service() async {
    final token = await AuthStorage().readToken();
    return AdminService(token ?? '');
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final svc = await _service();
      final list = await svc.listUsers();
      setState(() => _users = list);
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthGuard.logout(context, message: '登录已过期，请重新登录');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    try {
      final svc = await _service();
      await svc.createUser(_newUserCtrl.text, _newPassCtrl.text);
      await _loadUsers();
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthGuard.logout(context, message: '登录已过期，请重新登录');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resetUser() async {
    try {
      final svc = await _service();
      await svc.resetPassword(_resetUserCtrl.text, _resetPassCtrl.text);
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthGuard.logout(context, message: '登录已过期，请重新登录');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteUser() async {
    try {
      final svc = await _service();
      await svc.deleteUser(_delUserCtrl.text);
      await _loadUsers();
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthGuard.logout(context, message: '登录已过期，请重新登录');
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadUsers,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('用户列表', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._users.map((u) => Text('${u['username']} (${u['created_at']})')),
            const Divider(height: 32),
            const Text('新增用户', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _newUserCtrl, decoration: const InputDecoration(labelText: '用户名')),
            TextField(controller: _newPassCtrl, decoration: const InputDecoration(labelText: '密码')),
            PrimaryButton(text: '创建', onPressed: _createUser),
            const Divider(height: 32),
            const Text('重置密码', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _resetUserCtrl, decoration: const InputDecoration(labelText: '用户名')),
            TextField(controller: _resetPassCtrl, decoration: const InputDecoration(labelText: '新密码')),
            PrimaryButton(text: '重置', onPressed: _resetUser),
            const Divider(height: 32),
            const Text('删除用户', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _delUserCtrl, decoration: const InputDecoration(labelText: '用户名')),
            PrimaryButton(text: '删除', onPressed: _deleteUser),
          ],
        ),
      ),
    );
  }
}
