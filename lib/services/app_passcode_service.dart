import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPasscodeService {
  AppPasscodeService._();

  static final AppPasscodeService instance = AppPasscodeService._();
  static const String keyPasscodeEnabled = 'app_passcode_enabled';
  static const String _passcodeStorageKey = 'app_passcode_plain_v1';
  static const String _failedAttemptsKey = 'app_passcode_failed_attempts';
  static const String _lockedUntilMsKey = 'app_passcode_locked_until_ms';
  static const int maxAttempts = 5;
  static const int cooldownSeconds = 60;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyPasscodeEnabled) ?? false;
  }

  Future<bool> hasPasscode() async {
    final value = await _secureStorage.read(key: _passcodeStorageKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> setPasscode(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < 4 || normalized.length > 6) {
      throw ArgumentError('PIN harus 4-6 digit.');
    }
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      throw ArgumentError('PIN hanya boleh angka.');
    }
    await _secureStorage.write(key: _passcodeStorageKey, value: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPasscodeEnabled, true);
    await _clearProtectionState(prefs);
  }

  Future<void> disablePasscode() async {
    await _secureStorage.delete(key: _passcodeStorageKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPasscodeEnabled, false);
    await _clearProtectionState(prefs);
  }

  Future<bool> verifyPasscode(String pin) async {
    final stored = await _secureStorage.read(key: _passcodeStorageKey);
    if (stored == null || stored.isEmpty) return false;
    return stored == pin.trim();
  }

  Future<int> getRemainingLockSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilMs = prefs.getInt(_lockedUntilMsKey) ?? 0;
    if (lockedUntilMs <= 0) return 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lockedUntilMs <= nowMs) {
      await _clearProtectionState(prefs);
      return 0;
    }
    return ((lockedUntilMs - nowMs) / 1000).ceil();
  }

  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_failedAttemptsKey) ?? 0;
  }

  Future<void> clearFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearProtectionState(prefs);
  }

  Future<int> registerFailedAttemptAndGetRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = await getRemainingLockSeconds();
    if (remaining > 0) return remaining;

    final current = prefs.getInt(_failedAttemptsKey) ?? 0;
    final next = current + 1;
    if (next >= maxAttempts) {
      final lockUntil = DateTime.now()
          .add(const Duration(seconds: cooldownSeconds))
          .millisecondsSinceEpoch;
      await prefs.setInt(_lockedUntilMsKey, lockUntil);
      await prefs.setInt(_failedAttemptsKey, 0);
      return cooldownSeconds;
    }
    await prefs.setInt(_failedAttemptsKey, next);
    return 0;
  }

  Future<void> _clearProtectionState(SharedPreferences prefs) async {
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockedUntilMsKey);
  }
}
