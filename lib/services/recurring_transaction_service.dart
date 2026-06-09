import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_service.dart';
import '../data/transaction_store.dart';

class RecurringTransactionTemplate {
  const RecurringTransactionTemplate({
    required this.id,
    required this.name,
    required this.isExpense,
    required this.amount,
    required this.wallet,
    required this.category,
    required this.dayOfMonth,
    required this.note,
    required this.active,
  });

  final String id;
  final String name;
  final bool isExpense;
  final int amount;
  final String wallet;
  final String category;
  final int dayOfMonth;
  final String note;
  final bool active;

  RecurringTransactionTemplate copyWith({
    String? id,
    String? name,
    bool? isExpense,
    int? amount,
    String? wallet,
    String? category,
    int? dayOfMonth,
    String? note,
    bool? active,
  }) {
    return RecurringTransactionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isExpense: isExpense ?? this.isExpense,
      amount: amount ?? this.amount,
      wallet: wallet ?? this.wallet,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      note: note ?? this.note,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isExpense': isExpense,
        'amount': amount,
        'wallet': wallet,
        'category': category,
        'dayOfMonth': dayOfMonth,
        'note': note,
        'active': active,
      };

  static RecurringTransactionTemplate fromJson(Map<String, dynamic> json) {
    return RecurringTransactionTemplate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isExpense: (json['isExpense'] as bool?) ?? true,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      wallet: (json['wallet'] as String?) ?? 'cash',
      category: (json['category'] as String?) ?? 'food',
      dayOfMonth: ((json['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 31),
      note: (json['note'] as String?) ?? '',
      active: (json['active'] as bool?) ?? true,
    );
  }
}

class RecurringTransactionService {
  RecurringTransactionService._();

  static final RecurringTransactionService instance = RecurringTransactionService._();
  static const String _keyTemplates = 'recurring_transaction_templates_v1';

  Future<List<RecurringTransactionTemplate>> templates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyTemplates) ?? const <String>[];
    final out = <RecurringTransactionTemplate>[];
    for (final item in raw) {
      try {
        final jsonMap = jsonDecode(item) as Map<String, dynamic>;
        final tpl = RecurringTransactionTemplate.fromJson(jsonMap);
        if (tpl.id.isNotEmpty && tpl.name.trim().isNotEmpty && tpl.amount > 0) {
          out.add(tpl);
        }
      } catch (_) {
        // skip invalid payload
      }
    }
    return out;
  }

  Future<void> upsertTemplate(RecurringTransactionTemplate template) async {
    final current = await templates();
    final normalized = template.copyWith(
      id: template.id.trim().isEmpty ? _newId() : template.id.trim(),
      name: template.name.trim(),
      wallet: template.wallet.trim().isEmpty ? 'cash' : template.wallet.trim(),
      category: template.category.trim().isEmpty ? 'food' : template.category.trim(),
      dayOfMonth: template.dayOfMonth.clamp(1, 31),
      note: template.note.trim(),
      amount: template.amount < 0 ? 0 : template.amount,
    );
    final next = <RecurringTransactionTemplate>[];
    var replaced = false;
    for (final item in current) {
      if (item.id == normalized.id) {
        next.add(normalized);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) {
      next.add(normalized);
    }
    await _saveTemplates(next);
  }

  Future<void> deleteTemplate(String id) async {
    final current = await templates();
    final next = current.where((e) => e.id != id).toList(growable: false);
    await _saveTemplates(next);
  }

  Future<int> syncDueTransactions({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final monthKey = '${current.year}${current.month.toString().padLeft(2, '0')}';
    final all = await templates();
    var created = 0;

    for (final tpl in all) {
      if (!tpl.active || tpl.amount <= 0) continue;
      final dueDay = _safeDayInMonth(current.year, current.month, tpl.dayOfMonth);
      if (current.day < dueDay) continue;
      final generatedKey = 'recurring_tx_generated_${tpl.id}_$monthKey';
      if (prefs.getBool(generatedKey) == true) continue;

      await DatabaseService.instance.addTransaction(
        isExpense: tpl.isExpense,
        amount: tpl.amount,
        wallet: tpl.wallet,
        category: tpl.category,
        transactionDate: DateTime(current.year, current.month, dueDay, 9, 0),
        isCleared: true,
        note: tpl.note.isEmpty ? 'Auto: ${tpl.name}' : tpl.note,
      );
      await prefs.setBool(generatedKey, true);
      created += 1;
    }

    if (created > 0) {
      await refreshTransactions();
    }
    return created;
  }

  Future<void> createNow(RecurringTransactionTemplate template, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    await DatabaseService.instance.addTransaction(
      isExpense: template.isExpense,
      amount: template.amount,
      wallet: template.wallet,
      category: template.category,
      transactionDate: DateTime(
        current.year,
        current.month,
        current.day,
        current.hour,
        current.minute,
      ),
      isCleared: true,
      note: template.note.isEmpty ? 'Manual recurring: ${template.name}' : template.note,
    );
    await refreshTransactions();
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

  Future<void> _saveTemplates(List<RecurringTransactionTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = templates.map((e) => jsonEncode(e.toJson())).toList(growable: false);
    await prefs.setStringList(_keyTemplates, encoded);
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'rtx_$now';
  }
}
