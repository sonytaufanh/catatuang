import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/models/transaction_record.dart';
import 'package:catatuang/services/net_worth_service.dart';

TransactionRecord _tx({
  required bool isExpense,
  required int amount,
  required DateTime date,
  String category = 'food',
}) {
  return TransactionRecord()
    ..isExpense = isExpense
    ..amount = amount
    ..wallet = 'cash'
    ..category = category
    ..transactionDate = date
    ..isCleared = true
    ..createdAt = date;
}

void main() {
  final service = NetWorthService.instance;
  final now = DateTime(2026, 9, 16);

  test('builds monthly cashflow and closing balance', () {
    final summary = service.compute(
      transactions: [
        _tx(isExpense: false, amount: 500, date: DateTime(2026, 7, 10)),
        _tx(isExpense: true, amount: 100, date: DateTime(2026, 7, 20)),
        _tx(isExpense: true, amount: 200, date: DateTime(2026, 8, 5)),
        _tx(isExpense: false, amount: 300, date: DateTime(2026, 9, 3)),
      ],
      openingBalance: 1000,
      now: now,
      months: 3,
    );

    expect(summary.months, hasLength(3));
    expect(summary.months[0].income, 500);
    expect(summary.months[0].expense, 100);
    expect(summary.months[0].closingBalance, 1400);
    expect(summary.months[1].closingBalance, 1200);
    expect(summary.months[2].closingBalance, 1500);
    expect(summary.netWorth, 1500);
  });

  test('transfers net to zero in the running balance', () {
    final summary = service.compute(
      transactions: [
        _tx(
          isExpense: true,
          amount: 500,
          date: DateTime(2026, 9, 5),
          category: 'transfer_out',
        ),
        _tx(
          isExpense: false,
          amount: 500,
          date: DateTime(2026, 9, 5),
          category: 'transfer_in',
        ),
      ],
      openingBalance: 1000,
      now: now,
      months: 1,
    );
    expect(summary.netWorth, 1000);
    expect(summary.months.first.income, 0);
    expect(summary.months.first.expense, 0);
  });
}
