import 'package:flutter/material.dart';

import '../../services/app_localizations.dart';
import '../../services/app_ui_tokens.dart';

String homeCategoryLabel(AppLocalizations t, String key) {
  final normalized = key.trim().toLowerCase();
  switch (normalized) {
    case 'food':
    case 'makanan':
    case 'kuliner':
      return t.t('category_food');
    case 'transport':
    case 'transportasi':
      return t.t('category_transport');
    case 'bills':
    case 'tagihan':
      return t.t('category_bills');
    case 'shopping':
    case 'belanja':
      return t.t('category_shopping');
    case 'health':
    case 'kesehatan':
      return t.t('category_health');
    case 'education':
    case 'pendidikan':
      return t.t('category_education');
    case 'entertainment':
    case 'hiburan':
      return t.t('category_entertainment');
    case 'others':
    case 'lain_lain':
      return t.t('category_others');
    case 'salary':
    case 'gaji':
      return t.t('category_salary');
    case 'freelance':
      return t.t('category_freelance');
    case 'bonus':
      return t.t('category_bonus');
    case 'business':
    case 'usaha':
      return t.t('category_business');
    case 'investment':
    case 'investasi':
      return t.t('category_investment');
    case 'gift':
    case 'hadiah':
      return t.t('category_gift');
    case 'transfer_out':
      return t.t('category_transfer_out');
    case 'transfer_in':
      return t.t('category_transfer_in');
    default:
      return key;
  }
}

Color homeCategoryColor(String key) {
  final normalized = key.trim().toLowerCase();
  switch (normalized) {
    case 'food':
    case 'makanan':
    case 'kuliner':
      return AppUiTokens.warningAccent;
    case 'transport':
    case 'transportasi':
      return AppUiTokens.blueAccent;
    case 'bills':
    case 'tagihan':
      return AppUiTokens.brandBlueSoft;
    case 'shopping':
    case 'belanja':
      return AppUiTokens.pinkAccent;
    default:
      return AppUiTokens.textMuted;
  }
}

List<String> homeWeeklyLabels(AppLocalizations t, DateTime now) {
  final days = t.locale.languageCode == 'en'
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      : const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final today = DateUtils.dateOnly(now);
  return List<String>.generate(7, (index) {
    final day = today.subtract(Duration(days: 6 - index));
    return days[day.weekday - 1];
  }, growable: false);
}
