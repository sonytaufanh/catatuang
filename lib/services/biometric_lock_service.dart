import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricLockService {
  BiometricLockService._();

  static final BiometricLockService instance = BiometricLockService._();
  static const String keyBiometricLock = 'profile_biometric_lock';
  static const Duration _timeout = Duration(seconds: 8);

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyBiometricLock) ?? false;
  }

  Future<bool> authenticateIfEnabled() async {
    return authenticateForSensitiveAction(
      reason: 'Verifikasi biometrik untuk membuka aplikasi',
    );
  }

  Future<bool> authenticateForSensitiveAction({required String reason}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(keyBiometricLock) ?? false;
    if (!enabled) return true;

    final canCheck = await _auth.canCheckBiometrics.timeout(
      _timeout,
      onTimeout: () => false,
    );
    final isSupported = await _auth.isDeviceSupported().timeout(
      _timeout,
      onTimeout: () => false,
    );
    final canUse = canCheck || isSupported;
    if (!canUse) return true;

    try {
      final available = await _auth.getAvailableBiometrics().timeout(
        _timeout,
        onTimeout: () => <BiometricType>[],
      );
      if (available.isEmpty) return true;

      return await _auth
          .authenticate(
            localizedReason: reason,
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
              useErrorDialogs: true,
            ),
          )
          .timeout(_timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
}
