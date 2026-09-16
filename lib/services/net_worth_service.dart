import '../data/models/transaction_record.dart';

class MonthlyCashflow {
  const MonthlyCashflow({
    required this.month,
    required this.income,
    required this.expense,
    required this.closingBalance,
  });

  final DateTime month;
  final int income;
  final int expense;
  final int closingBalance;

  int get net => income - expense;
}

class NetWorthSummary {
  const NetWorthSummary({required this.netWorth, required this.months});

  final int netWorth;
  final List<MonthlyCashflow> months;
}

class NetWorthService {
  NetWorthService._();

  static final NetWorthService instance = NetWorthService._();

  /// Builds a net worth series and monthly cashflow for the last [months]
  /// calendar months. Transfers are excluded from income/expense but included
  /// (netting to zero) in the running balance.
  NetWorthSummary compute({
    required List<TransactionRecord> transactions,
    required int openingBalance,
    DateTime? now,
    int months = 12,
  }) {
    final reference = now ?? DateTime.now();
    final monthStarts = <DateTime>[];
    for (var i = months - 1; i >= 0; i--) {
      monthStarts.add(DateTime(reference.year, reference.month - i, 1));
    }
    final firstMonth = monthStarts.first;

    var runningBalance = openingBalance;
    for (final tx in transactions) {
      if (!tx.transactionDate.isBefore(firstMonth)) continue;
      runningBalance += tx.isExpense ? -tx.amount : tx.amount;
    }
    final result = <MonthlyCashflow>[];
    for (final monthStart in monthStarts) {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      var income = 0;
      var expense = 0;
      var signed = 0;
      for (final tx in transactions) {
        final date = tx.transactionDate;
        if (date.isBefore(monthStart) || !date.isBefore(monthEnd)) continue;
        final isTransfer =
            tx.category == 'transfer_out' || tx.category == 'transfer_in';
        signed += tx.isExpense ? -tx.amount : tx.amount;
        if (isTransfer) continue;
        if (tx.isExpense) {
          expense += tx.amount;
        } else {
          income += tx.amount;
        }
      }
      runningBalance += signed;
      result.add(
        MonthlyCashflow(
          month: monthStart,
          income: income,
          expense: expense,
          closingBalance: runningBalance,
        ),
      );
    }

    // Net worth at the end of the latest month equals the closing balance,
    // which already includes all transactions before the series start.
    return NetWorthSummary(
      netWorth: result.isEmpty ? openingBalance : result.last.closingBalance,
      months: result,
    );
  }

  int balanceForAllTime({
    required List<TransactionRecord> transactions,
    required int openingBalance,
  }) {
    var balance = openingBalance;
    for (final tx in transactions) {
      balance += tx.isExpense ? -tx.amount : tx.amount;
    }
    return balance;
  }
}
