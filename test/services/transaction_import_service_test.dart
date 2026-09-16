import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/transaction_import_service.dart';

void main() {
  final service = TransactionImportService.instance;

  test('parses DD/MM/YYYY with negative amount as expense', () {
    final rows = service.parse('16/09/2026; Indomaret; -125000');
    expect(rows, hasLength(1));
    expect(rows.first.isExpense, isTrue);
    expect(rows.first.amount, 125000);
    expect(rows.first.category, 'shopping');
    expect(rows.first.date, DateTime(2026, 9, 16));
  });

  test('parses ISO date and positive amount as income', () {
    final rows = service.parse('2026-09-16, Gaji Bulanan, 8000000');
    expect(rows, hasLength(1));
    expect(rows.first.isExpense, isFalse);
    expect(rows.first.amount, 8000000);
    expect(rows.first.category, 'salary');
  });

  test('skips header row and supports Rp prefix and parentheses', () {
    const csv = '''
tanggal; keterangan; nominal
16/09/2026; Gojek ke kantor; Rp -25.000
17/09/2026; Belanja bulanan; (50000)
''';
    final rows = service.parse(csv);
    expect(rows, hasLength(2));
    expect(rows[0].category, 'transport');
    expect(rows[0].amount, 25000);
    expect(rows[0].isExpense, isTrue);
    expect(rows[1].amount, 50000);
    expect(rows[1].isExpense, isTrue);
    expect(rows[1].category, 'shopping');
  });

  test('returns empty for garbage input', () {
    expect(service.parse('hello world'), isEmpty);
    expect(service.parse(''), isEmpty);
  });
}
