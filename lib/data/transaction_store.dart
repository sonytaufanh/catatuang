import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'models/transaction_record.dart';

final ValueNotifier<List<TransactionRecord>> transactionsNotifier =
    ValueNotifier<List<TransactionRecord>>([]);

Future<void> initTransactionStore() async {
  await refreshTransactions();
}

Future<void> refreshTransactions() async {
  final records = await DatabaseService.instance.getAllTransactions();
  transactionsNotifier.value = records;
}
