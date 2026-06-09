import 'package:flutter/foundation.dart';
import 'database_service.dart';

class RecurringBill {
  final int id;
  final String name;
  final int amount;
  final int dueDay;

  const RecurringBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
  });
}

final ValueNotifier<List<RecurringBill>> recurringBillsNotifier = ValueNotifier<List<RecurringBill>>([
]);

const List<(String, int, int)> _defaultSeedBills = <(String, int, int)>[
  ('Bayar Air (PDAM)', 175000, 5),
  ('Listrik PLN', 450000, 10),
  ('Internet Rumah', 350000, 15),
];

Future<void> initRecurringBillStore() async {
  await refreshRecurringBills();
}

Future<void> refreshRecurringBills() async {
  final records = await DatabaseService.instance.getAllRecurringBills();
  recurringBillsNotifier.value = records
      .map((e) => RecurringBill(id: e.id, name: e.name, amount: e.amount, dueDay: e.dueDay))
      .toList(growable: false);
}

Future<void> addRecurringBill(RecurringBill bill) async {
  await DatabaseService.instance.addRecurringBill(
    name: bill.name,
    amount: bill.amount,
    dueDay: bill.dueDay,
  );
  await refreshRecurringBills();
}

Future<void> updateRecurringBill(RecurringBill bill) async {
  await DatabaseService.instance.updateRecurringBill(
    id: bill.id,
    name: bill.name,
    amount: bill.amount,
    dueDay: bill.dueDay,
  );
  await refreshRecurringBills();
}

Future<void> deleteRecurringBill(int id) async {
  await DatabaseService.instance.deleteRecurringBill(id);
  await refreshRecurringBills();
}

bool isDefaultSeedRecurringBill(RecurringBill bill) {
  for (final seed in _defaultSeedBills) {
    if (bill.name == seed.$1 && bill.amount == seed.$2 && bill.dueDay == seed.$3) {
      return true;
    }
  }
  return false;
}

Future<int> removeDefaultSeedRecurringBills() async {
  final current = [...recurringBillsNotifier.value];
  var deletedCount = 0;
  for (final bill in current) {
    if (isDefaultSeedRecurringBill(bill)) {
      await DatabaseService.instance.deleteRecurringBill(bill.id);
      deletedCount++;
    }
  }
  if (deletedCount > 0) {
    await refreshRecurringBills();
  }
  return deletedCount;
}
