/// Plain data model persisted in the `debts` table.
class DebtRecord {
  DebtRecord({
    this.id = 0,
    this.name = '',
    this.isReceivable = false,
    this.principal = 0,
    this.remaining = 0,
    this.dueDate,
    this.note = '',
    this.interestRatePercent = 0,
    this.isSettled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int id;

  /// Counterparty name, e.g. "Budi" or "Bank ABC".
  String name;

  /// true = receivable (someone owes me); false = payable (I owe).
  bool isReceivable;

  /// Original amount borrowed/lent.
  int principal;

  /// Outstanding amount still to be settled.
  int remaining;

  DateTime? dueDate;
  String note;

  /// Annual interest rate in percent (0 for interest-free debt).
  double interestRatePercent;
  bool isSettled;
  DateTime createdAt;
}
