import 'package:isar/isar.dart';

part 'recurring_bill_record.g.dart';

@collection
class RecurringBillRecord {
  Id id = Isar.autoIncrement;

  late String name;
  late int amount;
  late int dueDay;
  late DateTime createdAt;
}
