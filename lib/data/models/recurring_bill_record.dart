/// Plain data model persisted in the `recurring_bills` table.
class RecurringBillRecord {
  RecurringBillRecord({
    this.id = 0,
    this.name = '',
    this.amount = 0,
    this.dueDay = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int id;
  String name;
  int amount;
  int dueDay;
  DateTime createdAt;
}
