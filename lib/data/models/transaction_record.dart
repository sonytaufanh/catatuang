import 'package:isar/isar.dart';

part 'transaction_record.g.dart';

@collection
class TransactionRecord {
  Id id = Isar.autoIncrement;

  late bool isExpense;
  late int amount;
  late String wallet;
  late String category;
  late DateTime transactionDate;
  late bool isCleared;
  String note = '';
  String receiptPath = '';
  late DateTime createdAt;
}
