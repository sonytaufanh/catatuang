import 'dart:async';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'models/debt_record.dart';

final ValueNotifier<List<DebtRecord>> debtsNotifier =
    ValueNotifier<List<DebtRecord>>([]);

StreamSubscription<List<DebtRecord>>? _debtSubscription;

Future<void> initDebtStore() async {
  await refreshDebts();
  _debtSubscription ??= DatabaseService.instance.watchDebts().listen((records) {
    debtsNotifier.value = records;
  });
}

Future<void> refreshDebts() async {
  debtsNotifier.value = await DatabaseService.instance.getAllDebts();
}

Future<void> addDebt({
  required String name,
  required bool isReceivable,
  required int amount,
  DateTime? dueDate,
  String note = '',
  double interestRatePercent = 0,
}) async {
  await DatabaseService.instance.addDebt(
    name: name,
    isReceivable: isReceivable,
    amount: amount,
    dueDate: dueDate,
    note: note,
    interestRatePercent: interestRatePercent,
  );
  await refreshDebts();
}

Future<void> updateDebt(DebtRecord debt) async {
  await DatabaseService.instance.updateDebt(
    id: debt.id,
    name: debt.name,
    isReceivable: debt.isReceivable,
    amount: debt.principal,
    remaining: debt.remaining,
    dueDate: debt.dueDate,
    note: debt.note,
    interestRatePercent: debt.interestRatePercent,
  );
  await refreshDebts();
}

Future<void> deleteDebt(int id) async {
  await DatabaseService.instance.deleteDebt(id);
  await refreshDebts();
}

Future<void> payDebt({
  required int debtId,
  required int amount,
  required String wallet,
  required String category,
  required DateTime transactionDate,
  bool createTransaction = true,
  String note = '',
}) async {
  await DatabaseService.instance.applyDebtPayment(
    debtId: debtId,
    amount: amount,
    wallet: wallet,
    category: category,
    transactionDate: transactionDate,
    createTransaction: createTransaction,
    note: note,
  );
  await refreshDebts();
}
