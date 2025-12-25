import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config.dart';
import 'core/notification_service.dart';
import 'core/share_store.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await NotificationService.instance.init();

  ReceiveSharingIntent.instance.getInitialMedia().then((items) {
    final text = _extractSharedText(items);
    if (text != null && text.trim().isNotEmpty) {
      ShareStore.pendingText = text.trim();
    }
  });

  ReceiveSharingIntent.instance.getMediaStream().listen((items) {
    final text = _extractSharedText(items);
    if (text != null && text.trim().isNotEmpty) {
      ShareStore.pendingText = text.trim();
    }
  });

  runApp(const KnowledgeApp());
}

String? _extractSharedText(List<SharedMediaFile> items) {
  for (final item in items) {
    if (item.type == SharedMediaType.text || item.type == SharedMediaType.url) {
      return item.path;
    }
  }
  return null;
}
