import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/models/transaction_record.dart';
import 'package:catatuang/data/recurring_bill_store.dart';
import 'package:catatuang/services/forecast_service.dart';

TransactionRecord _expense(int amount, DateTime date, {String category = 'food'}) {
  return TransactionRecord()
    ..isExpense = true
    ..amount = amount
    ..wallet = 'cash'
    ..category = category
    ..transactionDate = date
    ..isCleared = true
    ..createdAt = date;
}

void main() {
  final service = ForecastService.instance;
  final now = DateTime(2026, 9, 16, 12);

  test('computes safe-to-spend for the current cycle', () {
    final forecast = service.compute(
      transactions: [_expense(160000, DateTime(2026, 9, 5))],
      bills: [
        const RecurringBill(id: 1, name: 'Listrik', amount: 200000, dueDay: 20),
      ],
      totalBalance: 1000000,
      cycleStartDay: 1,
      now: now,
    );

    expect(forecast.spentThisCycle, 160000);
    expect(forecast.dailyBurnRate, 10000);
    expect(forecast.daysLeftInCycle, 14);
    expect(forecast.upcomingBillsAmount, 200000);
    expect(forecast.safeToSpendToday, 57142);
    expect(forecast.projectedCycleEndBalance, 860000);
  });

  test('excludes transfers from spending', () {
    final forecast = service.compute(
      transactions: [
        _expense(500000, DateTime(2026, 9, 5), category: 'transfer_out'),
      ],
      bills: const [],
      totalBalance: 1000000,
      cycleStartDay: 1,
      now: now,
    );
    expect(forecast.spentThisCycle, 0);
    expect(forecast.dailyBurnRate, 0);
  });

  test('ignores bills due after the cycle ends', () {
    final forecast = service.compute(
      transactions: [_expense(100000, DateTime(2026, 9, 2))],
      bills: [
        // dueDay 2 rolls to next month (16 days away) > 14 days left.
        const RecurringBill(id: 1, name: 'Kartu', amount: 900000, dueDay: 2),
      ],
      totalBalance: 1000000,
      cycleStartDay: 1,
      now: now,
    );
    expect(forecast.upcomingBillsAmount, 0);
  });
}
