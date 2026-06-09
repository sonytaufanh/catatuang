import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/app_settings.dart';

void main() {
  group('AppSettings currency formatting', () {
    test('formats IDR with dot separator', () {
      final settings = AppSettings()..currencyCode = 'IDR';
      expect(settings.formatCurrency(1500000), 'Rp 1.500.000');
    });

    test('formats signed currency values', () {
      final settings = AppSettings()..currencyCode = 'IDR';
      expect(settings.formatSignedCurrency(-1200), '- Rp 1.200');
      expect(settings.formatSignedCurrency(1200), '+ Rp 1.200');
    });

    test('formats compact currency values', () {
      final settings = AppSettings()..currencyCode = 'IDR';
      expect(settings.formatCurrencyCompact(1200), 'Rp 1K');
      expect(settings.formatCurrencyCompact(2500000), 'Rp 2.5M');
    });
  });
}
