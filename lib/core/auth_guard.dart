import 'package:flutter/material.dart';
import '../features/auth/login_page.dart';
import 'auth_storage.dart';

class AuthGuard {
  static Future<void> logout(BuildContext context,
      {String? message}) async {
    await AuthStorage().clear();
    if (!context.mounted) return;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}
