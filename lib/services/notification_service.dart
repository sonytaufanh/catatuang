import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/database_service.dart';
import '../data/recurring_bill_store.dart';
import '../data/models/transaction_record.dart';
import 'app_settings.dart';
import 'analytics_service.dart';
import 'budget_scope.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String keyNotifTagihan = 'notif_tagihan';
  static const String keyNotifAnggaran = 'notif_anggaran';
  static const String keyNotifRingkasan = 'notif_ringkasan';
  static const String keyBudgetLimit = 'budget_limit';
  static const String keyBudgetThreshold = 'budget_threshold';
  static const String keyBudgetScopeType = 'budget_scope_type';
  static const String keyBudgetScopeValue = 'budget_scope_value';
  static const String keyBudgetPeriodDays = 'budget_period_days';
  static const String keyRingkasanHour = 'ringkasan_hour';
  static const String keyRingkasanMinute = 'ringkasan_minute';

  static const int idRingkasanHarian = 1000;
  static const int idAnggaranHarian = 2000;
  static const int idTagihanBase = 3000;
  static const int idRetentionNudge = 4001;
  static final ValueNotifier<int> budgetSettingsVersion = ValueNotifier<int>(0);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static void notifyBudgetSettingsChanged() {
    budgetSettingsVersion.value++;
  }

  /// Removes persisted budget/notification budget settings.
  Future<void> clearBudgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyBudgetLimit);
    await prefs.remove(keyBudgetThreshold);
    await prefs.remove(keyBudgetScopeType);
    await prefs.remove(keyBudgetScopeValue);
    await prefs.remove(keyBudgetPeriodDays);
    notifyBudgetSettingsChanged();
  }

  Future<void> init({bool requestPermission = false}) async {
    await _ensureInitialized(requestPermission: requestPermission);
  }

  Future<void> _ensureInitialized({bool requestPermission = false}) async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    if (requestPermission) {
      await _requestAndroidPermission();
    }
    _initialized = true;
  }

  Future<void> _requestAndroidPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    const androidDetails = AndroidNotificationDetails(
      'catatuang_general',
      'Notifikasi CatatUang',
      channelDescription: 'Notifikasi umum aplikasi CatatUang',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    await _ensureInitialized();
    final schedule = _nextInstanceOfTime(time);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      schedule,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'catatuang_daily',
          'Pengingat Harian',
          channelDescription: 'Pengingat ringkasan harian dan anggaran',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleRecurringBills(List<RecurringBill> bills) async {
    await _ensureInitialized();
    int index = 0;
    for (final bill in bills) {
      final schedule = _nextInstanceOfMonthDay(
        bill.dueDay,
        const TimeOfDay(hour: 8, minute: 0),
      );
      final id = idTagihanBase + index;
      await _plugin.zonedSchedule(
        id,
        'Tagihan Jatuh Tempo',
        '${bill.name} jatuh tempo hari ini',
        schedule,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'catatuang_bills',
            'Tagihan Rutin',
            channelDescription: 'Pengingat tagihan rutin bulanan',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      index += 1;
    }
  }

  Future<void> cancel(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id);
  }

  Future<void> cancelAllBills() async {
    await _ensureInitialized();
    for (int i = 0; i < 50; i += 1) {
      await _plugin.cancel(idTagihanBase + i);
    }
  }

  Future<void> syncFromPreferences() async {
    await _ensureInitialized(requestPermission: true);
    final prefs = await SharedPreferences.getInstance();
    final notifTagihan = prefs.getBool(keyNotifTagihan) ?? true;
    final notifAnggaran = prefs.getBool(keyNotifAnggaran) ?? true;
    final notifRingkasan = prefs.getBool(keyNotifRingkasan) ?? false;
    final currencyCode = prefs.getString(AppSettings.keyCurrency) ?? 'IDR';
    final languageCode = prefs.getString(AppSettings.keyLanguage) ?? 'id';
    final ringkasanHour = prefs.getInt(keyRingkasanHour) ?? 20;
    final ringkasanMinute = prefs.getInt(keyRingkasanMinute) ?? 0;

    if (notifRingkasan) {
      await scheduleDaily(
        id: idRingkasanHarian,
        title: _t(languageCode, 'daily_summary_title'),
        body: _t(languageCode, 'daily_summary_body'),
        time: TimeOfDay(hour: ringkasanHour, minute: ringkasanMinute),
      );
    } else {
      await cancel(idRingkasanHarian);
    }

    if (notifTagihan) {
      await cancelAllBills();
      await scheduleRecurringBills(recurringBillsNotifier.value);
    } else {
      await cancelAllBills();
    }

    if (notifAnggaran) {
      await scheduleDaily(
        id: idAnggaranHarian,
        title: _t(languageCode, 'budget_check_title'),
        body: _t(languageCode, 'budget_check_body'),
        time: const TimeOfDay(hour: 20, minute: 30),
      );
      await _checkBudgetAndNotify(currencyCode, languageCode);
    } else {
      await cancel(idAnggaranHarian);
    }

    await _trackRetentionSignals(
      notifRingkasan: notifRingkasan,
      languageCode: languageCode,
    );
  }

  Future<void> warmUpInBackground() async {
    await _ensureInitialized();
  }

  Future<void> _checkBudgetAndNotify(
    String currencyCode,
    String languageCode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final limit = prefs.getInt(keyBudgetLimit) ?? 1000000;
    final threshold = prefs.getInt(keyBudgetThreshold) ?? 80;
    final scopeType = prefs.getString(keyBudgetScopeType) ?? 'all';
    final scopeValue = prefs.getString(keyBudgetScopeValue) ?? '';
    final periodDays = prefs.getInt(keyBudgetPeriodDays) ?? 0;
    final now = DateTime.now();
    final txs = await DatabaseService.instance.getAllTransactions();
    final total = calculateBudgetScopedExpense(
      transactions: txs,
      now: now,
      settings: BudgetScopeSettings(
        scopeType: scopeType,
        scopeValue: scopeValue,
        periodDays: periodDays,
      ),
    );
    final target = (limit * threshold / 100).round();
    if (total >= target && limit > 0) {
      final scopeLabel = _budgetScopeLabel(
        languageCode: languageCode,
        scopeType: scopeType,
        scopeValue: scopeValue,
        periodDays: periodDays,
      );
      await showNow(
        id: idAnggaranHarian + 1,
        title: _t(languageCode, 'budget_alert_title'),
        body: _t(
          languageCode,
          'budget_alert_body',
          args: {
            'amount': _formatCurrency(total, currencyCode),
            'threshold': '$threshold%',
            'scope': scopeLabel,
          },
        ),
      );
    }
  }

  String _formatCurrency(int value, String currencyCode) {
    final separator = (currencyCode == 'USD' || currencyCode == 'SGD')
        ? ','
        : '.';
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => separator,
    );
    final symbol = (currencyCode == 'USD' || currencyCode == 'SGD')
        ? '\$'
        : currencyCode == 'MYR'
        ? 'RM'
        : 'Rp';
    return '$symbol $text';
  }

  String _t(String languageCode, String key, {Map<String, String>? args}) {
    final data = _localizedMessages[languageCode] ?? _localizedMessages['id']!;
    var value = data[key] ?? key;
    if (args != null) {
      args.forEach((placeholder, replacement) {
        value = value.replaceAll('{$placeholder}', replacement);
      });
    }
    return value;
  }

  static const Map<String, Map<String, String>> _localizedMessages = {
    'id': {
      'daily_summary_title': 'Ringkasan Harian',
      'daily_summary_body': 'Catat pemasukan dan pengeluaran hari ini.',
      'budget_check_title': 'Cek Anggaran Bulanan',
      'budget_check_body': 'Pantau progres anggaran agar tetap terkendali.',
      'budget_alert_title': 'Batas Anggaran',
      'budget_alert_body':
          'Pengeluaran {scope} sudah {amount} (>= {threshold} dari limit).',
      'retention_nudge_title': 'Yuk lanjut catat keuangan',
      'retention_nudge_body':
          'Sudah beberapa hari belum ada catatan. Buka CatatUang dan lanjutkan progresmu.',
    },
    'en': {
      'daily_summary_title': 'Daily Summary',
      'daily_summary_body': 'Record your income and expenses today.',
      'budget_check_title': 'Monthly Budget Check',
      'budget_check_body': 'Keep your budget on track.',
      'budget_alert_title': 'Budget Limit',
      'budget_alert_body':
          'Your spending for {scope} is already {amount} (>= {threshold} of the limit).',
      'retention_nudge_title': 'Keep your finance streak going',
      'retention_nudge_body':
          'No records for a few days. Open CatatUang and continue your progress.',
    },
  };

  String _budgetScopeLabel({
    required String languageCode,
    required String scopeType,
    required String scopeValue,
    required int periodDays,
  }) {
    final normalizedType = scopeType.trim().toLowerCase();
    if (normalizedType == 'category' && scopeValue.trim().isNotEmpty) {
      return languageCode == 'en'
          ? 'category "$scopeValue" this month'
          : 'kategori "$scopeValue" bulan ini';
    }
    if (normalizedType == 'wallet' && scopeValue.trim().isNotEmpty) {
      return languageCode == 'en'
          ? 'wallet "$scopeValue" this month'
          : 'dompet "$scopeValue" bulan ini';
    }
    return languageCode == 'en'
        ? 'all spending this month'
        : 'semua pengeluaran bulan ini';
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfMonthDay(int day, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    final normalizedDay = day.clamp(1, 31);
    var year = now.year;
    var month = now.month;
    final currentMonthDay = _safeDayInMonth(year, month, normalizedDay);
    var scheduled = tz.TZDateTime(
      tz.local,
      year,
      month,
      currentMonthDay,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      final nextMonth = tz.TZDateTime(tz.local, year, month + 1, 1);
      final nextMonthDay = _safeDayInMonth(
        nextMonth.year,
        nextMonth.month,
        normalizedDay,
      );
      scheduled = tz.TZDateTime(
        tz.local,
        nextMonth.year,
        nextMonth.month,
        nextMonthDay,
        time.hour,
        time.minute,
      );
    }
    return scheduled;
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = tz.TZDateTime(tz.local, year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

  Future<void> _trackRetentionSignals({
    required bool notifRingkasan,
    required String languageCode,
  }) async {
    final txs = await DatabaseService.instance.getAllTransactions();
    final prefs = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(DateTime.now());
    final activeDays = _activeDaysSet(txs);

    final streak = _currentStreak(activeDays, today);
    if (streak == 1) {
      final key = 'retention_streak_started_day';
      final todayKey = today.toIso8601String();
      if (prefs.getString(key) != todayKey) {
        await AnalyticsService.instance.track('streak_started');
        await prefs.setString(key, todayKey);
      }
    }

    final activeDays7 = _activeDaysInLast7(activeDays, today);
    if (activeDays7 >= 5) {
      final weekKey = _weekKey(today);
      final key = 'retention_challenge_week';
      if (prefs.getString(key) != weekKey) {
        await AnalyticsService.instance.track('challenge_completed');
        await prefs.setString(key, weekKey);
      }
    }

    final latestActive = _latestActiveDay(activeDays);
    if (latestActive != null && today.difference(latestActive).inDays >= 2) {
      final key = 'retention_missed_day_notified';
      final todayKey = today.toIso8601String();
      if (prefs.getString(key) != todayKey) {
        await AnalyticsService.instance.track('day_missed');
        await prefs.setString(key, todayKey);
        if (notifRingkasan) {
          await showNow(
            id: idRetentionNudge,
            title: _t(languageCode, 'retention_nudge_title'),
            body: _t(languageCode, 'retention_nudge_body'),
          );
        }
      }
    }
  }

  Set<DateTime> _activeDaysSet(List<TransactionRecord> txs) {
    final set = <DateTime>{};
    for (final tx in txs) {
      set.add(DateUtils.dateOnly(tx.transactionDate));
    }
    return set;
  }

  int _currentStreak(Set<DateTime> activeDays, DateTime today) {
    var streak = 0;
    var cursor = today;
    while (activeDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _activeDaysInLast7(Set<DateTime> activeDays, DateTime today) {
    var count = 0;
    for (var i = 0; i < 7; i += 1) {
      final day = today.subtract(Duration(days: i));
      if (activeDays.contains(day)) count += 1;
    }
    return count;
  }

  DateTime? _latestActiveDay(Set<DateTime> activeDays) {
    if (activeDays.isEmpty) return null;
    final list = activeDays.toList()..sort((a, b) => b.compareTo(a));
    return list.first;
  }

  String _weekKey(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-$week';
  }
}
