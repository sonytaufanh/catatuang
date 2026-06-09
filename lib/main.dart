import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'data/database_service.dart';
import 'data/recurring_bill_store.dart';
import 'data/transaction_store.dart';
import 'screens/app_lock_gate.dart';
import 'services/app_settings.dart';
import 'services/app_localizations.dart';
import 'services/app_ui_tokens.dart';
import 'services/backup_service.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/error_log_service.dart';
import 'services/master_data_service.dart';
import 'services/recurring_transaction_service.dart';
import 'services/user_profile_service.dart';

const Duration _startupStepTimeout = Duration(seconds: 5);

class StartupStatus extends ChangeNotifier {
  String currentStep = 'Menyiapkan aplikasi...';
  final List<String> failures = <String>[];
  bool completed = false;

  void markStep(String label) {
    currentStep = label;
    notifyListeners();
  }

  void markFailure(String source, Object error) {
    failures.add('$source: $error');
    notifyListeners();
  }

  void markCompleted() {
    completed = true;
    currentStep = failures.isEmpty
        ? 'Aplikasi siap'
        : 'Aplikasi siap dengan beberapa fitur terbatas';
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(_safeLog(source: 'flutter_error', error: details.exception));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(_safeLog(source: 'platform_dispatcher', error: error));
    return true;
  };

  final settings = AppSettings();
  final startupStatus = StartupStatus();
  final startupFuture =
      runZonedGuarded<Future<void>>(
        () async {
          await _runStartup(settings, startupStatus);
        },
        (error, stack) {
          startupStatus.markFailure('run_zoned_guarded', error);
          unawaited(_safeLog(source: 'run_zoned_guarded', error: error));
        },
      ) ??
      Future<void>.value();

  runApp(
    CatatUangApp(
      settings: settings,
      startupFuture: startupFuture,
      startupStatus: startupStatus,
    ),
  );
}

Future<void> _runStartup(AppSettings settings, StartupStatus status) async {
  await _safeStartupStep(
    'database_init',
    'Memuat database lokal',
    status,
    () => DatabaseService.instance.init(),
  );
  await _safeStartupStep(
    'recurring_bill_store_init',
    'Menyiapkan tagihan rutin',
    status,
    initRecurringBillStore,
  );
  await _safeStartupStep(
    'transaction_store_init',
    'Memuat transaksi',
    status,
    initTransactionStore,
  );
  await _safeStartupStep(
    'auth_init',
    'Menyiapkan autentikasi',
    status,
    () => AuthService.instance.init(),
  );
  await _safeStartupStep(
    'user_profile_init',
    'Memuat profil pengguna',
    status,
    () => UserProfileService.instance.init(),
  );
  await _safeStartupStep(
    'settings_load',
    'Memuat pengaturan',
    status,
    () => settings.load(),
  );
  await _safeStartupStep(
    'master_data_init',
    'Memuat data dompet',
    status,
    () => MasterDataService.instance.init(),
  );
  await _safeStartupStep(
    'backup_auto_if_due',
    'Memeriksa backup otomatis',
    status,
    () => BackupService.instance.autoBackupIfDue(),
  );
  await _safeStartupStep(
    'recurring_transaction_sync_due',
    'Menyinkronkan transaksi berulang',
    status,
    () => RecurringTransactionService.instance.syncDueTransactions(),
  );
  await _safeStartupStep(
    'analytics_app_open',
    'Mencatat pembukaan aplikasi',
    status,
    () => AnalyticsService.instance.track('app_open'),
  );
  status.markCompleted();
}

Future<void> _safeStartupStep(
  String source,
  String label,
  StartupStatus status,
  Future<void> Function() task,
) async {
  try {
    status.markStep(label);
    await task().timeout(
      _startupStepTimeout,
      onTimeout: () =>
          throw TimeoutException('Startup step timed out: $source'),
    );
  } catch (error) {
    status.markFailure(source, error);
    unawaited(_safeLog(source: source, error: error));
  }
}

Future<void> _safeLog({required String source, required Object error}) async {
  try {
    await ErrorLogService.instance.log(source: source, error: error);
  } catch (_) {
    // Avoid crashing app startup when log persistence is unavailable.
  }
}

class CatatUangApp extends StatelessWidget {
  const CatatUangApp({
    super.key,
    required this.settings,
    required this.startupFuture,
    required this.startupStatus,
  });

  final AppSettings settings;
  final Future<void> startupFuture;
  final StartupStatus startupStatus;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CatatUang Warna',
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppThemes.light,
            darkTheme: AppThemes.dark,
            themeMode: settings.themeMode,
            home: _StartupSplashGate(
              startupFuture: startupFuture,
              startupStatus: startupStatus,
            ),
          );
        },
      ),
    );
  }
}

class _StartupSplashGate extends StatefulWidget {
  const _StartupSplashGate({
    required this.startupFuture,
    required this.startupStatus,
  });

  final Future<void> startupFuture;
  final StartupStatus startupStatus;

  @override
  State<_StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<_StartupSplashGate> {
  bool _minDelayDone = false;
  bool _startupDone = false;

  bool get _ready => _minDelayDone && _startupDone;

  @override
  void initState() {
    super.initState();
    widget.startupStatus.addListener(_handleStartupStatusChanged);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _minDelayDone = true);
    });
    widget.startupFuture.whenComplete(() {
      if (!mounted) return;
      setState(() => _startupDone = true);
    });
  }

  void _handleStartupStatusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.startupStatus.removeListener(_handleStartupStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AppLockGate();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppUiTokens.surfaceAppDark
        : AppUiTokens.surfaceAppLight;
    final title = isDark ? const Color(0xFFE5E7EB) : AppUiTokens.textPrimary;
    final subtitle = isDark
        ? const Color(0xFF94A3B8)
        : AppUiTokens.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : AppUiTokens.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppUiTokens.brandBlue.withValues(
                        alpha: isDark ? 0.20 : 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CatatUang by Sony',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: title,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.startupStatus.currentStep,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: subtitle,
                ),
              ),
              if (widget.startupStatus.failures.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x14FFFFFF)
                        : AppUiTokens.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x33FFFFFF)
                          : AppUiTokens.borderSoft,
                    ),
                  ),
                  child: Text(
                    'Beberapa layanan gagal dimuat. Aplikasi tetap berjalan, tetapi sebagian fitur mungkin terbatas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subtitle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
