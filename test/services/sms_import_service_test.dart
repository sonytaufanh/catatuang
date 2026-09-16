import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/sms_import_service.dart';

void main() {
  final service = SmsImportService.instance;

  test('parses a debit SMS as expense', () {
    final result = service.parse(
      '16/09/2026 14:03 Transaksi DEBIT Rp 125.000 di Indomaret. Saldo Rp 2.500.000',
    );
    expect(result, isNotNull);
    expect(result!.isExpense, isTrue);
    expect(result.amount, 125000);
    expect(result.date, DateTime(2026, 9, 16));
  });

  test('parses a credit salary SMS as income', () {
    final result = service.parse(
      '17/09/2026 KREDIT GAJI sebesar Rp 8.000.000 telah masuk ke rekening',
    );
    expect(result, isNotNull);
    expect(result!.isExpense, isFalse);
    expect(result.amount, 8000000);
    expect(result.category, 'salary');
  });

  test('returns null for non-financial messages', () {
    expect(service.parse('Halo apa kabar hari ini'), isNull);
    expect(service.parse(''), isNull);
  });
}
