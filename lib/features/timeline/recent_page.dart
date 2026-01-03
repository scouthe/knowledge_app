import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../core/auth_storage.dart';
import '../../widgets/primary_button.dart';
import 'timeline_service.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  String _content = '';
  bool _loading = false;

  Future<void> _load(int offset) async {
    setState(() => _loading = true);
    try {
      final token = await AuthStorage().readToken();
      if (token == null) return;
      final service = TimelineService(token);
      final res = await service.listByDay(offset);
      setState(() => _content = res);
    } catch (e) {
      if (e is AuthExpiredException) {
        await AuthGuard.logout(context, message: '登录已过期，请重新登录');
        return;
      }
      setState(() => _content = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日/昨日/前日')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: '今日',
                    onPressed: _loading ? null : () => _load(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    text: '昨日',
                    onPressed: _loading ? null : () => _load(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    text: '前日',
                    onPressed: _loading ? null : () => _load(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_content),
              ),
            )
          ],
        ),
      ),
    );
  }
}
