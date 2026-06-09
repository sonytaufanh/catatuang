import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ErrorLogService {
  ErrorLogService._();

  static final ErrorLogService instance = ErrorLogService._();
  static const String _key = 'error_logs_v1';

  Future<void> log({
    required String source,
    required Object error,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final entry = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'source': source,
      'error': error.toString(),
    });
    final next = [...raw, entry];
    if (next.length > 100) {
      next.removeRange(0, next.length - 100);
    }
    await prefs.setStringList(_key, next);
  }

  Future<List<String>> readRawLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const <String>[];
  }
}
