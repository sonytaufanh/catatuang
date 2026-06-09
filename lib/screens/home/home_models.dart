import 'package:flutter/material.dart';

class HomeDashboardSummary {
  const HomeDashboardSummary({
    required this.totalBalance,
    required this.incomeThisCycle,
    required this.expenseThisCycle,
    required this.weeklyExpenses,
    required this.weeklyExpenseMax,
    required this.weeklyExpenseCategories,
    required this.cycleRange,
    required this.cycleExpensesByCategory,
  });

  final int totalBalance;
  final int incomeThisCycle;
  final int expenseThisCycle;
  final List<double> weeklyExpenses;
  final double weeklyExpenseMax;
  final List<String?> weeklyExpenseCategories;
  final DateTimeRange cycleRange;
  final Map<String, int> cycleExpensesByCategory;
}

class HomeInboxItem {
  const HomeInboxItem({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
    required this.color,
    required this.sortValue,
    this.actionLabel,
    this.actionType,
    this.isExpense,
    this.category,
    this.wallet,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final IconData icon;
  final Color color;
  final int sortValue;
  final String? actionLabel;
  final String? actionType;
  final bool? isExpense;
  final String? category;
  final String? wallet;
}
