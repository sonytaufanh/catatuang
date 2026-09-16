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
    this.transferToWallet = '',
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

  /// Destination wallet when this template is a transfer. Empty otherwise.
  final String transferToWallet;

  bool get isTransfer => transferToWallet.trim().isNotEmpty;

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
    String? transferToWallet,
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
      transferToWallet: transferToWallet ?? this.transferToWallet,
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
        'transferToWallet': transferToWallet,
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
      transferToWallet: (json['transferToWallet'] as String?) ?? '',
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
      transferToWallet: template.transferToWallet.trim(),
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

      final dueDate = DateTime(current.year, current.month, dueDay, 9, 0);
      final note = tpl.note.isEmpty ? 'Auto: ${tpl.name}' : tpl.note;
      if (tpl.isTransfer) {
        await DatabaseService.instance.addTransfer(
          amount: tpl.amount,
          sourceWallet: tpl.wallet,
          destWallet: tpl.transferToWallet,
          transactionDate: dueDate,
          note: note,
        );
      } else {
        await DatabaseService.instance.addTransaction(
          isExpense: tpl.isExpense,
          amount: tpl.amount,
          wallet: tpl.wallet,
          category: tpl.category,
          transactionDate: dueDate,
          isCleared: true,
          note: note,
        );
      }
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
    final date = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    );
    final note = template.note.isEmpty
        ? 'Manual recurring: ${template.name}'
        : template.note;
    if (template.isTransfer) {
      await DatabaseService.instance.addTransfer(
        amount: template.amount,
        sourceWallet: template.wallet,
        destWallet: template.transferToWallet,
        transactionDate: date,
        note: note,
      );
    } else {
      await DatabaseService.instance.addTransaction(
        isExpense: template.isExpense,
        amount: template.amount,
        wallet: template.wallet,
        category: template.category,
        transactionDate: date,
        isCleared: true,
        note: note,
      );
    }
    // Mark this month as generated so the automatic sync does not create a
    // duplicate occurrence for the same template and month.
    final prefs = await SharedPreferences.getInstance();
    final monthKey = '${current.year}${current.month.toString().padLeft(2, '0')}';
    await prefs.setBool('recurring_tx_generated_${template.id}_$monthKey', true);
    await refreshTransactions();
  }

  /// Updates recurring templates that reference a renamed wallet.
  Future<void> renameWalletReferences({
    required String oldValue,
    required String newValue,
  }) async {
    final current = await templates();
    var changed = false;
    final next = current.map((tpl) {
      if (tpl.wallet == oldValue) {
        changed = true;
        return tpl.copyWith(wallet: newValue);
      }
      return tpl;
    }).toList(growable: false);
    if (changed) await _saveTemplates(next);
  }

  /// Updates recurring templates that reference a renamed category. Only
  /// templates of the same income/expense type are affected.
  Future<void> renameCategoryReferences({
    required bool isExpense,
    required String oldValue,
    required String newValue,
  }) async {
    final current = await templates();
    var changed = false;
    final next = current.map((tpl) {
      if (tpl.isExpense == isExpense && tpl.category == oldValue) {
        changed = true;
        return tpl.copyWith(category: newValue);
      }
      return tpl;
    }).toList(growable: false);
    if (changed) await _saveTemplates(next);
  }

  int _safeDayInMonth(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return requestedDay.clamp(1, lastDay);
  }

  Future<List<Map<String, dynamic>>> exportPayload() async {
    final list = await templates();
    return list.map((e) => e.toJson()).toList(growable: false);
  }

  Future<void> restorePayload(List<dynamic> raw) async {
    final restored = <RecurringTransactionTemplate>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final tpl = RecurringTransactionTemplate.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (tpl.id.isNotEmpty &&
            tpl.name.trim().isNotEmpty &&
            tpl.amount > 0) {
          restored.add(tpl);
        }
      } catch (_) {
        // skip invalid payload
      }
    }
    await _saveTemplates(restored);
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
