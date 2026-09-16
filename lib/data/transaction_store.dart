import 'dart:async';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'models/transaction_record.dart';

final ValueNotifier<List<TransactionRecord>> transactionsNotifier =
    ValueNotifier<List<TransactionRecord>>([]);

StreamSubscription<List<TransactionRecord>>? _transactionSubscription;

/// Ids temporarily hidden from the UI while a deferred delete is pending.
final Set<int> _suppressedIds = <int>{};

Future<void> initTransactionStore() async {
  await refreshTransactions();
  _transactionSubscription ??= DatabaseService.instance
      .watchTransactions()
      .listen(_applyRecords);
}

void _applyRecords(List<TransactionRecord> records) {
  if (_suppressedIds.isEmpty) {
    transactionsNotifier.value = records;
    return;
  }
  transactionsNotifier.value = records
      .where((record) => !_suppressedIds.contains(record.id))
      .toList(growable: false);
}

/// Hides the given ids from the reactive list (optimistic delete).
void suppressTransactions(Iterable<int> ids) {
  _suppressedIds.addAll(ids);
  transactionsNotifier.value = transactionsNotifier.value
      .where((record) => !_suppressedIds.contains(record.id))
      .toList(growable: false);
}

/// Restores the visibility of suppressed ids (undo / cancel delete).
void releaseSuppressedTransactions() {
  if (_suppressedIds.isEmpty) return;
  _suppressedIds.clear();
}

Future<void> refreshTransactions() async {
  final records = await DatabaseService.instance.getAllTransactions();
  _applyRecords(records);
}
