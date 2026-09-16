import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
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
  final Random _random = Random.secure();

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
    final stored = await _hashPin(normalized);
    await _secureStorage.write(key: _passcodeStorageKey, value: stored);
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
    final normalized = pin.trim();

    if (stored.contains(':')) {
      final parts = stored.split(':');
      if (parts.length != 2) return false;
      final salt = base64Decode(parts[0]);
      final expectedHash = parts[1];
      final hash = await _hashPinWithSalt(normalized, salt);
      return hash == expectedHash;
    }

    final legacyMatch = stored == normalized;
    if (legacyMatch) {
      await _secureStorage.write(
        key: _passcodeStorageKey,
        value: await _hashPin(normalized),
      );
    }
    return legacyMatch;
  }

  Future<String> _hashPin(String pin) async {
    final salt = _generateSalt();
    final hash = await _hashPinWithSalt(pin, salt);
    return '${base64Encode(salt)}:$hash';
  }

  Future<String> _hashPinWithSalt(String pin, List<int> salt) async {
    final payload = utf8.encode('$salt::$pin');
    final digest = await Sha256().hash(payload);
    return base64Encode(digest.bytes);
  }

  List<int> _generateSalt() {
    return List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
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
