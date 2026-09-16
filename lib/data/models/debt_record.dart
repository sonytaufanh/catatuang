import 'package:isar/isar.dart';

part 'debt_record.g.dart';

@collection
class DebtRecord {
  Id id = Isar.autoIncrement;

  /// Counterparty name, e.g. "Budi" or "Bank ABC".
  late String name;

  /// true = receivable (someone owes me); false = payable (I owe).
  late bool isReceivable;

  /// Original amount borrowed/lent.
  late int principal;

  /// Outstanding amount still to be settled.
  late int remaining;

  DateTime? dueDate;
  String note = '';

  /// Annual interest rate in percent (0 for interest-free debt).
  double interestRatePercent = 0;
  late bool isSettled;
  late DateTime createdAt;
}
