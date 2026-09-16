import '../data/models/debt_record.dart';

enum DebtStrategy { snowball, avalanche }

class DebtPayoffStep {
  const DebtPayoffStep({
    required this.name,
    required this.months,
    required this.totalPaid,
    required this.interestPaid,
  });

  final String name;
  final int months;
  final int totalPaid;
  final int interestPaid;
}

class DebtPayoffPlan {
  const DebtPayoffPlan({
    required this.steps,
    required this.monthsToDebtFree,
    required this.totalPaid,
    required this.totalInterest,
    required this.feasible,
  });

  final List<DebtPayoffStep> steps;
  final int monthsToDebtFree;
  final int totalPaid;
  final int totalInterest;
  final bool feasible;
}

/// Simulates payoff order for payables using the snowball (smallest balance
/// first) or avalanche (highest interest first) strategy.
class DebtPlanService {
  DebtPlanService._();

  static final DebtPlanService instance = DebtPlanService._();

  DebtPayoffPlan build({
    required List<DebtRecord> debts,
    required int monthlyPayment,
    required DebtStrategy strategy,
    int maxMonths = 600,
  }) {
    final active = debts
        .where(
          (d) => !d.isReceivable && !d.isSettled && d.remaining > 0,
        )
        .toList();
    if (active.isEmpty || monthlyPayment <= 0) {
      return const DebtPayoffPlan(
        steps: [],
        monthsToDebtFree: 0,
        totalPaid: 0,
        totalInterest: 0,
        feasible: true,
      );
    }

    active.sort((a, b) {
      if (strategy == DebtStrategy.avalanche) {
        final byRate = b.interestRatePercent.compareTo(a.interestRatePercent);
        if (byRate != 0) return byRate;
      }
      return a.remaining.compareTo(b.remaining);
    });

    final balances = active.map((d) => d.remaining.toDouble()).toList();
    final paid = List<double>.filled(active.length, 0);
    final interestPaid = List<double>.filled(active.length, 0);
    final clearedMonth = List<int>.filled(active.length, 0);
    var totalInterest = 0.0;
    var totalPaid = 0.0;
    var months = 0;

    for (var month = 1; month <= maxMonths; month++) {
      months = month;
      var remainingBudget = monthlyPayment.toDouble();
      var anyBalance = false;

      for (var i = 0; i < active.length; i++) {
        if (balances[i] <= 0) continue;
        final monthlyRate = active[i].interestRatePercent / 100 / 12;
        final interest = balances[i] * monthlyRate;
        balances[i] += interest;
        interestPaid[i] += interest;
        totalInterest += interest;
        anyBalance = true;
      }
      if (!anyBalance) {
        months = month - 1;
        break;
      }

      for (var i = 0; i < active.length; i++) {
        if (remainingBudget <= 0) break;
        if (balances[i] <= 0) continue;
        final payment = balances[i] < remainingBudget
            ? balances[i]
            : remainingBudget;
        balances[i] -= payment;
        remainingBudget -= payment;
        paid[i] += payment;
        totalPaid += payment;
        if (balances[i] <= 0.5 && clearedMonth[i] == 0) {
          clearedMonth[i] = month;
        }
      }

      if (balances.every((b) => b <= 0.5)) {
        break;
      }
      if (month == maxMonths) {
        return DebtPayoffPlan(
          steps: _steps(active, clearedMonth, paid, interestPaid),
          monthsToDebtFree: -1,
          totalPaid: totalPaid.round(),
          totalInterest: totalInterest.round(),
          feasible: false,
        );
      }
    }

    return DebtPayoffPlan(
      steps: _steps(active, clearedMonth, paid, interestPaid),
      monthsToDebtFree: months,
      totalPaid: totalPaid.round(),
      totalInterest: totalInterest.round(),
      feasible: true,
    );
  }

  List<DebtPayoffStep> _steps(
    List<DebtRecord> active,
    List<int> clearedMonth,
    List<double> paid,
    List<double> interestPaid,
  ) {
    final steps = <DebtPayoffStep>[];
    for (var i = 0; i < active.length; i++) {
      steps.add(
        DebtPayoffStep(
          name: active[i].name,
          months: clearedMonth[i],
          totalPaid: paid[i].round(),
          interestPaid: interestPaid[i].round(),
        ),
      );
    }
    return steps;
  }
}
