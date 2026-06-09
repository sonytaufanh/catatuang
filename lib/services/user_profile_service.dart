import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService extends ChangeNotifier {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  static const String _keyDisplayName = 'user_profile_display_name';
  static const String _keyEmail = 'user_profile_email';
  static const String _keyMemberSince = 'user_profile_member_since';

  String _displayName = 'Pengguna';
  String _email = '';
  DateTime _memberSince = DateTime.now();
  bool _initialized = false;

  String get displayName => _displayName;
  String get email => _email;
  DateTime get memberSince => _memberSince;

  String get avatarSeed {
    final seed = _displayName.trim().isNotEmpty ? _displayName : _email;
    if (seed.trim().isEmpty) return 'catatuang-user';
    return seed.replaceAll(' ', '_');
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _displayName = _normalizeName(prefs.getString(_keyDisplayName));
    _email = (prefs.getString(_keyEmail) ?? '').trim();
    final rawMemberSince = prefs.getString(_keyMemberSince);
    final parsed = rawMemberSince == null ? null : DateTime.tryParse(rawMemberSince);
    _memberSince = parsed ?? DateTime.now();
    if (rawMemberSince == null) {
      await prefs.setString(_keyMemberSince, _memberSince.toIso8601String());
    }
    if (_displayName == 'Pengguna' && _email.isNotEmpty) {
      _displayName = _guessNameFromEmail(_email);
    }
    _initialized = true;
  }

  Future<void> setIdentityFromAuthEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) return;
    await init();
    final prefs = await SharedPreferences.getInstance();
    _email = normalizedEmail;
    await prefs.setString(_keyEmail, _email);
    final currentRawName = prefs.getString(_keyDisplayName) ?? '';
    if (currentRawName.trim().isEmpty) {
      _displayName = _guessNameFromEmail(_email);
      await prefs.setString(_keyDisplayName, _displayName);
    }
    notifyListeners();
  }

  Future<void> updateDisplayName(String value) async {
    await init();
    final next = _normalizeName(value);
    _displayName = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, _displayName);
    notifyListeners();
  }

  String _normalizeName(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Pengguna';
    return raw;
  }

  String _guessNameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'Pengguna';
    final cleaned = local.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), ' ');
    final words = cleaned
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'Pengguna';
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
