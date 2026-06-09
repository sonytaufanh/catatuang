import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/models/transaction_record.dart';
import 'package:catatuang/services/budget_scope.dart';

void main() {
  TransactionRecord tx({
    required bool isExpense,
    required int amount,
    required String wallet,
    required String category,
    required DateTime date,
  }) {
    return TransactionRecord()
      ..isExpense = isExpense
      ..amount = amount
      ..wallet = wallet
      ..category = category
      ..transactionDate = date
      ..isCleared = true
      ..createdAt = date;
  }

  test('calculateBudgetScopedExpense filters by wallet and date', () {
    final now = DateTime(2026, 3, 2, 10);
    final data = <TransactionRecord>[
      tx(isExpense: true, amount: 100, wallet: 'cash', category: 'food', date: DateTime(2026, 3, 2)),
      tx(isExpense: true, amount: 200, wallet: 'bank', category: 'food', date: DateTime(2026, 3, 1)),
      tx(isExpense: false, amount: 1000, wallet: 'cash', category: 'salary', date: DateTime(2026, 3, 2)),
      tx(isExpense: true, amount: 300, wallet: 'cash', category: 'bills', date: DateTime(2026, 1, 1)),
    ];

    final total = calculateBudgetScopedExpense(
      transactions: data,
      now: now,
      settings: const BudgetScopeSettings(
        scopeType: 'wallet',
        scopeValue: 'cash',
        periodDays: 7,
      ),
    );

    expect(total, 100);
  });

  test('calculateBudgetScopedExpense filters by category', () {
    final now = DateTime(2026, 3, 2, 10);
    final data = <TransactionRecord>[
      tx(isExpense: true, amount: 120, wallet: 'cash', category: 'food', date: DateTime(2026, 3, 2)),
      tx(isExpense: true, amount: 80, wallet: 'bank', category: 'food', date: DateTime(2026, 3, 2)),
      tx(isExpense: true, amount: 90, wallet: 'bank', category: 'transport', date: DateTime(2026, 3, 2)),
    ];

    final total = calculateBudgetScopedExpense(
      transactions: data,
      now: now,
      settings: const BudgetScopeSettings(
        scopeType: 'category',
        scopeValue: 'food',
        periodDays: 30,
      ),
    );

    expect(total, 200);
  });
}
