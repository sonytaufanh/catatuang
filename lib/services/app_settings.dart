import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_ui_tokens.dart';

class AppSettings extends ChangeNotifier {
  static const String keyLanguage = 'app_language';
  static const String keyTheme = 'app_theme';
  static const String keyCurrency = 'app_currency';
  static const String keyCycleStart = 'billing_cycle_start';
  static const String keyTxIncludeTime = 'tx_include_time';

  String languageCode = 'id';
  ThemeMode themeMode = ThemeMode.system;
  String currencyCode = 'IDR';
  int billingCycleStart = 1;
  bool txIncludeTime = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    languageCode = prefs.getString(keyLanguage) ?? languageCode;
    currencyCode = prefs.getString(keyCurrency) ?? currencyCode;
    billingCycleStart = (prefs.getInt(keyCycleStart) ?? billingCycleStart)
        .clamp(1, 31);
    txIncludeTime = prefs.getBool(keyTxIncludeTime) ?? txIncludeTime;
    final themeValue = prefs.getString(keyTheme) ?? 'system';
    themeMode = _themeModeFromValue(themeValue);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLanguage, code);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTheme, _themeModeToValue(mode));
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    currencyCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCurrency, code);
    notifyListeners();
  }

  Future<void> setBillingCycleStart(int day) async {
    billingCycleStart = day.clamp(1, 31);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyCycleStart, billingCycleStart);
    notifyListeners();
  }

  Future<void> setTxIncludeTime(bool value) async {
    txIncludeTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyTxIncludeTime, value);
    notifyListeners();
  }

  Locale get locale => Locale(languageCode);

  String get currencySymbol {
    switch (currencyCode) {
      case 'USD':
      case 'SGD':
        return '\$';
      case 'MYR':
        return 'RM';
      case 'IDR':
      default:
        return 'Rp';
    }
  }

  String get currencyLabel {
    switch (currencyCode) {
      case 'USD':
        return 'USD (\$)';
      case 'SGD':
        return 'SGD (\$)';
      case 'MYR':
        return 'MYR (RM)';
      case 'IDR':
      default:
        return 'IDR (Rp)';
    }
  }

  String formatCurrency(int value) {
    final separator = (currencyCode == 'USD' || currencyCode == 'SGD')
        ? ','
        : '.';
    final digits = _formatWithSeparator(value.abs(), separator);
    return '$currencySymbol $digits';
  }

  String formatSignedCurrency(int value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign ${formatCurrency(value)}';
  }

  String formatBalanceCurrency(int value) {
    if (value < 0) {
      return '- ${formatCurrency(value)}';
    }
    return formatCurrency(value);
  }

  String formatCurrencyCompact(int value) {
    final absValue = value.abs();
    if (absValue >= 1000000) {
      final compact = (absValue / 1000000).toStringAsFixed(1);
      return '$currencySymbol ${compact}M';
    }
    if (absValue >= 1000) {
      final compact = (absValue / 1000).toStringAsFixed(0);
      return '$currencySymbol ${compact}K';
    }
    return formatCurrency(value);
  }

  String _formatWithSeparator(int value, String separator) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i += 1) {
      final reverseIndex = text.length - i;
      buffer.write(text[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }

  ThemeMode _themeModeFromValue(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    if (scope == null) {
      throw StateError('AppSettingsScope tidak ditemukan di widget tree.');
    }
    return scope.notifier!;
  }
}

class AppThemes {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppUiTokens.surfaceAppLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppUiTokens.brandBlue,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppUiTokens.white,
      foregroundColor: AppUiTokens.surfaceDarkCard,
      elevation: 0.5,
      centerTitle: true,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppUiTokens.white,
      modalBackgroundColor: AppUiTokens.white,
      surfaceTintColor: AppUiTokens.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppUiTokens.surfaceSoft,
      hintStyle: const TextStyle(
        color: AppUiTokens.textHint,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: AppUiTokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppUiTokens.textSecondary,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppUiTokens.brandBlue,
        foregroundColor: AppUiTokens.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppUiTokens.brandBlueDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppUiTokens.textNavyStrong,
        side: const BorderSide(color: AppUiTokens.brandBlueBorderStrong),
        minimumSize: const Size.fromHeight(46),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppUiTokens.brandBlue,
        foregroundColor: AppUiTokens.white,
        minimumSize: const Size.fromHeight(46),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: AppUiTokens.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppUiTokens.surfaceAppDark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppUiTokens.brandBlueSoft,
      onPrimary: AppUiTokens.white,
      secondary: AppUiTokens.brandBlue,
      onSecondary: AppUiTokens.white,
      error: AppUiTokens.danger,
      onError: AppUiTokens.white,
      surface: AppUiTokens.surfaceDarkCard,
      onSurface: Color(0xFFE5E7EB),
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: Color(0xFF334155),
      outlineVariant: Color(0xFF1E293B),
      shadow: AppUiTokens.black,
      scrim: AppUiTokens.black,
      inverseSurface: Color(0xFFE5E7EB),
      onInverseSurface: AppUiTokens.textPrimary,
      inversePrimary: AppUiTokens.brandBlueDark,
      surfaceTint: AppUiTokens.brandBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppUiTokens.surfaceDarkAppBar,
      foregroundColor: Color(0xFFE5E7EB),
      elevation: 0,
      centerTitle: true,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: AppUiTokens.surfaceDarkCard,
      elevation: 6,
      surfaceTintColor: AppUiTokens.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1E293B),
      thickness: 0.8,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF94A3B8),
      textColor: Color(0xFFE5E7EB),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIconColor: const Color(0xFF94A3B8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppUiTokens.brandBlueSoft,
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppUiTokens.brandBlue,
        foregroundColor: AppUiTokens.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppUiTokens.brandBlueSoft,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD1D5DB),
        side: const BorderSide(color: Color(0xFF334155)),
        minimumSize: const Size.fromHeight(46),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF0F172A),
      selectedColor: const Color(0xFF1E3A8A),
      secondarySelectedColor: const Color(0xFF1E3A8A),
      disabledColor: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: const TextStyle(
        color: Color(0xFFD1D5DB),
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppUiTokens.white,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppUiTokens.brandBlueSoft;
        }
        return const Color(0xFF94A3B8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppUiTokens.brandBlue.withValues(alpha: 0.45);
        }
        return const Color(0xFF334155);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppUiTokens.brandBlueSoft,
      linearTrackColor: Color(0xFF334155),
      circularTrackColor: Color(0xFF334155),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF111B2D),
      shadowColor: AppUiTokens.black,
      surfaceTintColor: AppUiTokens.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
