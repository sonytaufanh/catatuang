import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';
import 'user_profile_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  bool _initialized = false;

  bool get isConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  Future<void> init() async {
    if (_initialized) return;
    if (isConfigured) {
      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    }
    _initialized = true;
  }

  Future<bool> isSignedIn() async {
    if (isConfigured) {
      final session = Supabase.instance.client.auth.currentSession;
      return session != null;
    }
    return SessionService.instance.isSignedIn();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (isConfigured) {
      final result = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (result.user == null) {
        throw Exception('Login gagal.');
      }
      await UserProfileService.instance.setIdentityFromAuthEmail(email);
      return;
    }
    final ok = await SessionService.instance.verifyLocalCredentials(
      email: email,
      password: password,
    );
    if (!ok) {
      throw Exception('Email atau password salah.');
    }
    await SessionService.instance.setSignedIn(true);
    await UserProfileService.instance.setIdentityFromAuthEmail(email);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    if (isConfigured) {
      final result = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (result.user == null) {
        throw Exception('Registrasi gagal.');
      }
      await UserProfileService.instance.setIdentityFromAuthEmail(email);
      return;
    }
    final hasLocalAccount = await SessionService.instance.hasLocalAccount();
    if (hasLocalAccount) {
      throw Exception('Akun lokal sudah terdaftar. Silakan masuk.');
    }
    await SessionService.instance.registerLocalAccount(
      email: email,
      password: password,
    );
    await SessionService.instance.setSignedIn(true);
    await UserProfileService.instance.setIdentityFromAuthEmail(email);
  }

  Future<void> signOut() async {
    if (isConfigured) {
      await Supabase.instance.client.auth.signOut();
      return;
    }
    await SessionService.instance.setSignedIn(false);
  }

  Future<void> signInLocal() async {
    await SessionService.instance.setSignedIn(true);
  }

  Future<void> signUpLocal({
    required String displayName,
  }) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Nama profil tidak boleh kosong.');
    }
    await UserProfileService.instance.updateDisplayName(normalizedName);
    await SessionService.instance.markLocalProfileReady();
    await SessionService.instance.setSignedIn(true);
  }
}
