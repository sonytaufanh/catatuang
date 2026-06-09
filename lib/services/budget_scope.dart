import '../data/models/transaction_record.dart';

class BudgetScopeSettings {
  const BudgetScopeSettings({
    required this.scopeType,
    required this.scopeValue,
    required this.periodDays,
  });

  final String scopeType;
  final String scopeValue;
  final int periodDays;

  BudgetScopeSettings normalized() {
    final normalizedType = switch (scopeType) {
      'category' => 'category',
      'wallet' => 'wallet',
      _ => 'all',
    };
    return BudgetScopeSettings(
      scopeType: normalizedType,
      scopeValue: scopeValue.trim().toLowerCase(),
      periodDays: 0,
    );
  }
}

int calculateBudgetScopedExpense({
  required List<TransactionRecord> transactions,
  required DateTime now,
  required BudgetScopeSettings settings,
}) {
  final normalized = settings.normalized();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  var total = 0;
  for (final tx in transactions) {
    if (!tx.isExpense) continue;
    final date = tx.transactionDate;
    if (date.isBefore(start) || !date.isBefore(end)) continue;
    if (normalized.scopeType == 'category' &&
        tx.category.trim().toLowerCase() != normalized.scopeValue) {
      continue;
    }
    if (normalized.scopeType == 'wallet' &&
        tx.wallet.trim().toLowerCase() != normalized.scopeValue) {
      continue;
    }
    total += tx.amount;
  }
  return total;
}
