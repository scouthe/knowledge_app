import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/auth_storage.dart';
import '../../widgets/primary_button.dart';
import 'summary_service.dart';

class DailySummaryPage extends StatefulWidget {
  const DailySummaryPage({super.key});

  @override
  State<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends State<DailySummaryPage> {
  bool _loading = false;
  String _result = '';

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final storage = AuthStorage();
      final token = await storage.readToken();
      if (token == null) return;
      final service = SummaryService(token);
      final res = await service.generateDailySummary();
      if (File(res.path).existsSync()) {
        _result = File(res.path).readAsStringSync();
      } else {
        _result = '已生成: ${res.path} (${res.mode})';
      }
      setState(() {});
    } catch (e) {
      setState(() => _result = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日总结')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            PrimaryButton(
              text: _loading ? '生成中...' : '生成今日总结',
              onPressed: _loading ? null : _generate,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
