import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/data/models/debt_record.dart';
import 'package:catatuang/services/debt_plan_service.dart';

DebtRecord _debt({
  required int id,
  required String name,
  required int remaining,
  double rate = 0,
  bool isReceivable = false,
}) {
  return DebtRecord()
    ..id = id
    ..name = name
    ..isReceivable = isReceivable
    ..principal = remaining
    ..remaining = remaining
    ..interestRatePercent = rate
    ..isSettled = false
    ..createdAt = DateTime(2026, 1, 1);
}

void main() {
  final service = DebtPlanService.instance;

  test('snowball orders by smallest balance first', () {
    final plan = service.build(
      debts: [
        _debt(id: 1, name: 'Besar', remaining: 5000000),
        _debt(id: 2, name: 'Kecil', remaining: 1000000),
      ],
      monthlyPayment: 1000000,
      strategy: DebtStrategy.snowball,
    );
    expect(plan.steps.first.name, 'Kecil');
    expect(plan.feasible, isTrue);
    expect(plan.monthsToDebtFree, greaterThan(0));
  });

  test('avalanche orders by highest interest first', () {
    final plan = service.build(
      debts: [
        _debt(id: 1, name: 'Murah', remaining: 1000000, rate: 3),
        _debt(id: 2, name: 'Mahal', remaining: 5000000, rate: 24),
      ],
      monthlyPayment: 1500000,
      strategy: DebtStrategy.avalanche,
    );
    expect(plan.steps.first.name, 'Mahal');
  });

  test('ignores receivables and handles zero budget', () {
    final plan = service.build(
      debts: [
        _debt(id: 1, name: 'Piutang', remaining: 1000000, isReceivable: true),
      ],
      monthlyPayment: 0,
      strategy: DebtStrategy.snowball,
    );
    expect(plan.steps, isEmpty);
    expect(plan.feasible, isTrue);
  });

  test('marks infeasible when budget cannot cover interest', () {
    final plan = service.build(
      debts: [_debt(id: 1, name: 'Bunga', remaining: 100000000, rate: 60)],
      monthlyPayment: 1000,
      strategy: DebtStrategy.avalanche,
      maxMonths: 60,
    );
    expect(plan.feasible, isFalse);
  });
}
