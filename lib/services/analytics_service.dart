import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();
  static const String _eventsKey = 'analytics_events_v1';
  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _eventsTable =
      String.fromEnvironment('ANALYTICS_EVENTS_TABLE', defaultValue: 'analytics_events');

  bool get _isCloudEnabled =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  Future<void> track(
    String name, {
    Map<String, dynamic>? properties,
  }) async {
    final event = <String, dynamic>{
      'name': name,
      'at': DateTime.now().toIso8601String(),
      'properties': properties,
    };

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_eventsKey) ?? const <String>[];
    final next = [...raw, jsonEncode(event)];
    if (next.length > 300) {
      next.removeRange(0, next.length - 300);
    }
    await prefs.setStringList(_eventsKey, next);
    await _sendToCloud(event);
  }

  Future<void> trackOnce({
    required String onceKey,
    required String name,
    Map<String, dynamic>? properties,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'analytics_once_$onceKey';
    if (prefs.getBool(key) ?? false) return;
    await track(name, properties: properties);
    await prefs.setBool(key, true);
  }

  Future<void> _sendToCloud(Map<String, dynamic> event) async {
    if (!_isCloudEnabled) return;
    try {
      final client = Supabase.instance.client;
      await client.from(_eventsTable).insert(<String, dynamic>{
        'name': event['name'],
        'created_at': event['at'],
        'properties': event['properties'] ?? <String, dynamic>{},
      });
    } catch (_) {
      // Keep local event even if cloud insert fails.
    }
  }
}
