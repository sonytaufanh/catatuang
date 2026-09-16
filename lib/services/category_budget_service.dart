import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/transaction_record.dart';

class CategoryBudgetService extends ChangeNotifier {
  CategoryBudgetService._();

  static final CategoryBudgetService instance = CategoryBudgetService._();

  static const String _prefix = 'category_budget_v1_';
  static const String _indexKey = 'category_budget_v1_index';

  /// Set a budget limit for a category.
  Future<void> setBudget(String category, int limit) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$category';
    await prefs.setInt(key, limit);
    await _addToIndex(category);
    notifyListeners();
  }

  /// Get the budget limit for a category. Returns 0 if not set.
  Future<int> getBudget(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$category') ?? 0;
  }

  /// Get all category budgets as a map.
  Future<Map<String, int>> getAllBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? [];
    final result = <String, int>{};
    for (final category in index) {
      final value = prefs.getInt('$_prefix$category') ?? 0;
      if (value > 0) {
        result[category] = value;
      }
    }
    return result;
  }

  /// Remove budget for a category.
  Future<void> removeBudget(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$category');
    await _removeFromIndex(category);
    notifyListeners();
  }

  Future<Map<String, dynamic>> exportPayload() async {
    final budgets = await getAllBudgets();
    return <String, dynamic>{...budgets};
  }

  Future<void> restorePayload(Map<String, dynamic> raw) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? <String>[];
    for (final category in index) {
      await prefs.remove('$_prefix$category');
    }
    await prefs.remove(_indexKey);
    for (final entry in raw.entries) {
      final amount = entry.value is num ? (entry.value as num).toInt() : 0;
      final category = entry.key.toString().trim();
      if (category.isEmpty || amount <= 0) continue;
      await prefs.setInt('$_prefix$category', amount);
      await _addToIndex(category);
    }
    notifyListeners();
  }

  /// Calculate how much was spent in a category during a period.
  int getSpentForCategory(
    String category,
    List<TransactionRecord> transactions,
    DateTimeRange period,
  ) {
    var total = 0;
    for (final tx in transactions) {
      if (!tx.isExpense) continue;
      if (tx.category != category) continue;
      if (tx.transactionDate.isBefore(period.start)) continue;
      if (tx.transactionDate.isAfter(period.end)) continue;
      total += tx.amount;
    }
    return total;
  }

  Future<void> _addToIndex(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? [];
    if (!index.contains(category)) {
      index.add(category);
      await prefs.setStringList(_indexKey, index);
    }
  }

  Future<void> _removeFromIndex(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? [];
    index.remove(category);
    await prefs.setStringList(_indexKey, index);
  }
}
