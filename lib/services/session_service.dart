import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();
  static const String keySignedIn = 'session_signed_in';
  static const String keyLocalProfileReady = 'session_local_profile_ready';
  static const String _localEmailKey = 'session_local_email_v1';
  static const String _localPasswordHashKey = 'session_local_password_hash_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _random = Random.secure();

  Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keySignedIn) ?? false;
  }

  Future<void> setSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySignedIn, value);
  }

  Future<bool> hasLocalAccount() async {
    final email = await _secureStorage.read(key: _localEmailKey);
    final passwordHash = await _secureStorage.read(key: _localPasswordHashKey);
    return (email?.isNotEmpty ?? false) && (passwordHash?.isNotEmpty ?? false);
  }

  Future<bool> hasLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileReady = prefs.getBool(keyLocalProfileReady) ?? false;
    if (profileReady) return true;
    if (await hasLocalAccount()) return true;
    final displayName = (prefs.getString('user_profile_display_name') ?? '').trim();
    final email = (prefs.getString('user_profile_email') ?? '').trim();
    return displayName.isNotEmpty || email.isNotEmpty;
  }

  Future<void> markLocalProfileReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyLocalProfileReady, true);
  }

  Future<String?> getLocalAccountEmail() async {
    final email = await _secureStorage.read(key: _localEmailKey);
    if (email == null || email.trim().isEmpty) return null;
    return email.trim();
  }

  Future<void> registerLocalAccount({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    await _secureStorage.write(key: _localEmailKey, value: normalizedEmail);
    await _secureStorage.write(
      key: _localPasswordHashKey,
      value: await _hashCredentials(
        email: normalizedEmail,
        password: normalizedPassword,
      ),
    );
  }

  Future<bool> verifyLocalCredentials({
    required String email,
    required String password,
  }) async {
    final storedEmail = await _secureStorage.read(key: _localEmailKey);
    final storedHash = await _secureStorage.read(key: _localPasswordHashKey);
    if (storedEmail == null || storedHash == null) return false;
    final normalizedEmail = email.trim().toLowerCase();
    if (storedEmail.trim().toLowerCase() != normalizedEmail) return false;

    if (storedHash.contains(':')) {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;
      final salt = base64Decode(parts[0]);
      final expectedHash = parts[1];
      final hash = await _hashWithSalt(
        email: normalizedEmail,
        password: password.trim(),
        salt: salt,
      );
      return hash == expectedHash;
    }

    final legacyHash = await _hashLegacy(
      email: normalizedEmail,
      password: password.trim(),
    );
    if (legacyHash == storedHash) {
      await _secureStorage.write(
        key: _localPasswordHashKey,
        value: await _hashCredentials(
          email: normalizedEmail,
          password: password.trim(),
        ),
      );
      return true;
    }
    return false;
  }

  Future<String> _hashCredentials({
    required String email,
    required String password,
  }) async {
    final salt = _generateSalt();
    final hash = await _hashWithSalt(
      email: email,
      password: password,
      salt: salt,
    );
    return '${base64Encode(salt)}:$hash';
  }

  Future<String> _hashWithSalt({
    required String email,
    required String password,
    required List<int> salt,
  }) async {
    final payload = utf8.encode('$salt::$email::$password');
    final digest = await Sha256().hash(payload);
    return base64Encode(digest.bytes);
  }

  Future<String> _hashLegacy({
    required String email,
    required String password,
  }) async {
    final payload = utf8.encode('$email::$password');
    final digest = await Sha256().hash(payload);
    return base64Encode(digest.bytes);
  }

  List<int> _generateSalt() {
    return List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
  }
}
