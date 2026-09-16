/// Plain data model persisted in the `transactions` table.
class TransactionRecord {
  TransactionRecord({
    this.id = 0,
    this.isExpense = true,
    this.amount = 0,
    this.wallet = '',
    this.category = '',
    DateTime? transactionDate,
    this.isCleared = true,
    this.note = '',
    this.receiptPath = '',
    this.transferGroupId = '',
    this.splitGroupId = '',
    this.currency = '',
    DateTime? createdAt,
  }) : transactionDate = transactionDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  int id;
  bool isExpense;
  int amount;
  String wallet;
  String category;
  DateTime transactionDate;
  bool isCleared;
  String note;
  String receiptPath;

  /// Identifier shared by the two legs of a transfer. Empty for regular
  /// income/expense transactions.
  String transferGroupId;

  /// Identifier shared by the parts of a split transaction.
  String splitGroupId;

  /// ISO currency code of [amount] at the time it was recorded.
  String currency;
  DateTime createdAt;
}
