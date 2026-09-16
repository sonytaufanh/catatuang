import 'package:flutter/material.dart';

import '../data/models/transaction_record.dart';
import '../data/recurring_bill_store.dart';
import 'due_date_service.dart';

class CashForecast {
  const CashForecast({
    required this.safeToSpendToday,
    required this.projectedCycleEndBalance,
    required this.dailyBurnRate,
    required this.daysLeftInCycle,
    required this.upcomingBillsAmount,
    required this.spentThisCycle,
  });

  final int safeToSpendToday;
  final int projectedCycleEndBalance;
  final int dailyBurnRate;
  final int daysLeftInCycle;
  final int upcomingBillsAmount;
  final int spentThisCycle;

  bool get hasData => spentThisCycle > 0 || upcomingBillsAmount > 0;
}

class ForecastService {
  ForecastService._();

  static final ForecastService instance = ForecastService._();

  CashForecast compute({
    required List<TransactionRecord> transactions,
    required List<RecurringBill> bills,
    required int totalBalance,
    required int cycleStartDay,
    required DateTime now,
  }) {
    final range = cycleRange(now, cycleStartDay);
    final totalDays = range.end.difference(range.start).inDays;
    final elapsedDays = (now.difference(range.start).inDays + 1)
        .clamp(1, totalDays <= 0 ? 1 : totalDays)
        .toInt();
    final daysLeft = (totalDays - elapsedDays).clamp(0, 100000).toInt();

    var spentThisCycle = 0;
    for (final tx in transactions) {
      if (!tx.isExpense) continue;
      if (tx.category == 'transfer_out' || tx.category == 'transfer_in') {
        continue;
      }
      final date = tx.transactionDate;
      if (date.isBefore(range.start) || !date.isBefore(range.end)) continue;
      spentThisCycle += tx.amount;
    }

    final dailyBurnRate = spentThisCycle ~/ elapsedDays;

    var upcomingBillsAmount = 0;
    for (final bill in bills) {
      final dueIn = DueDateService.daysUntilDueDate(
        from: now,
        dueDay: bill.dueDay,
      );
      if (dueIn <= daysLeft) {
        upcomingBillsAmount += bill.amount;
      }
    }

    final availableForSpending = totalBalance - upcomingBillsAmount;
    final safeToSpendToday = daysLeft <= 0
        ? 0
        : (availableForSpending <= 0
              ? 0
              : availableForSpending ~/ daysLeft);

    final projectedCycleEndBalance =
        totalBalance - (dailyBurnRate * daysLeft);

    return CashForecast(
      safeToSpendToday: safeToSpendToday,
      projectedCycleEndBalance: projectedCycleEndBalance,
      dailyBurnRate: dailyBurnRate,
      daysLeftInCycle: daysLeft,
      upcomingBillsAmount: upcomingBillsAmount,
      spentThisCycle: spentThisCycle,
    );
  }

  DateTimeRange cycleRange(DateTime now, int cycleStartDay) {
    final normalizedDay = cycleStartDay.clamp(1, 31);
    final currentMonthStartDay = _safeDayInMonth(
      now.year,
      now.month,
      normalizedDay,
    );
    late DateTime start;
    late DateTime end;
    if (now.day >= currentMonthStartDay) {
      start = DateTime(now.year, now.month, currentMonthStartDay);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextStartDay = _safeDayInMonth(
        nextMonth.year,
        nextMonth.month,
        normalizedDay,
      );
      end = DateTime(nextMonth.year, nextMonth.month, nextStartDay);
    } else {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevStartDay = _safeDayInMonth(
        prevMonth.year,
        prevMonth.month,
        normalizedDay,
      );
      start = DateTime(prevMonth.year, prevMonth.month, prevStartDay);
      end = DateTime(now.year, now.month, currentMonthStartDay);
    }
    return DateTimeRange(start: start, end: end);
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }
}
