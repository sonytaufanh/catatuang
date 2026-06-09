import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/recurring_bill_store.dart';

void main() {
  test('isDefaultSeedRecurringBill detects known seed', () {
    final sample = const RecurringBill(
      id: 1,
      name: 'Bayar Air (PDAM)',
      amount: 175000,
      dueDay: 5,
    );
    expect(isDefaultSeedRecurringBill(sample), isTrue);
  });

  test('isDefaultSeedRecurringBill ignores user bill', () {
    final sample = const RecurringBill(
      id: 2,
      name: 'Gym',
      amount: 250000,
      dueDay: 12,
    );
    expect(isDefaultSeedRecurringBill(sample), isFalse);
  });
}
