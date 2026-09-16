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

  /// Identifier shared by the two legs of a transfer. Empty for regular
  /// income/expense transactions. Older transfers may have an empty value
  /// and are paired heuristically.
  String transferGroupId = '';

  /// Identifier shared by the parts of a split transaction. Empty for
  /// non-split transactions.
  String splitGroupId = '';

  /// ISO currency code of [amount] at the time it was recorded.
  String currency = '';
  late DateTime createdAt;
}
