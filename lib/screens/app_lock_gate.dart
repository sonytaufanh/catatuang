import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_passcode_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_lock_service.dart';
import '../services/error_log_service.dart';
import '../services/session_service.dart';
import '../services/app_animations.dart';
import '../services/app_ui_tokens.dart';
import '../services/user_profile_service.dart';
import 'main_navigation.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _loading = true;
  bool _submittingAuth = false;
  bool _unlocked = false;
  bool _signedIn = true;
  bool _hasPasscode = false;
  bool _biometricEnabled = false;
  bool _isSignUp = false;
  String _errorMessage = '';
  DateTime? _pausedAt;
  int _passcodeLockSeconds = 0;
  Timer? _lockTimer;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<T?> _showPolishedDialog<T>({
    required String title,
    String? subtitle,
    required Widget child,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppUiTokens.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppUiTokens.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                child,
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      Expanded(child: actions[i]),
                      if (i < actions.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _authFieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: AppUiTokens.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppUiTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppUiTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppUiTokens.brandBlue, width: 1.35),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGate();
    });
  }

  Future<void> _initGate() async {
    try {
      _hasPasscode = await AppPasscodeService.instance.hasPasscode();
      _biometricEnabled = await BiometricLockService.instance.isEnabled();
      _passcodeLockSeconds = await AppPasscodeService.instance
          .getRemainingLockSeconds();
      if (_passcodeLockSeconds > 0) {
        _startLockTimer();
      }
    } catch (e) {
      _hasPasscode = false;
      await ErrorLogService.instance.log(
        source: 'load_passcode_state',
        error: e,
      );
    }
    if (!AuthService.instance.isConfigured) {
      try {
        _isSignUp = !(await SessionService.instance.hasLocalProfile());
        _nameController.text = _profileDisplayName();
      } catch (e) {
        await ErrorLogService.instance.log(
          source: 'local_auth_state',
          error: e,
        );
      }
    }
    var signedIn = false;
    try {
      signedIn = await AuthService.instance.isSignedIn();
    } catch (e) {
      await ErrorLogService.instance.log(source: 'auth_state', error: e);
      signedIn = false;
    }
    if (!mounted) return;
    if (!signedIn) {
      setState(() {
        _signedIn = false;
        _loading = false;
      });
      return;
    }
    setState(() => _signedIn = true);
    await _unlock();
  }

  Future<void> _submitAuth() async {
    if (!AuthService.instance.isConfigured) {
      await _submitLocalAuth();
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (!_isValidEmail(email) || password.length < 6) {
      setState(
        () => _errorMessage = 'Email/password belum valid (min 6 karakter).',
      );
      return;
    }
    setState(() {
      _loading = true;
      _submittingAuth = true;
      _errorMessage = '';
    });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUp(email: email, password: password);
      } else {
        await AuthService.instance.signIn(email: email, password: password);
      }
      if (!mounted) return;
      setState(() => _signedIn = true);
      await _unlock();
    } catch (e) {
      await ErrorLogService.instance.log(source: 'auth_submit', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Autentikasi gagal: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submittingAuth = false);
      }
    }
  }

  Future<void> _submitLocalAuth() async {
    final displayName = _nameController.text.trim();
    if (_isSignUp && displayName.length < 2) {
      setState(() => _errorMessage = 'Nama profil minimal 2 karakter.');
      return;
    }
    setState(() {
      _loading = true;
      _submittingAuth = true;
      _errorMessage = '';
    });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUpLocal(displayName: displayName);
      } else {
        await AuthService.instance.signInLocal();
      }
      if (!mounted) return;
      setState(() => _signedIn = true);
      await _unlock();
    } catch (e) {
      await ErrorLogService.instance.log(source: 'local_auth_submit', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Autentikasi gagal: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submittingAuth = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_signedIn) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (_unlocked &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt).inSeconds >= 20) {
        if (!mounted) return;
        setState(() => _unlocked = false);
      }
    }
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    final biometricEnabled = await BiometricLockService.instance.isEnabled();
    if (!mounted) return;
    if (biometricEnabled) {
      final ok = await BiometricLockService.instance.authenticateIfEnabled();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = true;
        _unlocked = ok;
        _loading = false;
        if (ok) {
          _pausedAt = null;
        } else {
          _errorMessage = 'Verifikasi gagal atau timeout.';
        }
      });
      return;
    }
    if (_hasPasscode) {
      // Passcode-only protection: keep the lock screen so the user must enter
      // the PIN through the "Use Security PIN" action.
      setState(() {
        _biometricEnabled = false;
        _unlocked = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _biometricEnabled = false;
      _unlocked = true;
      _loading = false;
    });
    _pausedAt = null;
  }

  Future<void> _unlockWithPasscode() async {
    if (_passcodeLockSeconds > 0) {
      return;
    }
    final pinController = TextEditingController();
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final pin = await _showPolishedDialog<String>(
      title: isEn ? 'Enter Security PIN' : 'Masukkan PIN Keamanan',
      subtitle: isEn
          ? 'Use your fallback PIN to unlock the app.'
          : 'Gunakan PIN cadangan untuk membuka aplikasi.',
      child: TextField(
        controller: pinController,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _authFieldDecoration(
          label: isEn ? 'Security PIN' : 'PIN Keamanan',
          hint: isEn ? '4-6 digits' : '4-6 digit',
          icon: Icons.pin_rounded,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isEn ? 'Cancel' : 'Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pinController.text),
          child: Text(isEn ? 'Unlock' : 'Buka'),
        ),
      ],
    );
    if (pin == null || pin.isEmpty) return;
    if (!_isValidPin(pin)) {
      setState(() {
        _errorMessage = isEn
            ? 'PIN must be 4-6 digits.'
            : 'PIN harus 4-6 digit.';
      });
      return;
    }
    final ok = await AppPasscodeService.instance.verifyPasscode(pin);
    if (!mounted) return;
    if (ok) {
      await AppPasscodeService.instance.clearFailedAttempts();
      if (!mounted) return;
      _pausedAt = null;
      setState(() {
        _unlocked = true;
        _errorMessage = '';
      });
      return;
    }
    final lockSeconds = await AppPasscodeService.instance
        .registerFailedAttemptAndGetRemaining();
    final failed = await AppPasscodeService.instance.getFailedAttempts();
    final attemptsLeft = (AppPasscodeService.maxAttempts - failed).clamp(
      0,
      AppPasscodeService.maxAttempts,
    );
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      if (lockSeconds > 0) {
        _passcodeLockSeconds = lockSeconds;
        _errorMessage = isEn
            ? 'Too many attempts. Try again in $lockSeconds seconds.'
            : 'Terlalu banyak percobaan. Coba lagi dalam $lockSeconds detik.';
      } else {
        _errorMessage = isEn
            ? 'PIN is incorrect. Attempts left: $attemptsLeft.'
            : 'PIN tidak sesuai. Sisa percobaan: $attemptsLeft.';
      }
    });
    if (lockSeconds > 0) {
      _startLockTimer();
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool _isValidPin(String value) {
    return RegExp(r'^\d{4,6}$').hasMatch(value);
  }

  String _profileDisplayName() {
    final raw = UserProfileService.instance.displayName.trim();
    if (raw.isNotEmpty && raw != 'Pengguna') return raw;
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) return typed;
    return 'Pengguna';
  }

  String _localTitle(bool isEn) => _isSignUp
      ? (isEn ? 'Create Local Profile' : 'Buat Profil Lokal')
      : (isEn ? 'Open Profile' : 'Buka Profil');

  String _localSubtitle(bool isEn) => _isSignUp
      ? (isEn
            ? 'Save a simple profile on this device without email or password'
            : 'Simpan profil sederhana di perangkat ini tanpa email dan password')
      : (isEn
            ? 'Use your local profile on this device'
            : 'Gunakan profil lokal di perangkat ini');

  String _localCta(bool isEn) => _isSignUp
      ? (isEn ? 'Start Using the App' : 'Mulai Pakai Aplikasi')
      : (isEn ? 'Open Profile' : 'Buka Profil');

  String _localModeHint(bool isEn) => isEn
      ? 'Local profile mode is active. No email or password is needed.'
      : 'Mode profil lokal aktif. Tidak perlu email atau password.';

  String _profileInitials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'CU';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await AppPasscodeService.instance
          .getRemainingLockSeconds();
      if (!mounted) return;
      if (remaining <= 0) {
        _lockTimer?.cancel();
        setState(() {
          _passcodeLockSeconds = 0;
          if (_errorMessage.contains('detik') ||
              _errorMessage.contains('seconds')) {
            _errorMessage = '';
          }
        });
      } else {
        setState(() => _passcodeLockSeconds = remaining);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    late final Widget content;
    late final String stateKey;
    if (_unlocked) {
      stateKey = 'main_navigation';
      content = const MainNavigation();
    } else if (_loading) {
      stateKey = 'loading';
      content = Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Menyiapkan aplikasi...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppUiTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (!_signedIn) {
      final isLocalMode = !AuthService.instance.isConfigured;
      final profileName = _profileDisplayName();
      stateKey = 'signed_out';
      content = Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppUiTokens.surfaceBlueSoft, AppUiTokens.surfaceSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppUiTokens.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppUiTokens.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: AppAnimations.normal,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                        child: isLocalMode && !_isSignUp
                            ? Container(
                                key: const ValueKey('local_continue'),
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppUiTokens.surfaceBlueSoft,
                                      AppUiTokens.white,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppUiTokens.brandBlueBorder,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        gradient: AppUiTokens.brandGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppUiTokens.brandBlue
                                                .withValues(alpha: 0.22),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _profileInitials(profileName),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppUiTokens.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isEn
                                          ? 'Welcome back,'
                                          : 'Selamat datang kembali,',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppUiTokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profileName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppUiTokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _localSubtitle(isEn),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        height: 1.4,
                                        color: AppUiTokens.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Row(
                                key: const ValueKey('signup_header'),
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppUiTokens.brandBlueTint,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.lock_person_rounded,
                                      color: AppUiTokens.brandBlueDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isLocalMode
                                              ? _localTitle(isEn)
                                              : (_isSignUp
                                                    ? (isEn
                                                          ? 'Create Profile'
                                                          : 'Buat Profil')
                                                    : (isEn
                                                          ? 'Open Profile'
                                                          : 'Buka Profil')),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          isLocalMode
                                              ? _localSubtitle(isEn)
                                              : 'Amanin data keuangan kamu',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppUiTokens.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 14),
                      if (isLocalMode)
                        AnimatedSwitcher(
                          duration: AppAnimations.normal,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _isSignUp
                              ? Container(
                                  key: const ValueKey('local_signup_body'),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppUiTokens.surfaceSoft,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppUiTokens.borderSoft,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEn
                                            ? 'This local profile will be used as your app identity on this device.'
                                            : 'Profil lokal ini akan dipakai sebagai identitas aplikasi di perangkat ini.',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppUiTokens.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _nameController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        onChanged: (_) => setState(() {}),
                                        decoration: _authFieldDecoration(
                                          label: isEn
                                              ? 'Profile Name'
                                              : 'Nama Profil',
                                          hint: isEn
                                              ? 'For example: Sony'
                                              : 'Contoh: Sony',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppUiTokens.brandGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _profileInitials(profileName),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: AppUiTokens.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              profileName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppUiTokens.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('local_continue_body'),
                                  height: 2,
                                ),
                        ),
                      if (!isLocalMode) ...[
                        TextField(
                          controller: _emailController,
                          decoration: _authFieldDecoration(
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _authFieldDecoration(
                            label: 'Password',
                            hint: isEn
                                ? 'At least 6 characters'
                                : 'Minimal 6 karakter',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          button: true,
                          label: isLocalMode
                              ? (_isSignUp
                                    ? 'Buat profil lokal'
                                    : 'Buka profil')
                              : (_isSignUp ? 'Buat akun' : 'Buka akun'),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: AppUiTokens.brandBlue,
                            ),
                            onPressed: _submittingAuth ? null : _submitAuth,
                            child: _submittingAuth
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Text(
                                    isLocalMode
                                        ? _localCta(isEn)
                                        : (_isSignUp
                                              ? 'Buat Akun'
                                              : 'Buka Akun'),
                                  ),
                          ),
                        ),
                      ),
                      if (!isLocalMode) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = '';
                            }),
                            child: Text(
                              _isSignUp
                                  ? 'Sudah punya profil? Buka'
                                  : 'Belum punya profil? Buat',
                            ),
                          ),
                        ),
                      ],
                      if (isLocalMode)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppUiTokens.surfaceBlueSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _localModeHint(isEn),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppUiTokens.textMutedDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppUiTokens.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      stateKey = 'locked_gate';
      content = Scaffold(
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppUiTokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: AppUiTokens.brandBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  isEn ? 'App is locked' : 'Aplikasi terkunci',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _biometricEnabled
                      ? (isEn
                            ? 'Verify biometrics to continue'
                            : 'Verifikasi biometrik untuk lanjut')
                      : (isEn
                            ? 'Enter your Security PIN to continue'
                            : 'Masukkan PIN Keamanan untuk lanjut'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppUiTokens.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                if (_biometricEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        isEn
                            ? 'Unlock with Biometrics'
                            : 'Buka dengan Biometrik',
                      ),
                    ),
                  ),
                if (_hasPasscode) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _passcodeLockSeconds > 0
                          ? null
                          : _unlockWithPasscode,
                      icon: const Icon(Icons.pin_rounded),
                      label: Text(
                        isEn ? 'Use Security PIN' : 'Gunakan PIN Keamanan',
                      ),
                    ),
                  ),
                  if (_passcodeLockSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isEn
                            ? 'PIN locked for $_passcodeLockSeconds seconds.'
                            : 'PIN dikunci $_passcodeLockSeconds detik.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppUiTokens.dangerDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    if (!mounted) return;
                    setState(() {
                      _signedIn = false;
                      _errorMessage = '';
                    });
                  },
                  child: const Text('Tutup Profil'),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppUiTokens.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: AppAnimations.slow,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(stateKey), child: content),
    );
  }
}
