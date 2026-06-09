import 'package:flutter/material.dart';

class AppUiTokens {
  AppUiTokens._();

  // Brand palette
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandBlueDark = Color(0xFF1D4ED8);
  static const Color brandBlueSoft = Color(0xFF0EA5E9);
  static const Color brandBlueLight = Color(0xFFEAF2FF);
  static const Color brandBlueBorder = Color(0xFFBFDBFE);

  // Semantic palette
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFF0EA5E9);
  static const Color dangerDark = Color(0xFFBE123C);
  static const Color dangerStrong = Color(0xFFDC2626);
  static const Color dangerDeep = Color(0xFFB91C1C);
  static const Color warningMedium = Color(0xFFB45309);
  static const Color successDark = Color(0xFF059669);
  static const Color successDeep = Color(0xFF047857);
  static const Color successStrong = Color(0xFF16A34A);
  static const Color warningDark = Color(0xFFEA580C);
  static const Color warningAccent = Color(0xFFF97316);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color blueAccent = Color(0xFF3B82F6);

  // Neutral palette
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black54 = Color(0x8A000000);
  static const Color transparent = Color(0x00000000);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textPrimarySoft = Color(0xFF334155);
  static const Color textNavy = Color(0xFF1E3A8A);
  static const Color textNavyStrong = Color(0xFF1E40AF);
  static const Color textBody = Color(0xFF374151);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textMutedDeep = Color(0xFF475569);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDarkMuted = Color(0xFF4B5563);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xFFE5E7EB);
  static const Color borderUltraSoft = Color(0xFFEFF2F6);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color surfaceBlueSoft = Color(0xFFEFF6FF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color surfaceAppLight = Color(0xFFF4F6F9);
  static const Color surfaceAppDark = Color(0xFF0B1220);
  static const Color surfaceDarkCard = Color(0xFF111827);
  static const Color surfaceDarkAppBar = Color(0xFF0F172A);
  static const Color brandBlueTint = Color(0xFFDBEAFE);
  static const Color brandBlueBorderStrong = Color(0xFF93C5FD);
  static const Color surfaceTintBlue = Color(0xFFE0F2FE);
  static const Color surfaceGradientStart = Color(0xFFF7FAFF);
  static const Color surfaceGradientEnd = Color(0xFFF0F6FF);
  static const Color labelBlue = Color(0xFF0369A1);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color successSoftBorder = Color(0xFFA7F3D0);
  static const Color successSoftTrack = Color(0xFFD1FAE5);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color warningSoftBorder = Color(0xFFFED7AA);
  static const Color warningSoftText = Color(0xFF9A3412);
  static const Color dangerSoftBorder = Color(0xFFFECACA);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandBlueSoft, brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fabGradient = LinearGradient(
    colors: [brandBlueSoft, brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 22;
  static const double radiusFull = 999;

  // Typography scale
  static const double textXs = 10;
  static const double textSm = 11;
  static const double textMd = 12;
  static const double textLg = 13;
  static const double textXl = 14;
  static const double textTitle = 18;
  static const double textDisplay = 22;

  // Spacing scale
  static const double space2 = 4;
  static const double space3 = 6;
  static const double space4 = 8;
  static const double space5 = 10;
  static const double space6 = 12;
  static const double space8 = 16;
  static const double space10 = 20;
  static const double space12 = 24;
}
